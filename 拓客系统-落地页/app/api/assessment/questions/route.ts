import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { ok, fail } from '@/lib/api-response';
import {
  ASSESSMENT_MODULE_LABEL,
  type AssessmentModuleKey,
  type QuestionPublicDTO,
  type QuestionType,
} from '@/lib/contracts/assessment';

/**
 * GET /api/assessment/questions
 * 公开接口，无需认证。
 * 返回活跃题目列表，故意省略 options.score（S5 安全约定）。
 */
export async function GET(_req: NextRequest) {
  const serviceClient = createServiceClient();

  const { data: rows, error } = await serviceClient
    .from('assessment_questions')
    .select('id, module_key, type, title, description, sort_order, options')
    .eq('is_active', true)
    .order('sort_order', { ascending: true });

  if (error) {
    return fail('QUESTIONS_FETCH_FAILED', '题库加载失败', 500, error.message);
  }

  if (!rows || rows.length === 0) {
    return ok<QuestionPublicDTO[]>([]);
  }

  const questions: QuestionPublicDTO[] = rows.map((row) => {
    const moduleKey = row.module_key as AssessmentModuleKey;

    // options JSONB: Array<{ sort_order: number; label: string; score: number; ... }>
    // 故意只取 sort_order 和 label，丢弃 score（S5）
    const rawOptions = Array.isArray(row.options) ? row.options : [];
    const options = rawOptions.map((opt: Record<string, unknown>) => ({
      sortOrder: opt.sort_order as number,
      label: opt.label as string,
    }));

    return {
      id: row.id as string,
      moduleKey,
      moduleName: ASSESSMENT_MODULE_LABEL[moduleKey] ?? moduleKey,
      type: row.type as QuestionType,
      title: row.title as string,
      description: (row.description as string | null) ?? '',
      sortOrder: row.sort_order as number,
      options,
    };
  });

  return ok(questions);
}
