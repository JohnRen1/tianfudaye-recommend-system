import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { requireUser } from '@/lib/auth';
import { ok, fail } from '@/lib/api-response';
import type { SaveReportResponseDTO } from '@/lib/contracts/assessment';

interface RouteContext {
  params: Promise<{ id: string }>;
}

/**
 * POST /api/assessment/report/:id/save
 * 需要认证。
 * 更新 assessment_reports SET is_saved=true。
 */
export async function POST(req: NextRequest, { params }: RouteContext) {
  const { id } = await params;

  const userCtx = await requireUser(req);
  if (!userCtx) {
    return fail('AUTH_REQUIRED', '请先登录', 401);
  }

  const serviceClient = createServiceClient();

  // 查询报告，验证存在性和归属
  const { data: row, error: fetchError } = await serviceClient
    .from('assessment_reports')
    .select('id, user_id')
    .eq('id', id)
    .single();

  if (fetchError || !row) {
    return fail('REPORT_NOT_FOUND', '报告不存在', 404);
  }

  const reportUserId = row.user_id as string | null;

  // 若报告已认领，必须是同一用户
  if (reportUserId !== null && reportUserId !== userCtx.userId) {
    return fail('REPORT_FORBIDDEN', '无权限保存此报告', 403);
  }

  const savedAt = new Date().toISOString();

  const { error: updateError } = await serviceClient
    .from('assessment_reports')
    .update({ is_saved: true })
    .eq('id', id);

  if (updateError) {
    return fail('REPORT_SAVE_FAILED', '保存失败', 500, updateError.message);
  }

  const response: SaveReportResponseDTO = {
    saved: true,
    savedAt,
  };

  return ok(response);
}
