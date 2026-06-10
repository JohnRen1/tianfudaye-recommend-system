import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { ok, fail } from '@/lib/api-response';
import type { QrScanTrackRequestDTO, QrScanTrackResponseDTO } from '@/lib/contracts/tracking';

export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail('INVALID_REQUEST_BODY', '请求体格式错误', 400);
  }

  const { qrCodeId, sessionId, userAgent } = body as QrScanTrackRequestDTO & Record<string, unknown>;

  if (typeof qrCodeId !== 'string' || !qrCodeId) {
    return fail('INVALID_QR_CODE_ID', 'qrCodeId 不能为空', 400);
  }

  const serviceClient = createServiceClient();

  // 验证二维码存在且有效
  const { data: qrCode, error: qrError } = await serviceClient
    .from('qr_codes')
    .select(`
      id, name, type, status, invite_code, activity_id, advisor_id,
      activities!activity_id(
        id, name, theme, start_at, end_at, place, teacher, speaker_title,
        description, cover_image, status
      )
    `)
    .eq('id', qrCodeId)
    .eq('status', 'active')
    .single();

  if (qrError || !qrCode) {
    return fail('QR_CODE_NOT_FOUND', '二维码不存在或已停用', 404);
  }

  // 插入扫码事件记录（S2：归因链追踪）
  const eventData: Record<string, unknown> = {
    qr_code_id: qrCodeId,
    user_agent: typeof userAgent === 'string' ? userAgent : null,
    session_id: typeof sessionId === 'string' ? sessionId : null,
  };

  await serviceClient.from('qr_scan_events').insert(eventData);

  // 原子递增扫码计数（先查当前值，再 +1）
  const { data: currentQr } = await serviceClient
    .from('qr_codes')
    .select('scans')
    .eq('id', qrCodeId)
    .single();
  await serviceClient
    .from('qr_codes')
    .update({ scans: ((currentQr?.scans as number | null) ?? 0) + 1 })
    .eq('id', qrCodeId);

  if (qrCode.activity_id) {
    await serviceClient
      .from('activities')
      .update({ scan: (qrCode as Record<string, unknown>).scan as number ?? 0 })
      .eq('id', qrCode.activity_id as string);
  }

  // 构建扫码响应（含活动展示数据）
  const actArr = qrCode.activities as Record<string, unknown>[] | null;
  const act = Array.isArray(actArr) ? (actArr[0] ?? null) : null;

  // 查询顾问展示名
  let advisorName: string | null = null;
  if (qrCode.advisor_id) {
    const { data: adv } = await serviceClient
      .from('admin_users')
      .select('display_name')
      .eq('id', qrCode.advisor_id as string)
      .single();
    advisorName = (adv?.display_name as string | null) ?? null;
  }

  const response: QrScanTrackResponseDTO = {
    valid: true,
    status: qrCode.status as 'active' | 'paused',
    advisorId: (qrCode.advisor_id as string | null) ?? null,
    advisorName,
    activity: act
      ? {
          id: act.id as string,
          name: act.name as string,
          speaker: act.teacher as string,
          speakerTitle: (act.speaker_title as string) ?? '',
          date: (act.start_at as string).slice(0, 10),
          time: (act.start_at as string).slice(11, 16),
          location: act.place as string,
          description: (act.description as string) ?? '',
          coverImage: (act.cover_image as string | null) ?? null,
          status: act.status as 'published' | 'draft' | 'closed',
        }
      : null,
  };

  return ok(response);
}
