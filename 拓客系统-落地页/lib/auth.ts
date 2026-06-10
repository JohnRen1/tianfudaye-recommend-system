import { NextRequest } from 'next/server';
import { createServiceClient } from './supabase';
import type { CurrentUserDTO } from './contracts/auth';

export interface UserContext {
  userId: string;
  user: CurrentUserDTO;
}

/**
 * 从 Authorization: Bearer <token> 验证落地页端用户身份。
 * 当前阶段使用开发临时 token（base64 userId:timestamp）。
 * 生产阶段替换为 Supabase Auth JWT 验证。
 */
export async function requireUser(req: NextRequest): Promise<UserContext | null> {
  const authHeader = req.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;

  const token = authHeader.slice(7);

  // 开发阶段：解析临时 token（格式：base64(userId:timestamp)）
  let userId: string;
  try {
    const decoded = Buffer.from(token, 'base64').toString('utf-8');
    const [id] = decoded.split(':');
    if (!id || id.length < 10) return null;
    userId = id;
  } catch {
    return null;
  }

  const serviceClient = createServiceClient();
  const { data: row } = await serviceClient
    .from('users')
    .select('id, phone, name, identity, company, industry, size, registered_at, active_at, is_profile_complete')
    .eq('id', userId)
    .single();

  if (!row) return null;

  const user: CurrentUserDTO = {
    id: row.id as string,
    name: (row.name as string | null) ?? null,
    phone: row.phone as string,
    identity: (row.identity as string | null) ?? null,
    company: (row.company as string | null) ?? null,
    industry: (row.industry as string | null) ?? null,
    size: (row.size as string | null) ?? null,
    registeredAt: row.registered_at as string,
    activeAt: row.active_at as string,
    isProfileComplete: (row.is_profile_complete as boolean) ?? false,
  };

  return { userId, user };
}
