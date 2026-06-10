-- migration: 20260610120005_create_qa_records_table
-- description: 创建 knowledge_items、qa_records、qa_record_knowledge_refs 表
-- depends_on: 20260610120004_create_assessment_table
-- note: qa_records.lead_id FK 待 20260610120003_create_leads_table 执行后通过新 migration 补全
-- note: risk_level_enum 已在 20260610120004_create_assessment_table 中定义，本 migration 直接使用
--       lead_id 当前无 FK constraint（leads 表由并行 migration 3 创建），
--       仅作普通 uuid 列存储；补全 migration 应执行：
--         ALTER TABLE public.qa_records
--           ADD CONSTRAINT qa_records_lead_id_fk
--             FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE SET NULL;
-- rollback: 见文件末尾 ROLLBACK SECTION

-- ============================================================================
-- 依赖说明
-- ============================================================================
-- 本 migration 依赖：
--   20260610120000_create_users_table   — 提供 public.users、public.admin_users、
--                                         public.set_updated_at()、public.is_admin()、
--                                         public.get_my_admin_role()、pg_trgm 扩展
--   20260610120001_create_activities_qrcodes_table — 提供 public.activities
--
-- 以下外键约束因目标表尚未创建，暂以注释说明，待对应 migration 执行后补全：
--   qa_records.lead_id → leads.id  (待 20260610120003 执行后通过新 migration 添加)

-- ============================================================================
-- 枚举类型
-- ============================================================================

-- risk_level_enum 已在 20260610120004_create_assessment_table 中定义，此处直接使用。
-- 值：low / medium / high / critical
-- 注：落地页 riskLevel="uncertain" 落库时映射为 risk_level='medium' + needs_confirmation=true，
--     不新增 "uncertain" 枚举值（已决策）。

-- 知识库条目状态枚举
CREATE TYPE public.knowledge_item_status_enum AS ENUM (
  'active',    -- 生效中：对外开放（落地页客服 FAQ 可见）
  'pending',   -- 待审核：已上传，尚未审核
  'inactive'   -- 已停用：不对外展示，保留数据
);

-- 知识库条目类型枚举
CREATE TYPE public.knowledge_item_type_enum AS ENUM (
  'faq',       -- 常见问题（落地页客服页 FAQ 来源）
  'policy',    -- 政策法规
  'case',      -- 案例
  'manual'     -- 操作手册
);

-- ============================================================================
-- TABLE: public.knowledge_items
-- ============================================================================
-- 知识库条目，服务两个场景：
--   1. 落地页客服页（support/page.tsx）FAQ 动态数据来源（type='faq', status='active'）
--   2. RAG 预留：接入真实 AI 后，AI 回答引用的知识库条目记录在
--      qa_record_knowledge_refs 关联表中，并原子递增 refs 计数。
--
-- 当前阶段（RAG 未接入）：
--   qa_record_knowledge_refs 表为空，refs 列始终为 0。
--   落地页 FAQ 可直接查 WHERE type='faq' AND status='active'。
--
-- content 字段存全文，是 RAG 切片的数据来源，当前阶段可为空字符串。
-- summary 字段存摘要，用于知识库列表展示（knowledge-base/page.tsx），
--   不是 content 的截断，而是独立维护的精炼摘要。

CREATE TABLE public.knowledge_items (
  -- 主键：UUID，由数据库自动生成
  id              uuid                              NOT NULL DEFAULT gen_random_uuid(),

  -- 知识条目标题，不允许为空字符串
  title           text                              NOT NULL,

  -- 摘要，列表展示用（knowledge-base/page.tsx 列表副标题）
  -- 可为空字符串（新建时尚未填写摘要）
  summary         text                              NOT NULL DEFAULT '',

  -- 全文内容，RAG 切片用
  -- 当前阶段可为空字符串；接入 RAG 后此字段为向量化的数据来源
  content         text                              NOT NULL DEFAULT '',

  -- 知识条目类型枚举
  type            public.knowledge_item_type_enum   NOT NULL,

  -- 知识条目状态枚举，默认待审核
  status          public.knowledge_item_status_enum NOT NULL DEFAULT 'pending',

  -- 版本号（如"1.0"、"2.1"），运营手动维护
  -- 对应 knowledge-base/page.tsx 列表中的版本号展示
  version         text                              NOT NULL DEFAULT '1.0',

  -- 生效日期（date，仅日期无时间）
  -- null 表示无生效日期限制（立即生效）
  valid_from      date                                       DEFAULT NULL,

  -- 失效日期（date，仅日期无时间）
  -- null 表示长期有效
  valid_to        date                                       DEFAULT NULL,

  -- 备注（来源说明、审核意见等）
  -- 对应 knowledge-base/page.tsx 详情抽屉的 note 字段
  note            text                                       DEFAULT NULL,

  -- AI 引用次数（原子递增，由 qa_refs_increment_knowledge trigger 维护）
  -- 每次 qa_record_knowledge_refs 新增一行时 +1
  -- 不允许为负数；当前阶段（RAG 未接入）始终为 0
  refs            integer                           NOT NULL DEFAULT 0,

  -- 上传人（admin_users 外键）
  -- ON DELETE SET NULL：管理员账号删除后知识条目仍保留，仅清除上传人关联
  uploader_id     uuid                                       DEFAULT NULL
                    REFERENCES public.admin_users(id) ON DELETE SET NULL,

  -- 创建时间（UTC），由数据库自动填充
  created_at      timestamptz                       NOT NULL DEFAULT now(),

  -- 更新时间（UTC），由 trigger 自动维护
  updated_at      timestamptz                       NOT NULL DEFAULT now(),

  -- ── 约束 ──────────────────────────────────────────────────────────────────

  CONSTRAINT knowledge_items_pkey PRIMARY KEY (id),

  -- title 不允许为空字符串（包含空白字符视为非法）
  CONSTRAINT knowledge_items_title_not_empty_ck
    CHECK (length(trim(title)) > 0),

  -- refs 不允许为负数（原子递增，初始为 0）
  CONSTRAINT knowledge_items_refs_non_negative_ck
    CHECK (refs >= 0),

  -- valid_to 必须晚于 valid_from（仅在两者都不为 null 时校验）
  CONSTRAINT knowledge_items_valid_period_ck
    CHECK (
      valid_from IS NULL
      OR valid_to IS NULL
      OR valid_to > valid_from
    )
);

