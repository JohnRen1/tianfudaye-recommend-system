---
name: project-qa-knowledge-module
description: 问答记录与知识库模块 migration 设计决策，risk_level_enum 定义位置，lead_id 悬空外键状态
metadata:
  type: project
---

问答记录与知识库模块 migration 文件为 `20260610120005_create_qa_records_table.sql`，于 2026-06-10 完成。

**Why:** S3 审计高风险项（落地页 AI 问答无持久化路径），admin 侧 qa-records 页面看不到任何真实数据；knowledge_items 同时服务落地页 FAQ 动态化和 RAG 预留。

**How to apply:** 以下决策在后续任务（后端 API 实现、知识库管理 API）中应遵守：

## 枚举类型

- `risk_level_enum`（low/medium/high/critical）在本 migration（20260610120005）中首次定义，前序 migration 0-4 中均未定义。
- `knowledge_item_status_enum`（active/pending/inactive）和 `knowledge_item_type_enum`（faq/policy/case/manual）均在本 migration 定义。

## 核心设计决策

1. `uncertain → medium + needs_confirmation` 映射：落地页 `riskLevel="uncertain"` 落库时写入 `risk_level='medium'` + `needs_confirmation=true`，不新增枚举值。
2. `ai_answer` 用 JSONB 存完整 AiAnswerBodyDTO，同时冗余出 `risk_level`/`advisor_recommended`/`needs_confirmation` 三个独立列用于 B-Tree 索引加速查询。双写由服务层维护，不加 CHECK 约束。
3. `qa_records.lead_id` 无 FK constraint（leads 表由并行 migration 20260610120003 创建）。补全 migration 应在 20260610120003 执行后添加：`ALTER TABLE public.qa_records ADD CONSTRAINT qa_records_lead_id_fk FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE SET NULL`。
4. `qa_record_knowledge_refs` 关联表当前阶段始终为空（RAG 未接入），`knowledgeItemIds=[]`。接入 RAG 后由服务端批量写入，trigger `qa_refs_increment_knowledge` 自动递增 `knowledge_items.refs`。

## 待完成

- `qa_records.lead_id` FK 待 migration 20260610120003（leads 表）执行后通过新 migration 补全，参见 `docs/database/问答记录与知识库.md` 第 10 节。

## 文件位置

- Migration: `supabase/migrations/20260610120005_create_qa_records_table.sql`
- 文档: `docs/database/问答记录与知识库.md`
