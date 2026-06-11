import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { requireUser } from '@/lib/auth';
import { ok, fail } from '@/lib/api-response';
import {
  REPORT_MODULE_LABEL,
  type ReportModuleKey,
  type AssessmentSubmitDTO,
  type AssessmentSubmitResponseDTO,
  type ModuleScorePublicDTO,
} from '@/lib/contracts/assessment';
import type { RiskLevel } from '@/lib/contracts/shared';

const REPORT_MODULE_KEYS: ReportModuleKey[] = [
  'report_invoice',
  'report_fund',
  'report_cost',
  'report_payroll',
  'report_audit',
];

const FIXED_SUGGESTIONS = ['建议咨询专业税务顾问', '定期进行税务自查'];

/** 根据总分映射风险等级 */
function scoreToRiskLevel(score: number): RiskLevel {
  if (score >= 70) return 'high';
  if (score >= 40) return 'medium';
  return 'low';
}

/** 模块描述映射（简化版占位） */
const MODULE_DESC: Record<ReportModuleKey, string> = {
  report_invoice: '您在发票合规方面存在一定风险，建议进行全面自查。',
  report_fund: '公转私操作需注意合规性，避免资金流水异常。',
  report_cost: '成本费用的归属和票据管理需加强规范。',
  report_payroll: '个税申报及社保缴纳合规性需重点关注。',
  report_audit: '面对税务稽查，建议提前做好风险应对预案。',
};

const MODULE_ADVICE: Record<ReportModuleKey, string> = {
  report_invoice: '建立发票台账，定期核查进销项匹配。',
  report_fund: '规范资金走账流程，保留相关业务凭证。',
  report_cost: '确保成本费用均有合法凭证支撑。',
  report_payroll: '核查社保基数与实际薪资的匹配情况。',
  report_audit: '整理并归档近三年纳税记录和凭证。',
};

/**
 * POST /api/assessment/submit
 * 认证可选（userId 可为 null）。
 * S5：score / riskLevel 由服务端计算，不接受前端传入。
 */
export async function POST(req: NextRequest) {
  // 认证可选
  const userCtx = await requireUser(req);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail('INVALID_REQUEST_BODY', '请求体格式错误', 400);
  }

  const { answers, sourceQrId, sourceActivityId } = body as Partial<AssessmentSubmitDTO>;

  // 验证 answers
  if (!Array.isArray(answers) || answers.length === 0) {
    return fail('INVALID_ANSWERS', 'answers 不能为空', 400);
  }

  for (const ans of answers) {
    if (
      typeof ans !== 'object' ||
      ans === null ||
      typeof ans.questionId !== 'string' ||
      !Array.isArray(ans.selectedIndexes)
    ) {
      return fail('INVALID_ANSWERS', 'answers 格式不正确', 400);
    }
  }

  const serviceClient = createServiceClient();

  // 查询题库，获取 options（含 score）
  const questionIds = answers.map((a) => a.questionId);
  const { data: questionRows, error: qError } = await serviceClient
    .from('assessment_questions')
    .select('id, options')
    .in('id', questionIds);

  if (qError) {
    return fail('QUESTIONS_FETCH_FAILED', '题库加载失败', 500, qError.message);
  }

  // 构建 id -> options 查找表
  const questionMap = new Map<string, Array<{ sort_order: number; score: number }>>();
  for (const row of questionRows ?? []) {
    const opts = Array.isArray(row.options) ? row.options : [];
    questionMap.set(row.id as string, opts as Array<{ sort_order: number; score: number }>);
  }

  // 评分逻辑：对每题取 selectedIndexes 对应 score 求和
  let totalScore = 0;
  for (const ans of answers) {
    const opts = questionMap.get(ans.questionId);
    if (!opts) continue;
    for (const idx of ans.selectedIndexes) {
      const opt = opts.find((o) => o.sort_order === idx);
      if (opt && typeof opt.score === 'number') {
        totalScore += opt.score;
      }
    }
  }

  // 限制 0-100
  totalScore = Math.min(100, Math.max(0, totalScore));
  const riskLevel = scoreToRiskLevel(totalScore);

  // 构建 5 个报告模块（简化：各模块 score = totalScore）
  const modules: ModuleScorePublicDTO[] = REPORT_MODULE_KEYS.map((key) => ({
    moduleKey: key,
    moduleName: REPORT_MODULE_LABEL[key],
    score: totalScore,
    riskLevel,
    desc: MODULE_DESC[key],
    advice: MODULE_ADVICE[key],
  }));

  const modulesJson = modules.map((m) => ({
    module_key: m.moduleKey,
    module_name: m.moduleName,
    score: m.score,
    risk_level: m.riskLevel,
    desc: m.desc,
    advice: m.advice,
  }));

  // 写入 assessment_reports
  const reportInsert: Record<string, unknown> = {
    score: totalScore,
    risk_level: riskLevel,
    modules: modulesJson,
    suggestions: FIXED_SUGGESTIONS,
    viewed: false,
    is_saved: false,
  };

  if (userCtx) {
    reportInsert.user_id = userCtx.userId;
  }
  if (typeof sourceQrId === 'string' && sourceQrId) {
    reportInsert.source_qr_id = sourceQrId;
  }
  if (typeof sourceActivityId === 'string' && sourceActivityId) {
    reportInsert.source_activity_id = sourceActivityId;
  }

  const { data: report, error: reportError } = await serviceClient
    .from('assessment_reports')
    .insert(reportInsert)
    .select('id')
    .single();

  if (reportError || !report) {
    return fail('REPORT_CREATE_FAILED', '报告生成失败', 500, reportError?.message);
  }

  const reportId = report.id as string;

  // 写入 report_raw_answers（每题一条）
  const rawAnswerRows = answers.map((ans) => ({
    report_id: reportId,
    question_id: ans.questionId,
    selected_indexes: ans.selectedIndexes,
  }));

  const { error: rawAnswerError } = await serviceClient
    .from('report_raw_answers')
    .insert(rawAnswerRows);

  if (rawAnswerError) {
    // 原始答案写入失败不阻断主流程，仅记录（生产环境可接入告警）
    console.error('[assessment/submit] raw answers insert failed:', rawAnswerError.message);
  }

  const response: AssessmentSubmitResponseDTO = {
    reportId,
    score: totalScore,
    riskLevel,
    modules,
  };

  return ok(response, 201);
}
