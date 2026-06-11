import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { ok, fail } from '@/lib/api-response';
import { requireUser } from '@/lib/auth';
import type { AppointmentMySummaryDTO } from '@/lib/contracts/appointment';
import { APPOINTMENT_ERROR_CODES } from '@/lib/contracts/appointment';

export async function GET(req: NextRequest) {
  // 认证：端用户必须登录
  const ctx = await requireUser(req);
  if (!ctx) {
    return fail(
      APPOINTMENT_ERROR_CODES.APPOINTMENT_AUTH_REQUIRED,
      '请先登录后再查看预约记录',
      401,
    );
  }
  const { userId } = ctx;

  const serviceClient = createServiceClient();

  const { data: rows, error } = await serviceClient
    .from('appointments')
    .select('id, topic, description, status, advisor_name, scheduled_at, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) {
    return fail('APPOINTMENT_FETCH_FAILED', '预约记录获取失败', 500, error.message);
  }

  const list: AppointmentMySummaryDTO[] = (rows ?? []).map((row) => {
    const desc = (row.description as string) ?? '';
    return {
      id: row.id as string,
      topic: row.topic as AppointmentMySummaryDTO['topic'],
      descriptionSummary: desc.slice(0, 100),
      status: row.status as AppointmentMySummaryDTO['status'],
      advisorName: (row.advisor_name as string | null) ?? null,
      scheduledAt: (row.scheduled_at as string | null) ?? null,
      createdAt: row.created_at as string,
    };
  });

  return ok(list);
}
