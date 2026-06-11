import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { requireUser } from '@/lib/auth';
import { ok, fail } from '@/lib/api-response';
import {
  REPORT_MODULE_LABEL,
  type ReportModuleKey,
  type AssessmentReportPublicDTO,
  type ModuleScorePublicDTO,
} from '@/lib/contracts/assessment';
import type { RiskLevel } from '@/lib/contracts/shared';

interface RouteContext {
  params: Promise<{ id: string }>;
}

/** 将数据库 modules JSONB 转换为 ModuleScorePublicDTO[] */
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
 * GET /api/assessment/report/:id
 * 认证可选。
 * - 若报告 user_id 非 null，且请求用户已登录，则校验归属。
 * - 未解锁时不返回 suggestions（S5）。
 */
export async function GET(req: NextRequest, { params }: RouteContext) {
  const { id } = await params;
  const userCtx = await requireUser(req);

  const serviceClient = createServiceClient();

  const { data: row, error } = await serviceClient
    .from('assessment_reports')
    .select('id, user_id, score, risk_level, modules, suggestions, viewed, is_saved, created_at')
    .eq('id', id)
    .single();

  if (error || !row) {
    return fail('REPORT_NOT_FOUND', '报告不存在', 404);
  }

  // 归属校验：报告已认领（user_id 非 null）且请求用户已登录 → 必须匹配
  const reportUserId = row.user_id as string | null;
  if (reportUserId !== null && userCtx !== null) {
    if (reportUserId !== userCtx.userId) {
      return fail('REPORT_FORBIDDEN', '无权限访问此报告', 403);
    }
  }

  const viewed = Boolean(row.viewed);

  const report: AssessmentReportPublicDTO = {
    id: row.id as string,
    isClaimed: reportUserId !== null,
    isUnlocked: viewed,
    isSaved: Boolean(row.is_saved),
    score: row.score as number,
    riskLevel: row.risk_level as RiskLevel,
    modules: parseModules(row.modules),
    completedAt: row.created_at as string,
    // suggestions 仅已解锁时返回（S5）
    ...(viewed && {
      suggestions: Array.isArray(row.suggestions) ? (row.suggestions as string[]) : [],
    }),
  };

  return ok(report);
}
