import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { ok, fail } from '@/lib/api-response';
import type { SendCodeResponseDTO } from '@/lib/contracts/auth';

const PHONE_REGEX = /^1[3-9]\d{9}$/;

// 开发阶段内存存储验证码（生产阶段替换为 Redis 或 Supabase Edge Functions KV）
// 格式：{ phone -> { code, expiresAt } }
const devCodeStore = new Map<string, { code: string; expiresAt: number }>();

export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail('INVALID_REQUEST_BODY', '请求体格式错误', 400);
  }

  const { phone, purpose } = body as Record<string, unknown>;

  if (typeof phone !== 'string' || !PHONE_REGEX.test(phone)) {
    return fail('INVALID_PHONE', '手机号格式不正确', 400);
  }

  if (purpose !== 'login') {
    return fail('INVALID_PURPOSE', '验证码用途不合法', 400);
  }

  // 防刷：60 秒内同一手机号不重复发送
  const existing = devCodeStore.get(phone);
  if (existing && existing.expiresAt - 240_000 > Date.now()) {
    return fail('CODE_SEND_TOO_FREQUENT', '发送太频繁，请 60 秒后再试', 429);
  }

  const serviceClient = createServiceClient();
  const { data: user } = await serviceClient
    .from('users')
    .select('id')
    .eq('phone', phone)
    .single();

  const isRegistered = !!user;

  // 生成 6 位验证码
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + 300_000; // 5 分钟
  devCodeStore.set(phone, { code, expiresAt });

  // 生产阶段：在此调用短信服务
  // await sendSms({ phone, templateCode: process.env.SMS_TEMPLATE_CODE, params: { code } });
  // 开发阶段：通过 _devCode 字段直接返回（生产环境删除此字段）

  const response: SendCodeResponseDTO & { _devCode?: string } = {
    expiresInSeconds: 300,
    isRegistered,
    ...(process.env.NODE_ENV !== 'production' && { _devCode: code }),
  };

  return ok(response);
}
