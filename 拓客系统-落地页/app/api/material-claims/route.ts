import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { requireUser } from '@/lib/auth';
import { ok, fail } from '@/lib/api-response';
import type {
  MaterialClaimCreateDTO,
  MaterialClaimCreateResponseDTO,
} from '@/lib/contracts/material';

export async function POST(req: NextRequest) {
  const ctx = await requireUser(req);
  if (!ctx) return fail('AUTH_REQUIRED', '请先登录', 401);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail('INVALID_REQUEST_BODY', '请求体格式错误', 400);
  }

  const { materialId, activityId } = body as MaterialClaimCreateDTO & Record<string, unknown>;

  if (typeof materialId !== 'string' || !materialId) {
    return fail('INVALID_MATERIAL_ID', 'materialId 不能为空', 400);
  }

  const serviceClient = createServiceClient();

  // 验证资料存在且已上架
  const { data: material, error: matError } = await serviceClient
    .from('materials')
    .select('id, name, status, need_login, need_company_info, storage_key, format')
    .eq('id', materialId)
    .single();

  if (matError || !material) {
    return fail('MATERIAL_NOT_FOUND', '资料不存在', 404);
  }

  if (material.status !== 'published') {
    return fail('MATERIAL_NOT_PUBLISHED', '资料未上架，无法领取', 422);
  }

  // 检查用户资质
  if (material.need_company_info && !ctx.user.isProfileComplete) {
    return fail('CLAIM_COMPANY_INFO_REQUIRED', '需要先补充企业信息才能领取', 403);
  }

  // 检查是否已领取（幂等：重复领取直接返回已有记录）
  const { data: existing } = await serviceClient
    .from('material_claims')
    .select('id, claimed_at, download_url, url_expires_at')
    .eq('user_id', ctx.userId)
    .eq('material_id', materialId)
    .single();

  if (existing) {
    // 已领取，返回现有记录（download_url 可能已过期，需重新生成）
    const response: MaterialClaimCreateResponseDTO = {
      claimId: existing.id as string,
      materialId,
      claimedAt: existing.claimed_at as string,
      downloadUrl: existing.download_url as string ?? '',
      downloadUrlExpiresAt: existing.url_expires_at as string ?? new Date(Date.now() + 3600_000).toISOString(),
    };
    return ok(response);
  }

  // 生成下载 URL（使用 Supabase Storage signed URL）
  // 生产阶段：通过 storage_key 生成有时效的签名下载链接
  // 当前阶段：返回占位 URL，接入 Storage 后替换
  const signedUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/sign/${material.storage_key}?token=dev-placeholder`;
  const expiresAt = new Date(Date.now() + 3600_000).toISOString(); // 1 小时

  // 写入领取记录（S3：落库修复审计缺口）
  const claimData: Record<string, unknown> = {
    user_id: ctx.userId,
    material_id: materialId,
    download_url: signedUrl,
    url_expires_at: expiresAt,
    ...(typeof activityId === 'string' && activityId ? { activity_id: activityId } : {}),
  };

  const { data: claim, error: claimError } = await serviceClient
    .from('material_claims')
    .insert(claimData)
    .select('id, claimed_at')
    .single();

  if (claimError || !claim) {
    return fail('CLAIM_FAILED', '领取失败', 500, claimError?.message);
  }

  const response: MaterialClaimCreateResponseDTO = {
    claimId: claim.id as string,
    materialId,
    claimedAt: claim.claimed_at as string,
    downloadUrl: signedUrl,
    downloadUrlExpiresAt: expiresAt,
  };

  return ok(response);
}
