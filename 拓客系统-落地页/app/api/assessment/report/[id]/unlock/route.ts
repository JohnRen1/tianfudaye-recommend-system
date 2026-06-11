import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { requireUser } from '@/lib/auth';
import { ok, fail } from '@/lib/api-response';
import {
  REPORT_MODULE_LABEL,
  type ReportModuleKey,
  type AssessmentReportPublicDTO,
  type ModuleScorePublicDTO,
  type UnlockReportResponseDTO,
} from '@/lib/contracts/assessment';
import type { RiskLevel } from '@/lib/contracts/shared';

interface RouteContext {
  params: Promise<{ id: string }>;
}

function parseModules(raw: unknown): ModuleScorePublicDTO[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((m: Record<string, unknown>) => ({
    moduleKey: m.module_key as ReportModuleKey,
    moduleName:
      (m.module_name as string | undefined) ??
      REPORT_MODULE_LABEL[m.module_key as ReportModuleKey] ??
      String(m.module_key),
    score: (m.score as number) ?? 0,
    riskLevel: (m.risk_level as RiskLevel) ?? 'low',
    desc: (m.desc as string) ?? '',
    advice: (m.advice as string) ?? '',
  }));
}

/**
 * POST /api/assessment/report/:id/unlock
 * 需要认证。
 * 更新 assessment_reports SET viewed=true，返回含 suggestions 的完整报告。
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
    .select('id, user_id, score, risk_level, modules, suggestions, viewed, is_saved, created_at')
    .eq('id', id)
    .single();

  if (fetchError || !row) {
    return fail('REPORT_NOT_FOUND', '报告不存在', 404);
  }

  const reportUserId = row.user_id as string | null;

  // 若报告已认领，必须是同一用户
  if (reportUserId !== null && reportUserId !== userCtx.userId) {
    return fail('REPORT_FORBIDDEN', '无权限解锁此报告', 403);
  }

  // 更新 viewed=true（若报告未认领，同时写入 user_id）
  const updatePayload: Record<string, unknown> = { viewed: true };
  if (reportUserId === null) {
    updatePayload.user_id = userCtx.userId;
  }

  const { error: updateError } = await serviceClient
    .from('assessment_reports')
    .update(updatePayload)
    .eq('id', id);

  if (updateError) {
    return fail('REPORT_UNLOCK_FAILED', '解锁失败', 500, updateError.message);
  }

  // 重新查询以返回最新状态
  const { data: updated, error: refetchError } = await serviceClient
    .from('assessment_reports')
    .select('id, user_id, score, risk_level, modules, suggestions, viewed, is_saved, created_at')
    .eq('id', id)
    .single();

  if (refetchError || !updated) {
    return fail('REPORT_FETCH_FAILED', '报告数据获取失败', 500);
  }

  const report: AssessmentReportPublicDTO = {
    id: updated.id as string,
    isClaimed: (updated.user_id as string | null) !== null,
    isUnlocked: true,
    isSaved: Boolean(updated.is_saved),
    score: updated.score as number,
    riskLevel: updated.risk_level as RiskLevel,
    modules: parseModules(updated.modules),
    completedAt: updated.created_at as string,
    suggestions: Array.isArray(updated.suggestions)
      ? (updated.suggestions as string[])
      : [],
  };

  const response: UnlockReportResponseDTO = { report };
  return ok(response);
}