COMMENT ON TABLE  public.knowledge_items                IS '知识库条目：FAQ / 政策 / 案例 / 手册，服务落地页 FAQ 和 RAG 预留';
COMMENT ON COLUMN public.knowledge_items.id             IS 'UUID 主键';
COMMENT ON COLUMN public.knowledge_items.title          IS '知识条目标题，不允许为空字符串';
COMMENT ON COLUMN public.knowledge_items.summary        IS '摘要（精炼，非 content 截断），列表展示用';
COMMENT ON COLUMN public.knowledge_items.content        IS '全文内容，RAG 切片数据来源；当前阶段可为空字符串';
COMMENT ON COLUMN public.knowledge_items.type           IS '知识类型枚举：faq / policy / case / manual';
COMMENT ON COLUMN public.knowledge_items.status         IS '状态枚举：active（生效中）/ pending（待审核）/ inactive（已停用）';
COMMENT ON COLUMN public.knowledge_items.version        IS '版本号（如"1.0"），运营手动维护';
COMMENT ON COLUMN public.knowledge_items.valid_from     IS '生效日期（仅日期），null 表示无起始限制';
COMMENT ON COLUMN public.knowledge_items.valid_to       IS '失效日期（仅日期），null 表示长期有效';
COMMENT ON COLUMN public.knowledge_items.note           IS '备注：来源说明、审核意见等，可为 null';
COMMENT ON COLUMN public.knowledge_items.refs           IS 'AI 引用次数，原子递增（trigger）；当前阶段（RAG 未接入）始终为 0';
COMMENT ON COLUMN public.knowledge_items.uploader_id    IS '上传人 admin_users.id（外键），ON DELETE SET NULL';
COMMENT ON COLUMN public.knowledge_items.created_at     IS '创建时间（UTC）';
COMMENT ON COLUMN public.knowledge_items.updated_at     IS '最近修改时间（UTC），trigger 自动更新';

-- updated_at 自动更新 trigger
CREATE TRIGGER knowledge_items_set_updated_at
  BEFORE UPDATE ON public.knowledge_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- TABLE: public.qa_records
-- ============================================================================
-- AI 问答记录（S3：修复落地页问答无落库逻辑的核心审计问题）。
--
-- 写入路径：落地页 POST /api/ai/chat → 服务端 AI 生成回答 → 落库到此表。
-- 读取路径：admin-system qa-records/page.tsx 列表/详情/统计。
--
-- JSONB 设计决策：
--   ai_answer 存完整 AiAnswerBodyDTO 结构体（JSONB），保证 AI 回答原始格式不丢失。
--   从 JSONB 解构出 risk_level / advisor_recommended / needs_confirmation 作为独立列，
--   原因：高频筛选字段用独立列的 B-Tree 索引，性能远优于 JSONB 操作符查询。
--   双写一致性由业务层（Service Action）维护，数据库不加 CHECK 约束（AI 回答可能被服务端后处理）。
--
-- user_id 可为 null：未登录用户也可提问（落地页匿名使用场景）。
-- lead_id 当前无 FK constraint：leads 表由并行 migration 3 创建，
--   FK 在 20260610120003 执行后通过新 migration 补全（见文件头部 note）。

