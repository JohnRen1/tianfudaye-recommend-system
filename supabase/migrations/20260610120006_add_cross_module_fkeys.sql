-- migration: 20260610120006_add_cross_module_fkeys
-- description: 补全所有跨模块悬空外键约束，并将 leads.risk_level 从 text 升级为 risk_level_enum
-- depends_on:
--   20260610120002_create_materials_table   (materials, material_claims)
--   20260610120003_create_leads_table       (leads)
--   20260610120004_create_assessment_table  (risk_level_enum)
--   20260610120005_create_qa_records_table  (qa_records)
-- rollback: 见文件末尾 ROLLBACK SECTION

-- ============================================================================
-- 汇总：本 migration 补全的所有悬空外键
-- ============================================================================
--
-- 1. materials.activity_id        → activities.id          ON DELETE SET NULL
-- 2. material_claims.activity_id  → activities.id          ON DELETE SET NULL
-- 3. qa_records.lead_id           → leads.id               ON DELETE SET NULL
-- 4. leads.risk_level             升级为 risk_level_enum 类型（从 text）
-- 5. assessment_reports.lead_status 冗余字段与 leads 状态同步（无 FK，仅注释说明）
--
-- 原因说明：以上约束在各自模块 migration 中因目标表尚未创建而无法添加，
-- 统一在所有核心表创建完毕后通过本 migration 补全。
-- ============================================================================


-- ============================================================================
-- 1. materials.activity_id → activities.id
-- ============================================================================
-- 资料可关联到特定活动（活动落地页展示该活动的资料列表）。
-- ON DELETE SET NULL：删除活动时，资料不删除，仅解除关联（资料依然可用）。

ALTER TABLE public.materials
  ADD CONSTRAINT materials_activity_id_fk
    FOREIGN KEY (activity_id)
    REFERENCES public.activities(id)
    ON DELETE SET NULL;

COMMENT ON CONSTRAINT materials_activity_id_fk ON public.materials
  IS '资料关联活动外键；ON DELETE SET NULL：删除活动时资料保留，仅清空关联';


-- ============================================================================
-- 2. material_claims.activity_id → activities.id
-- ============================================================================
-- 领取记录记录来源活动（S2 归因链），用于统计各活动带来的资料领取数。
-- ON DELETE SET NULL：删除活动时保留领取记录，仅清空来源活动归因。

ALTER TABLE public.material_claims
  ADD CONSTRAINT material_claims_activity_id_fk
    FOREIGN KEY (activity_id)
    REFERENCES public.activities(id)
    ON DELETE SET NULL;

COMMENT ON CONSTRAINT material_claims_activity_id_fk ON public.material_claims
  IS '领取记录来源活动外键（S2 归因链）；ON DELETE SET NULL：删除活动时保留历史领取记录';


-- ============================================================================
-- 3. qa_records.lead_id → leads.id
-- ============================================================================
-- 问答记录在生成线索后关联 lead_id，支持从问答跳转到线索详情。
-- ON DELETE SET NULL：删除线索时问答记录保留（历史记录不丢失），仅清空关联。

ALTER TABLE public.qa_records
  ADD CONSTRAINT qa_records_lead_id_fk
    FOREIGN KEY (lead_id)
    REFERENCES public.leads(id)
    ON DELETE SET NULL;

COMMENT ON CONSTRAINT qa_records_lead_id_fk ON public.qa_records
  IS '问答记录关联线索外键；ON DELETE SET NULL：删除线索时问答记录保留';


-- ============================================================================
-- 4. leads.risk_level 从 text 升级为 risk_level_enum
-- ============================================================================
-- migration 3 创建 leads 表时，risk_level_enum 尚未定义（由 migration 4 定义），
-- 因此暂时使用 text 类型。现在 risk_level_enum 已存在，执行类型升级。
--
-- 升级步骤：
--   a. 删除旧的 CHECK 约束（若有）
--   b. 使用 USING 子句将 text 值转换为枚举值
--   c. 添加 NOT NULL 约束（leads.risk_level 允许 null，保持 nullable）

ALTER TABLE public.leads
  ALTER COLUMN risk_level
    TYPE public.risk_level_enum
    USING risk_level::public.risk_level_enum;

COMMENT ON COLUMN public.leads.risk_level
  IS '风险等级枚举（已升级为 risk_level_enum），冗余自 assessment_reports，null 表示未完成测评';


-- ============================================================================
-- 5. 同步验证：确认所有 FK 已正确添加（查询系统表）
-- ============================================================================
-- 以下为可选验证 SQL，可在本地执行确认：
--
--   SELECT
--     tc.table_name,
--     kcu.column_name,
--     ccu.table_name  AS foreign_table,
--     ccu.column_name AS foreign_column,
--     rc.delete_rule
--   FROM information_schema.table_constraints AS tc
--   JOIN information_schema.key_column_usage AS kcu
--     ON tc.constraint_name = kcu.constraint_name
--   JOIN information_schema.constraint_column_usage AS ccu
--     ON ccu.constraint_name = tc.constraint_name
--   JOIN information_schema.referential_constraints AS rc
--     ON rc.constraint_name = tc.constraint_name
--   WHERE tc.constraint_type = 'FOREIGN KEY'
--     AND tc.table_name IN ('materials', 'material_claims', 'qa_records', 'leads')
--   ORDER BY tc.table_name, kcu.column_name;
--
-- 预期结果：
--   materials        | activity_id  | activities | id | SET NULL
--   material_claims  | activity_id  | activities | id | SET NULL
--   qa_records       | lead_id      | leads      | id | SET NULL
--
-- leads.risk_level 类型验证：
--   SELECT column_name, data_type, udt_name
--   FROM information_schema.columns
--   WHERE table_name = 'leads' AND column_name = 'risk_level';
-- 预期：data_type = 'USER-DEFINED', udt_name = 'risk_level_enum'


-- ============================================================================
-- ROLLBACK SECTION
-- ============================================================================
-- 执行顺序与正文相反。
--
-- -- 4. 将 leads.risk_level 降级回 text
-- ALTER TABLE public.leads
--   ALTER COLUMN risk_level TYPE text USING risk_level::text;
--
-- -- 3. 删除 qa_records.lead_id FK
-- ALTER TABLE public.qa_records
--   DROP CONSTRAINT IF EXISTS qa_records_lead_id_fk;
--
-- -- 2. 删除 material_claims.activity_id FK
-- ALTER TABLE public.material_claims
--   DROP CONSTRAINT IF EXISTS material_claims_activity_id_fk;
--
-- -- 1. 删除 materials.activity_id FK
-- ALTER TABLE public.materials
--   DROP CONSTRAINT IF EXISTS materials_activity_id_fk;
