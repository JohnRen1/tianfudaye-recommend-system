---
name: project-assessment-module-migration
description: 测评报告模块 migration 已完成，记录关键设计决策、安全约束和枚举说明
metadata:
  type: project
---

测评报告模块 migration 已于 2026-06-10 完成，创建了以下文件：
- `supabase/migrations/20260610120004_create_assessment_table.sql`
- `docs/database/测评报告.md`

**Why:** 修复审计高风险项：评分全在客户端（无后端记录）、report.user 姓名字符串关联、answers 含义双重、题库模块与报告模块映射断裂。

**How to apply:** 本 migration 依赖 20260610120001（activities/qr_codes 表）。risk_level_enum 在本 migration 中首次定义（前三个 migration 均未定义），后续 migration 可直接引用。

## 关键设计决策

- `risk_level_enum` 在本 migration（20260610120004）中首次定义，前三个 migration 均未定义此枚举。后续模块如需引用 risk_level_enum，依赖本 migration 即可。
- `assessment_reports.user_id` 允许 null（匿名测评 S5 不确定项 #5）；匿名报告通过 claim API 绑定 userId，该操作由服务端以 Service Role 执行（绕过 RLS），API 层负责 token 验证。
- `report_raw_answers` 只存 `selected_indexes`（选项 sort_order 索引），不存 score 权重（S5 安全约束）：防止历史数据反推评分模型。服务端重算分数时 JOIN `assessment_questions.options` 取 score。
- `assessment_questions.options` 是 JSONB 数组，格式 `{sort_order, label, score}`。落地页 API 返回时由 API 层过滤 score 字段（RLS 无法做列级过滤）。
- `(report_id, question_id)` UNIQUE 约束保证答题幂等写入（重复提交同一道题不报错，ON CONFLICT DO NOTHING）。
- `report_raw_answers.question_id` 使用 ON DELETE RESTRICT：题目在有关联答题记录时不能被删除，保护历史数据可追溯性。软下线通过 `is_active=false` 实现，不硬删除题目。
- `assessment_reports` 四个外键（user_id / advisor_id / source_qr_id / source_activity_id）均使用 ON DELETE SET NULL：任何关联实体删除时报告本身保留。
- `modules` 和 `suggestions` 存 JSONB（而非拆成独立表）：结构稳定，查询时整体读取，不需要跨行 JOIN；ModuleScoreDTO 字段含 module_key/score/risk_level/desc/advice。
- `lead_status` 冗余存储在 assessment_reports（主数据在 leads 表）：便于运营列表页快速筛选，更新时由业务层负责同步。
- 题库模块（8 个）→ 报告模块（5 个）映射：company_basic + vat 用于综合分计算不出卡片；income_tax + cost_expense → report_cost 合并。此映射为产品草稿，实现时须以最终确认版为准。
- `assessment_questions_select_active` 和 `assessment_questions_select_by_manager` 两条 SELECT 策略并存，Supabase 取 OR：manager 可见全部题目，匿名用户只见 is_active=true 的题目，行为符合预期。

## 题库模块 → 报告模块映射（草稿）

| 题库模块 | 报告模块 |
|---------|---------|
| invoice_compliance | report_invoice |
| fund_transfer | report_fund |
| income_tax + cost_expense | report_cost |
| payroll_insurance | report_payroll |
| tax_audit | report_audit |
| company_basic | 综合分（不出卡片） |
| vat | 综合分（不出卡片） |

## 待完成

- 产品最终确认题库模块→报告模块映射关系（当前为草稿）
- 产品最终确认 risk_level 分数阈值（≥85/≥65/≥35 为临时占位，审计不确定项 #1）
- 真实业务题库通过管理员接口入库（替换 seed 中 3 道示例题目）
- 匿名报告 claim API 实现（Service Role 执行 UPDATE user_id，API 层验证 token）