CREATE TABLE public.qa_records (
  -- 主键：UUID，由数据库自动生成
  id                   uuid                       NOT NULL DEFAULT gen_random_uuid(),

  -- 提问用户外键（S1：不存姓名字符串，存 UUID 外键）
  -- 可为 null：未登录用户匿名提问场景
  -- ON DELETE SET NULL：用户删除后保留问答记录（审计/历史价值），仅清除关联
  user_id              uuid                                DEFAULT NULL
                         REFERENCES public.users(id) ON DELETE SET NULL,

  -- 来源活动外键（S1 归因链）
  -- 可为 null：用户直接访问问答页（无活动上下文）
  -- ON DELETE SET NULL：活动删除后保留问答记录
  activity_id          uuid                                DEFAULT NULL
                         REFERENCES public.activities(id) ON DELETE SET NULL,

  -- 多轮对话会话 id（S5：多轮上下文支持）
  -- 首次提问时服务端生成并返回，后续提问携带以关联同一会话
  -- null 表示单次独立问答（无多轮上下文）
  session_id           text                                DEFAULT NULL,

  -- ── AI 问答内容 ──────────────────────────────────────────────────────────

  -- 用户提问原文（S4：替代 mock 中的 originalQuestion）
  -- 长度约束：1-2000 字符（对应错误码 AI_CHAT_QUESTION_TOO_LONG）
  question             text                       NOT NULL,

  -- AI 生成的问题摘要（admin 列表展示，不截断 question）
  -- 服务端 AI 生成，可为空字符串（旧数据迁移场景）
  summary              text                       NOT NULL DEFAULT '',

  -- AI 回答完整结构体（JSONB）
  -- 对应 AiAnswerBodyDTO：
  --   questionUnderstanding: string
  --   initialJudgment: string
  --   involvedRisks: string[]
  --   suggestions: string[]
  --   riskLevel: 'low'|'medium'|'high'|'critical'
  --   advisorRecommended: boolean
  --   needsConfirmation: boolean
  --   knowledgeItemIds: string[]  （RAG 预留，当前阶段为 []）
  -- 必须为 JSON object（非 array / null / string）
  ai_answer            jsonb                      NOT NULL,

  -- ── 高频查询冗余列（从 ai_answer JSONB 解构，避免 JSONB 操作符查询）──────

  -- 风险等级（S4：统一英文四值枚举）
  -- 冗余自 ai_answer->>'riskLevel'，由业务层双写维护
  -- 落地页 uncertain=true 落库时映射为 risk_level='medium' + needs_confirmation=true
  risk_level           public.risk_level_enum     NOT NULL,

  -- 是否建议人工顾问介入（S4：统一字段名 advisor_recommended，替代 mock 的 manual）
  -- 冗余自 ai_answer->>'advisorRecommended'
  advisor_recommended  boolean                    NOT NULL DEFAULT false,

  -- 是否为"建议结合实际确认"状态（落地页 uncertain 映射字段）
  -- 冗余自 ai_answer->>'needsConfirmation'
  -- true 时 risk_level 固定为 'medium'（业务层维护）
  needs_confirmation   boolean                    NOT NULL DEFAULT false,

  -- AI 自动打标的标签数组（如 ['公转私', '资金流水异常']）
  -- GIN 索引支持 @> 标签包含查询
  tags                 text[]                     NOT NULL DEFAULT '{}',

  -- 问题类型（如"公转私风险"/"政策咨询"/"申报异常"）
  -- AI 自动分类，由业务层写入
  type                 text                       NOT NULL DEFAULT '',

  -- ── 管理员操作字段 ─────────────────────────────────────────────────────────

  -- 分配的顾问外键（S1：不存顾问姓名字符串）
  -- ON DELETE SET NULL：顾问账号删除后清除分配关联（记录保留）
  assigned_advisor_id  uuid                                DEFAULT NULL
                         REFERENCES public.admin_users(id) ON DELETE SET NULL,

  -- 顾问备注（独立字段，不覆盖 AI 生成的 ai_answer 内容）
  -- 审计不确定项 #2 决策：AI 回答只读，顾问意见独立存储
  advisor_note         text                                DEFAULT NULL,

  -- 是否已生成线索（冗余标志，避免 JOIN leads 表的高频查询）
  has_lead             boolean                    NOT NULL DEFAULT false,

  -- 关联线索 UUID
  -- 注意：此列暂无 FK constraint（leads 表由并行 migration 3 创建）
  -- 待 20260610120003_create_leads_table 执行后通过新 migration 补全：
  --   ALTER TABLE public.qa_records
  --     ADD CONSTRAINT qa_records_lead_id_fk
  --       FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE SET NULL;
  lead_id              uuid                                DEFAULT NULL,

  -- ── 时间戳 ────────────────────────────────────────────────────────────────
  created_at           timestamptz                NOT NULL DEFAULT now(),
  updated_at           timestamptz                NOT NULL DEFAULT now(),

  -- ── 约束 ──────────────────────────────────────────────────────────────────

  CONSTRAINT qa_records_pkey PRIMARY KEY (id),

  -- question 长度：1-2000 字符
  -- 空字符串对应错误码 AI_CHAT_QUESTION_EMPTY，超长对应 AI_CHAT_QUESTION_TOO_LONG
  CONSTRAINT qa_records_question_length_ck
    CHECK (length(question) BETWEEN 1 AND 2000),

  -- ai_answer 必须是 JSON object（非 array / null / primitive）
  -- 防止业务层意外写入非结构化数据
  CONSTRAINT qa_records_ai_answer_is_object_ck
    CHECK (jsonb_typeof(ai_answer) = 'object')
);

