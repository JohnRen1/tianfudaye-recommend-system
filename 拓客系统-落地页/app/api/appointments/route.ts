import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { ok, fail } from '@/lib/api-response';
import { requireUser } from '@/lib/auth';
import type {
  AppointmentCreateDTO,
  AppointmentCreateResponseDTO,
} from '@/lib/contracts/appointment';
import { APPOINTMENT_ERROR_CODES } from '@/lib/contracts/appointment';

const VALID_TOPICS = new Set([
  'tax_risk_check',
  'invoice_compliance',
  'public_to_private_risk',
  'corporate_income_tax',
  'individual_tax_social',
  'tax_audit_response',
  'company_structure',
  'other',
]);

export async function POST(req: NextRequest) {
  // 认证：端用户必须登录
  const ctx = await requireUser(req);
  if (!ctx) {
    return fail(
      APPOINTMENT_ERROR_CODES.APPOINTMENT_AUTH_REQUIRED,
      '请先登录后再预约顾问',
      401,
    );
  }
  const { userId, user } = ctx;

  // 解析请求体
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail('INVALID_REQUEST_BODY', '请求体格式错误', 400);
  }

  const {
    topic,
    description,
    company,
    industry,
    contactTime,
    sourceQrId,
    sourceActivityId,
    sourceLeadId,
  } = body as AppointmentCreateDTO & Record<string, unknown>;

  // 验证 topic
  if (typeof topic !== 'string' || !VALID_TOPICS.has(topic)) {
    return fail(
      APPOINTMENT_ERROR_CODES.APPOINTMENT_TOPIC_INVALID,
      '咨询主题值无效',
      400,
    );
  }

  // 验证 description
  if (typeof description !== 'string' || description.trim().length === 0) {
    return fail('APPOINTMENT_DESCRIPTION_REQUIRED', '问题描述不能为空', 400);
  }

  const serviceClient = createServiceClient();

  // 从 users 表读取 phone 和 name（以服务端数据为准）
  const { data: userRow } = await serviceClient
    .from('users')
    .select('phone, name')
    .eq('id', userId)
    .single();

  if (!userRow) {
    return fail('USER_NOT_FOUND', '用户不存在', 404);
  }

  const phone = (userRow.phone as string | null) ?? user.phone;
  const name = (userRow.name as string | null) ?? '';

  // 写入 appointments 表（先不带 lead_id）
  const appointmentInsert: Record<string, unknown> = {
    user_id: userId,
    topic,
    description: description.trim(),
    phone,
    name,
    status: 'pending',
  };
  if (typeof company === 'string' && company.trim()) {
    appointmentInsert.company = company.trim();
  }
  if (typeof industry === 'string' && industry.trim()) {
    appointmentInsert.industry = industry.trim();
  }
  if (typeof contactTime === 'string' && contactTime.trim()) {
    appointmentInsert.contact_time = contactTime.trim();
  }
  if (typeof sourceQrId === 'string' && sourceQrId) {
    appointmentInsert.source_qr_id = sourceQrId;
  }
  if (typeof sourceActivityId === 'string' && sourceActivityId) {
    appointmentInsert.source_activity_id = sourceActivityId;
  }

  const { data: newAppointment, error: insertErr } = await serviceClient
    .from('appointments')
    .insert(appointmentInsert)
    .select('id, created_at')
    .single();

  if (insertErr || !newAppointment) {
    return fail('APPOINTMENT_CREATE_FAILED', '预约创建失败', 500, insertErr?.message);
  }

  const appointmentId = newAppointment.id as string;
  const createdAt = newAppointment.created_at as string;

  // 联动更新线索状态（S3）
  let leadId: string | null = null;

  // 若请求中携带了 sourceLeadId，直接关联该线索
  if (typeof sourceLeadId === 'string' && sourceLeadId) {
    const { data: specifiedLead } = await serviceClient
      .from('leads')
      .select('id, status')
      .eq('id', sourceLeadId)
      .eq('user_id', userId)
      .single();

    if (specifiedLead) {
      leadId = specifiedLead.id as string;
      await serviceClient
        .from('leads')
        .update({ status: 'appointed' })
        .eq('id', leadId);
    }
    // sourceLeadId 不存在时不阻断流程，继续走通用逻辑
  }

  if (!leadId) {
    // 查找最近一条有效线索（非 converted / invalid）
    const { data: existingLead } = await serviceClient
      .from('leads')
      .select('id')
      .eq('user_id', userId)
      .not('status', 'in', '("converted","invalid")')
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    if (existingLead) {
      leadId = existingLead.id as string;
      await serviceClient
        .from('leads')
        .update({ status: 'appointed' })
        .eq('id', leadId);
    } else {
      // 无线索：新建一条
      const leadInsert: Record<string, unknown> = {
        user_id: userId,
        status: 'appointed',
      };
      if (typeof sourceActivityId === 'string' && sourceActivityId) {
        leadInsert.source_activity_id = sourceActivityId;
      }
      if (typeof sourceQrId === 'string' && sourceQrId) {
        leadInsert.source_qr_id = sourceQrId;
      }

      const { data: newLead } = await serviceClient
        .from('leads')
        .insert(leadInsert)
        .select('id')
        .single();

      if (newLead) {
        leadId = newLead.id as string;
      }
    }
  }

  // 将 lead_id 回写到 appointments
  if (leadId) {
    await serviceClient
      .from('appointments')
      .update({ lead_id: leadId })
      .eq('id', appointmentId);

    // 同步更新 users.lead_status
    await serviceClient
      .from('users')
      .update({ lead_status: 'appointed' })
      .eq('id', userId);
  }

  const response: AppointmentCreateResponseDTO = {
    id: appointmentId,
    leadId,
    status: 'pending',
    createdAt,
  };

  return ok(response, 201);
}
