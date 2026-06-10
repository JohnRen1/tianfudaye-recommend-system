import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { ok, fail } from '@/lib/api-response';
import type { PhoneLoginResponseDTO, CurrentUserDTO } from '@/lib/contracts/auth';

const PHONE_REGEX = /^1[3-9]\d{9}$/;
const CODE_REGEX = /^\d{6}$/;

// 与 send-code/route.ts 共享的内存验证码存储
// 生产阶段替换为 Redis 或 Supabase Edge Functions KV
declare global {
  // eslint-disable-next-line no-var
  var _devCodeStore: Map<string, { code: string; expiresAt: number }> | undefined;
}
if (!globalThis._devCodeStore) {
  globalThis._devCodeStore = new Map();
}
const devCodeStore = globalThis._devCodeStore;

function buildDevToken(userId: string): string {
  // 开发阶段临时 token：base64(userId:timestamp)
  // 生产阶段替换为签发 JWT（jose 库）或 Supabase Auth session token
  return Buffer.from(`${userId}:${Date.now()}`).toString('base64');
}

export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail('INVALID_REQUEST_BODY', '请求体格式错误', 400);
  }

  const { phone, code, sourceQrId, sourceActivityId } = body as Record<string, unknown>;

  if (typeof phone !== 'string' || !PHONE_REGEX.test(phone)) {
    return fail('INVALID_PHONE', '手机号格式不正确', 400);
  }

  if (typeof code !== 'string' || !CODE_REGEX.test(code)) {
    return fail('INVALID_CODE', '验证码格式不正确', 400);
  }

  // 验证码校验
  // 生产阶段替换为查 Redis KV 或 Supabase Auth OTP 验证
  if (process.env.NODE_ENV === 'production') {
    // TODO: 接入真实短信验证
    return fail('SMS_NOT_CONFIGURED', '生产环境尚未接入短信服务', 501);
  }

  const stored = devCodeStore.get(phone);
  const isValid =
    stored &&
    stored.code === code &&
    stored.expiresAt > Date.now();

  if (!isValid) {
    return fail('AUTH_INVALID_CODE', '验证码错误或已过期', 401);
  }

  // 验证通过，清除已用验证码
  devCodeStore.delete(phone);

  const serviceClient = createServiceClient();

  // 查询用户是否已存在
  const { data: existingUser } = await serviceClient
    .from('users')
    .select('id, phone, name, identity, company, industry, size, registered_at, active_at, is_profile_complete')
    .eq('phone', phone)
    .single();

  let isNew = false;
  let userId: string;

  if (existingUser) {
    userId = existingUser.id as string;
    // 已有用户：更新最近活跃时间
    await serviceClient
      .from('users')
      .update({ active_at: new Date().toISOString() })
      .eq('id', userId);
  } else {
    // 新用户：创建账号
    isNew = true;
    const insertData: Record<string, unknown> = {
      phone,
      is_profile_complete: false,
    };

    // 写入来源归因（S2）
    if (typeof sourceQrId === 'string' && sourceQrId) {
      insertData.source_qr_id = sourceQrId;
    }
    if (typeof sourceActivityId === 'string' && sourceActivityId) {
      insertData.source_activity_id = sourceActivityId;
    }

    const { data: newUser, error: insertError } = await serviceClient
      .from('users')
      .insert(insertData)
      .select('id, phone, name, identity, company, industry, size, registered_at, active_at, is_profile_complete')
      .single();

    if (insertError || !newUser) {
      return fail('USER_CREATE_FAILED', '用户创建失败', 500, insertError?.message);
    }

    userId = newUser.id as string;
  }

  // 重新查询最新用户数据
  const { data: userData } = await serviceClient
    .from('users')
    .select('id, phone, name, identity, company, industry, size, registered_at, active_at, is_profile_complete')
    .eq('id', userId)
    .single();

  if (!userData) {
    return fail('USER_FETCH_FAILED', '用户数据获取失败', 500);
  }

  const currentUser: CurrentUserDTO = {
    id: userData.id as string,
    name: (userData.name as string | null) ?? null,
    phone: userData.phone as string,
    identity: (userData.identity as string | null) ?? null,
    company: (userData.company as string | null) ?? null,
    industry: (userData.industry as string | null) ?? null,
    size: (userData.size as string | null) ?? null,
    registeredAt: userData.registered_at as string,
    activeAt: userData.active_at as string,
    isProfileComplete: (userData.is_profile_complete as boolean) ?? false,
  };

  const accessToken = buildDevToken(userId);
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(); // 7 天

  const response: PhoneLoginResponseDTO = {
    accessToken,
    expiresAt,
    user: currentUser,
    isNew,
  };

  return ok(response);
}