COMMENT ON TABLE  public.qa_records                        IS 'AI 问答记录（S3：修复落地页问答无落库问题）';
COMMENT ON COLUMN public.qa_records.id                     IS 'UUID 主键';
COMMENT ON COLUMN public.qa_records.user_id                IS '提问用户外键（S1），null 表示未登录匿名提问；ON DELETE SET NULL';
COMMENT ON COLUMN public.qa_records.activity_id            IS '来源活动外键（S1 归因），null 表示无活动上下文；ON DELETE SET NULL';
COMMENT ON COLUMN public.qa_records.session_id             IS '多轮对话会话 id，首次提问由服务端生成，后续提问携带；null 表示单次独立问答';
COMMENT ON COLUMN public.qa_records.question               IS '用户提问原文，1-2000 字符';
COMMENT ON COLUMN public.qa_records.summary                IS 'AI 生成的问题摘要，admin 列表展示用，非 question 截断';
COMMENT ON COLUMN public.qa_records.ai_answer              IS 'AI 回答完整结构体（JSONB）：包含 questionUnderstanding/initialJudgment/involvedRisks[]/suggestions[]/riskLevel/advisorRecommended/needsConfirmation/knowledgeItemIds[]';
COMMENT ON COLUMN public.qa_records.risk_level             IS '风险等级冗余列（S4：英文四值枚举），冗余自 ai_answer，用于 B-Tree 索引加速筛选';
COMMENT ON COLUMN public.qa_records.advisor_recommended    IS '是否建议人工顾问介入（S4：统一字段名，替代 mock 的 manual），冗余自 ai_answer';
COMMENT ON COLUMN public.qa_records.needs_confirmation     IS '是否为"建议结合实际确认"（落地页 uncertain 映射），冗余自 ai_answer；true 时 risk_level 固定为 medium';
COMMENT ON COLUMN public.qa_records.tags                   IS 'AI 自动打标标签数组，GIN 索引支持 @> 查询';
COMMENT ON COLUMN public.qa_records.type                   IS '问题类型（如"公转私风险"），AI 自动分类';
COMMENT ON COLUMN public.qa_records.assigned_advisor_id    IS '分配的顾问外键（S1），ON DELETE SET NULL；null 表示未分配';
COMMENT ON COLUMN public.qa_records.advisor_note           IS '顾问备注，独立字段，不覆盖 ai_answer；null 表示顾问尚未添加备注';
COMMENT ON COLUMN public.qa_records.has_lead               IS '是否已生成线索（冗余标志，避免 JOIN leads 表高频查询）';
COMMENT ON COLUMN public.qa_records.lead_id                IS '关联线索 UUID；暂无 FK（leads 表由并行 migration 3 创建），待补全 migration 添加约束';
COMMENT ON COLUMN public.qa_records.created_at             IS '提问时间（UTC），由数据库自动填充';
COMMENT ON COLUMN public.qa_records.updated_at             IS '最近修改时间（UTC），trigger 自动更新';

-- updated_at 自动更新 trigger
CREATE TRIGGER qa_records_set_updated_at
  BEFORE UPDATE ON public.qa_records
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- TABLE: public.qa_record_knowledge_refs
-- ============================================================================
-- 问答记录与知识库条目的关联表（RAG 预留）。
--
-- 当前阶段（RAG 未接入）：
--   后端插入 qa_records 时此表始终为空（ai_answer.knowledgeItemIds = []）。
--   所有相关查询对此表的 COUNT 结果为 0，不影响业务正确性。
--
-- 接入 RAG 后：
--   每次 AI 回答时，服务端将引用的 knowledgeItemIds 批量写入此表。
--   trigger qa_refs_increment_knowledge 自动递增 knowledge_items.refs 计数。
--
-- 删除策略：
--   qa_record_id   → ON DELETE CASCADE：问答记录删除时级联删除引用关系
--   knowledge_item_id → ON DELETE CASCADE：知识库条目删除时清除引用关系
-- 两侧均用 CASCADE 而非 RESTRICT，是因为问答记录和知识库条目各自有独立生命周期，
-- 关联表是派生数据，任一侧删除均不应阻塞操作。

CREATE TABLE public.qa_record_knowledge_refs (
  -- 问答记录外键
  qa_record_id         uuid        NOT NULL
                         REFERENCES public.qa_records(id) ON DELETE CASCADE,

  -- 知识库条目外键
  knowledge_item_id    uuid        NOT NULL
                         REFERENCES public.knowledge_items(id) ON DELETE CASCADE,

  -- 关联创建时间（记录 AI 在何时引用了此知识条目）
  created_at           timestamptz NOT NULL DEFAULT now(),

  -- 复合主键：同一问答记录不能重复引用同一知识条目
  CONSTRAINT qa_record_knowledge_refs_pkey
    PRIMARY KEY (qa_record_id, knowledge_item_id)
);

COMMENT ON TABLE  public.qa_record_knowledge_refs                    IS '问答记录↔知识库条目关联表（RAG 预留），当前阶段始终为空';
COMMENT ON COLUMN public.qa_record_knowledge_refs.qa_record_id       IS '问答记录外键 → qa_records(id)，ON DELETE CASCADE';
COMMENT ON COLUMN public.qa_record_knowledge_refs.knowledge_item_id  IS '知识库条目外键 → knowledge_items(id)，ON DELETE CASCADE';
COMMENT ON COLUMN public.qa_record_knowledge_refs.created_at         IS '关联创建时间（UTC），记录 AI 引用知识条目的时刻';

-- ============================================================================
-- 索引
-- ============================================================================

-- ---------- knowledge_items 索引 ----------

-- type 索引：按类型筛选（知识库列表 type 筛选，落地页 FAQ 查询 WHERE type='faq'）
CREATE INDEX idx_knowledge_items_type
  ON public.knowledge_items (type);

-- status = 'active' 部分索引：落地页 FAQ 查询的高频路径（只关心生效中的条目）
CREATE INDEX idx_knowledge_items_status_active
  ON public.knowledge_items (id)
  WHERE status = 'active';

-- status 全量索引：admin 知识库列表按状态筛选（含 pending/inactive）
CREATE INDEX idx_knowledge_items_status
  ON public.knowledge_items (status);

-- valid_from / valid_to 索引：有效期筛选（知识库列表日期范围过滤）
CREATE INDEX idx_knowledge_items_valid_from
  ON public.knowledge_items (valid_from)
  WHERE valid_from IS NOT NULL;

CREATE INDEX idx_knowledge_items_valid_to
  ON public.knowledge_items (valid_to)
  WHERE valid_to IS NOT NULL;

-- title GIN trgm 索引：标题模糊搜索（知识库列表搜索框，依赖 migration 0 的 pg_trgm 扩展）
CREATE INDEX idx_knowledge_items_title_trgm
  ON public.knowledge_items USING GIN (title extensions.gin_trgm_ops);

-- uploader_id 部分索引：按上传人筛选（知识库列表 uploader 过滤器）
CREATE INDEX idx_knowledge_items_uploader_id
  ON public.knowledge_items (uploader_id)
  WHERE uploader_id IS NOT NULL;

-- refs DESC 索引：按引用次数倒序排列（知识库列表"最多引用"排序）
CREATE INDEX idx_knowledge_items_refs_desc
  ON public.knowledge_items (refs DESC);

-- ---------- qa_records 索引 ----------

-- user_id 部分索引：查某用户的所有问答历史（端用户个人中心、用户详情页标签页）
CREATE INDEX idx_qa_records_user_id
  ON public.qa_records (user_id)
  WHERE user_id IS NOT NULL;

-- activity_id 部分索引：按来源活动筛选（admin 问答列表 activityId 筛选，S1 修复）
CREATE INDEX idx_qa_records_activity_id
  ON public.qa_records (activity_id)
  WHERE activity_id IS NOT NULL;

-- session_id 部分索引：按会话分组查询（多轮对话聚合）
CREATE INDEX idx_qa_records_session_id
  ON public.qa_records (session_id)
  WHERE session_id IS NOT NULL;

-- risk_level 索引：风险等级筛选（admin 问答列表 riskLevel 筛选，统计卡片高风险计算）
CREATE INDEX idx_qa_records_risk_level
  ON public.qa_records (risk_level);

-- advisor_recommended = true 部分索引：筛选建议转人工的记录（统计卡片 advisorRecommended 计算）
CREATE INDEX idx_qa_records_advisor_recommended
  ON public.qa_records (advisor_recommended)
  WHERE advisor_recommended = true;

-- needs_confirmation = true 部分索引：筛选需要确认的记录
CREATE INDEX idx_qa_records_needs_confirmation
  ON public.qa_records (needs_confirmation)
  WHERE needs_confirmation = true;

-- assigned_advisor_id 部分索引：查某顾问分配的问答记录
CREATE INDEX idx_qa_records_assigned_advisor_id
  ON public.qa_records (assigned_advisor_id)
  WHERE assigned_advisor_id IS NOT NULL;

-- has_lead = true 部分索引：筛选已生成线索的记录
CREATE INDEX idx_qa_records_has_lead
  ON public.qa_records (has_lead)
  WHERE has_lead = true;

-- created_at DESC 索引：默认排序（admin 列表 sortBy=createdAt desc，分页稳定性）
CREATE INDEX idx_qa_records_created_at_desc
  ON public.qa_records (created_at DESC);

-- tags GIN 索引：标签包含查询（tags @> ARRAY['公转私']，admin 列表标签筛选）
CREATE INDEX idx_qa_records_tags_gin
  ON public.qa_records USING GIN (tags);

-- ---------- qa_record_knowledge_refs 索引 ----------

-- 主键 (qa_record_id, knowledge_item_id) 已覆盖 qa_record_id 前缀查询
-- 额外建 knowledge_item_id 索引：查某知识条目被哪些问答引用（反向查询）
CREATE INDEX idx_qa_refs_knowledge_item_id
  ON public.qa_record_knowledge_refs (knowledge_item_id);

-- ============================================================================
-- Trigger：knowledge_items.refs 原子递增
-- ============================================================================
-- 每当 qa_record_knowledge_refs 新增一行（AI 引用了一个知识条目），
-- 对应 knowledge_items.refs 原子递增 +1。
--
-- 设计决策：
--   用 trigger 而非应用层双写，保证 refs 计数与关联表写入的原子一致性。
--   trigger 在 AFTER INSERT 触发，不影响关联表的写入性能（异步递增）。
--   当前阶段（RAG 未接入）此 trigger 不会被触发，refs 始终为 0。

CREATE OR REPLACE FUNCTION public.increment_knowledge_refs()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.knowledge_items
  SET refs = refs + 1
  WHERE id = NEW.knowledge_item_id;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.increment_knowledge_refs() IS
  '当 qa_record_knowledge_refs 新增一行时，原子递增对应 knowledge_items.refs 计数';

CREATE TRIGGER qa_refs_increment_knowledge
  AFTER INSERT ON public.qa_record_knowledge_refs
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_knowledge_refs();

-- ============================================================================
-- Row Level Security（RLS）
-- ============================================================================

-- ---------- knowledge_items RLS ----------

ALTER TABLE public.knowledge_items ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何人（含匿名）可读取 active 状态的知识条目
-- 条件：status = 'active'
-- 用途：落地页客服页（support/page.tsx）FAQ 动态数据，无需登录即可查看
-- 注意：实际落地页 API 使用 Service Role，此策略作为直连 Supabase 客户端的兜底安全层
CREATE POLICY knowledge_items_select_active_by_all
  ON public.knowledge_items
  FOR SELECT
  USING (status = 'active');

-- 策略 2：任何已认证管理员可查询所有知识条目（含 pending/inactive）
-- 条件：is_admin()（任意活跃管理员角色）
-- 用途：admin-system 知识库管理页（knowledge-base/page.tsx）列表/详情/统计
CREATE POLICY knowledge_items_select_by_admin
  ON public.knowledge_items
  FOR SELECT
  USING (public.is_admin());

-- 策略 3：manager 可创建知识条目（market_ops 仅可查看，不能写入）
-- 注意：知识库内容影响 AI 问答质量，写权限限制于 manager 角色
-- 若业务需要开放 market_ops 写权限，修改为 IN ('market_ops', 'manager')
CREATE POLICY knowledge_items_insert_by_manager
  ON public.knowledge_items
  FOR INSERT
  WITH CHECK (public.get_my_admin_role() = 'manager');

-- 策略 4：manager 可更新知识条目（含审核通过/停用/编辑内容）
CREATE POLICY knowledge_items_update_by_manager
  ON public.knowledge_items
  FOR UPDATE
  USING (public.get_my_admin_role() = 'manager')
  WITH CHECK (public.get_my_admin_role() = 'manager');

-- 策略 5：manager 可删除知识条目
-- 建议 API 层在删除前校验条目已停用（status='inactive'），避免误删生效中的条目
CREATE POLICY knowledge_items_delete_by_manager
  ON public.knowledge_items
  FOR DELETE
  USING (public.get_my_admin_role() = 'manager');

-- 注意：Service Role（后端 API / Server Action）绕过 RLS，拥有全部权限。

-- ---------- qa_records RLS ----------

ALTER TABLE public.qa_records ENABLE ROW LEVEL SECURITY;

-- 策略 1：已登录端用户可查询自己的问答历史
-- 条件：auth.uid() = user_id
-- 用途：GET /api/ai/history（落地页个人问答历史）
CREATE POLICY qa_records_select_self
  ON public.qa_records
  FOR SELECT
  USING (auth.uid() = user_id);

-- 策略 2：已登录端用户可创建问答记录（提交问题）
-- 条件：auth.uid() = user_id
-- 注意：服务端从 JWT 读取 userId 后写入，客户端不能伪造 user_id
--       匿名用户（user_id=null）由 Service Role 处理，不经此策略
CREATE POLICY qa_records_insert_by_user
  ON public.qa_records
  FOR INSERT
  WITH CHECK (
    user_id IS NULL
    OR auth.uid() = user_id
  );

-- 策略 3：任何已认证管理员可查询所有问答记录
-- 条件：is_admin()（任意活跃管理员角色）
-- 用途：GET /api/admin/qa-records 列表/详情/统计
CREATE POLICY qa_records_select_by_admin
  ON public.qa_records
  FOR SELECT
  USING (public.is_admin());

-- 策略 4：tax_advisor / manager 可更新问答记录（分配顾问、添加备注、更新线索状态）
-- market_ops 也可分配顾问（API 契约权限矩阵），故包含 market_ops
-- 操作：
--   PATCH /api/admin/qa-records/:id/advisor       → assigned_advisor_id
--   PATCH /api/admin/qa-records/:id/advisor-note  → advisor_note
--   POST  /api/admin/qa-records/:id/lead          → has_lead / lead_id
CREATE POLICY qa_records_update_by_admin
  ON public.qa_records
  FOR UPDATE
  USING (
    public.get_my_admin_role() IN ('market_ops', 'tax_advisor', 'manager')
  )
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'tax_advisor', 'manager')
  );

-- 注意：任何角色均不能通过 RLS 删除 qa_records 行。
-- 问答记录具有审计价值，不允许物理删除；若需归档，通过 Service Role 实现软删除扩展。

-- ---------- qa_record_knowledge_refs RLS ----------

ALTER TABLE public.qa_record_knowledge_refs ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何已认证管理员可查询关联关系（查看 AI 引用了哪些知识条目）
CREATE POLICY qa_refs_select_by_admin
  ON public.qa_record_knowledge_refs
  FOR SELECT
  USING (public.is_admin());

-- 注意：
--   INSERT / UPDATE / DELETE 仅由 Service Role 执行（后端写入关联关系）。
--   普通用户和管理员均不能直接操作关联表，所有写入通过服务端接口。
--   当前阶段（RAG 未接入）此表无任何写入，策略配置为接入 RAG 后准备。

-- ============================================================================
-- 本地开发 / 测试 SEED 数据
-- ============================================================================
-- 警告：以下 seed 仅用于本地开发和 CI 测试环境，生产环境不应执行此段。
-- JSONB 示例数据使用有意义的业务语义，但不包含真实用户信息。
-- uploader_id / user_id / activity_id 引用前序 migration seed 的占位 UUID。

-- seed 知识库条目（3 条）
INSERT INTO public.knowledge_items (
  id, title, summary, content,
  type, status, version,
  valid_from, valid_to,
  note, refs, uploader_id
)
VALUES
  -- 1. FAQ / active：落地页客服页 FAQ 来源
  (
    'e0000000-0000-0000-0000-000000000001'::uuid,
    '公转私操作是否存在税务风险？',
    '解答企业老板常见的"公转私"税务疑问，明确合规操作边界。',
    '公转私是指企业资金转入法定代表人或股东个人账户的行为。'
    || '主要风险包括：1. 个人所得税合规风险——转款性质不明确可能被认定为工资薪酬或股息，'
    || '触发个税扣缴义务；2. 企业所得税风险——无真实业务背景的资金流出可能被认定为"虚假成本"；'
    || '3. 金税四期预警风险——大额频繁的公转私流水会触发系统预警，进入人工核查流程。'
    || '建议在专业税务顾问指导下，通过合规股息分红、薪酬发放等方式实现资金流动。',
    'faq',
    'active',
    '1.0',
    NULL,
    NULL,
    '高频问题，建议每季度更新政策依据',
    0,
    'a0000000-0000-0000-0000-000000000001'::uuid  -- 系统管理员上传
  ),
  -- 2. policy / active：政策法规条目
  (
    'e0000000-0000-0000-0000-000000000002',
    '金税四期税收大数据应用场景及企业应对指引',
    '梳理金税四期对企业税务核查的影响，提供合规应对建议。',
    '金税四期工程于2023年起逐步推广，核心是"以数治税"。'
    || '主要应用场景：1. 发票比对——进销项发票数据实时比对，虚开发票风险直接暴露；'
    || '2. 资金流分析——与银行大数据共享，公转私、现金交易等异常资金流自动预警；'
    || '3. 申报数据交叉比对——工资、社保、公积金数据三方比对，发现少报员工收入等问题。'
    || '企业应对建议：建立完整的业务凭证台账，确保资金流、票据流、合同流三流一致。',
    'policy',
    'active',
    '2.1',
    '2023-01-01',
    NULL,
    '政策更新频繁，需关注国家税务总局官网动态',
    0,
    'a0000000-0000-0000-0000-000000000001'::uuid
  ),
  -- 3. faq / pending：待审核，落地页不可见
  (
    'e0000000-0000-0000-0000-000000000003'::uuid,
    '零申报是否会触发税务稽查？',
    '针对长期零申报企业，分析稽查触发条件和合规建议。',
    '长期零申报（连续3个月以上申报收入为零）是金税四期重点监控场景之一。'
    || '触发稽查的常见条件：有经营活动迹象但持续申报收入为零、水电等公用事业数据与申报收入明显不符。'
    || '建议：有真实收入的企业不应以零申报规避税负，应如实申报；确实无收入时保留业务停滞证明。',
    'faq',
    'pending',   -- 待审核，落地页不可见
    '1.0',
    NULL,
    NULL,
    '运营小李提交，待审核后上线',
    0,
    'a0000000-0000-0000-0000-000000000002'::uuid  -- 运营小李上传
  )
ON CONFLICT (id) DO NOTHING;

-- seed 问答记录（2 条）
-- ai_answer JSONB 使用有意义的示例结构，不含真实用户数据
INSERT INTO public.qa_records (
  id, user_id, activity_id, session_id,
  question, summary,
  ai_answer,
  risk_level, advisor_recommended, needs_confirmation,
  tags, type,
  assigned_advisor_id, advisor_note,
  has_lead, lead_id
)
VALUES
  -- 1. 高风险 + 建议转人工
  (
    'f0000000-0000-0000-0000-000000000001'::uuid,
    'b0000000-0000-0000-0000-000000000001'::uuid,  -- 测试用户甲
    'c0000000-0000-0000-0000-000000000001'::uuid,  -- 金税四期专题课
    'sess-seed-001',
    '我们公司每个月都有大额公转私，金额在50到100万之间，这样会有风险吗？',
    '大额公转私的税务风险咨询',
    '{
      "questionUnderstanding": "用户询问每月50-100万大额公转私操作的税务合规风险，属于高风险资金流动场景。",
      "initialJudgment": "大额、高频的公转私行为是金税四期重点监控对象，当前情况存在较高的税务合规风险。",
      "involvedRisks": [
        "资金流水异常预警：月均50-100万公转私频率较高，极易触发金税四期大数据预警",
        "个人所得税风险：资金性质不明确时，可能被认定为股东分红或工资薪酬，需补缴个税",
        "企业所得税风险：若无真实业务背景，转款可能被认定为虚假支出，影响税前扣除"
      ],
      "suggestions": [
        "立即梳理近12个月公转私明细，整理每笔转款的业务凭证和说明",
        "建议通过合规股息分红流程替代直接公转私，确保三流一致",
        "尽快约税务顾问进行专项体检，评估已有操作的风险敞口"
      ],
      "riskLevel": "high",
      "advisorRecommended": true,
      "needsConfirmation": false,
      "knowledgeItemIds": []
    }'::jsonb,
    'high',
    true,
    false,
    ARRAY['公转私', '资金流水异常', '建议顾问介入'],
    '公转私风险',
    'a0000000-0000-0000-0000-000000000003'::uuid,  -- 已分配给周顾问
    '已与用户初步沟通，建议本周内预约专项诊断，重点核查近一年的资金流水记录。',
    false,
    NULL
  ),
  -- 2. 中风险 + needs_confirmation（uncertain 映射场景）
  (
    'f0000000-0000-0000-0000-000000000002'::uuid,
    'b0000000-0000-0000-0000-000000000002'::uuid,  -- 测试用户乙
    NULL,          -- 直接访问，无活动来源
    'sess-seed-002',
    '我们公司今年零申报了三个季度，但实际上有一些业务往来，只是收款都是现金，请问这样合规吗？',
    '现金收款叠加零申报的合规性咨询',
    '{
      "questionUnderstanding": "用户公司有真实业务往来和现金收款，但申报收入为零，询问此操作的税务合规性。",
      "initialJudgment": "有收入但零申报属于典型的申报不实行为，具有中等税务风险，实际风险程度需结合具体金额和行业情况确认。",
      "involvedRisks": [
        "增值税申报风险：现金收入未纳入申报，存在漏报可能，可能触发补税和滞纳金",
        "企业所得税风险：收入不入账导致账面利润失真，年度汇算清缴存在差异",
        "金税四期交叉比对风险：水电气用量、员工社保等数据与零收入申报不符时会触发预警"
      ],
      "suggestions": [
        "建议对近三个季度的现金收入进行梳理，评估补申报的必要性和时机",
        "在税务机关主动稽查前主动补申报，可降低处罚风险",
        "建议建立收入台账，将现金交易纳入财务流程管控"
      ],
      "riskLevel": "medium",
      "advisorRecommended": false,
      "needsConfirmation": true,
      "knowledgeItemIds": []
    }'::jsonb,
    'medium',
    false,
    true,          -- needs_confirmation=true（uncertain 映射）
    ARRAY['零申报', '现金收入', '申报合规'],
    '申报异常',
    NULL,          -- 未分配顾问
    NULL,
    false,
    NULL
  )
ON CONFLICT (id) DO NOTHING;

-- 注意：qa_record_knowledge_refs 表无 seed 数据（当前阶段 RAG 未接入，refs 表为空）。

-- ============================================================================
-- ROLLBACK SECTION
-- ============================================================================
-- 回滚顺序（与创建顺序相反）：
--
-- -- 1. 删除 trigger 和 trigger 函数
-- DROP TRIGGER IF EXISTS qa_refs_increment_knowledge ON public.qa_record_knowledge_refs;
-- DROP TRIGGER IF EXISTS qa_records_set_updated_at ON public.qa_records;
-- DROP TRIGGER IF EXISTS knowledge_items_set_updated_at ON public.knowledge_items;
-- DROP FUNCTION IF EXISTS public.increment_knowledge_refs();
--
-- -- 2. 删除表（依赖顺序：关联表先删，再删主表）
-- DROP TABLE IF EXISTS public.qa_record_knowledge_refs CASCADE;
-- DROP TABLE IF EXISTS public.qa_records CASCADE;
-- DROP TABLE IF EXISTS public.knowledge_items CASCADE;
--
-- -- 3. 删除枚举类型（必须在依赖表删除后执行）
-- DROP TYPE IF EXISTS public.knowledge_item_type_enum;
-- DROP TYPE IF EXISTS public.knowledge_item_status_enum;
-- DROP TYPE IF EXISTS public.risk_level_enum;
--
-- 注意：
--   CASCADE 会同时删除所有依赖对象（索引、触发器、RLS 策略）。
--   回滚不可恢复数据，执行前备份。
--   回滚不影响 migration 0-2 创建的内容。
--   若 migration 3（leads 表）已执行，其对 qa_records.lead_id 的 FK 约束
--   需在此回滚前先 DROP CONSTRAINT 或同时回滚 migration 3。
