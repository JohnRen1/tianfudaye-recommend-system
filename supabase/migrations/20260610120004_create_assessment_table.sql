-- migration: 20260610120004_create_assessment_table
-- description: 创建 assessment_questions、assessment_reports、report_raw_answers 表
-- depends_on: 20260610120001_create_activities_qrcodes_table
-- rollback: 见文件末尾

-- ============================================================================
-- 依赖说明
-- ============================================================================
-- 本 migration 依赖：
--   20260610120000_create_users_table
--     — 提供 public.users、public.admin_users、public.set_updated_at()、
--       public.is_admin()、public.get_my_admin_role()、public.lead_status_enum
--   20260610120001_create_activities_qrcodes_table
--     — 提供 public.activities、public.qr_codes
--
-- 外键关系：
--   assessment_reports.user_id         → public.users(id)         ON DELETE SET NULL
--   assessment_reports.advisor_id      → public.admin_users(id)   ON DELETE SET NULL
--   assessment_reports.source_qr_id    → public.qr_codes(id)      ON DELETE SET NULL
--   assessment_reports.source_activity_id → public.activities(id) ON DELETE SET NULL
--   report_raw_answers.report_id       → public.assessment_reports(id) ON DELETE CASCADE
--   report_raw_answers.question_id     → public.assessment_questions(id) ON DELETE RESTRICT

-- ============================================================================
-- 枚举类型
-- ============================================================================

-- 题目类型枚举
-- single: 单选；multiple: 多选；range: 区间选择（单选形式，表达数量范围）
CREATE TYPE public.question_type_enum AS ENUM (
  'single',    -- 单选题
  'multiple',  -- 多选题
  'range'      -- 区间选择（单选形式）
);

-- 题库模块枚举（8 个维度）
-- 对应 API 契约 AssessmentModuleKey，覆盖当前落地页硬编码题库的所有模块
CREATE TYPE public.assessment_module_enum AS ENUM (
  'company_basic',       -- 企业基础信息
  'invoice_compliance',  -- 发票合规风险
  'fund_transfer',       -- 公转私风险
  'income_tax',          -- 所得税风险
  'vat',                 -- 增值税风险
  'payroll_insurance',   -- 个税社保风险
  'cost_expense',        -- 成本费用风险
  'tax_audit'            -- 税务稽查应对
);

-- 报告展示模块枚举（5 个维度）
-- 对应 API 契约 ReportModuleKey，与题库 8 模块的映射关系见文档
-- company_basic 和 vat 用于综合评分，不单独出模块卡片
CREATE TYPE public.report_module_enum AS ENUM (
  'report_invoice',  -- 发票合规风险（← invoice_compliance）
  'report_fund',     -- 公转私风险（← fund_transfer）
  'report_cost',     -- 成本费用风险（← income_tax + cost_expense）
  'report_payroll',  -- 个税社保风险（← payroll_insurance）
  'report_audit'     -- 税务稽查应对风险（← tax_audit）
);

-- 风险等级枚举
-- 检查是否已在其他 migration 中定义（当前三个已有 migration 均未定义，在此创建）
-- S5：risk_level 由服务端根据 score 计算，绝不接受前端传入
-- 对应 API 契约 RiskLevel（admin + landing-page 共用）
CREATE TYPE public.risk_level_enum AS ENUM (
  'low',       -- 低风险
  'medium',    -- 中风险
  'high',      -- 高风险
  'critical'   -- 严重风险
);

-- ============================================================================
-- TABLE: public.assessment_questions
-- ============================================================================
-- 存储测评题库，替代落地页 risk-assessment-quiz-page.tsx 中的硬编码 questions 数组。
--
-- 设计决策：
--   1. 选项（options）存为 JSONB 数组，每项格式：
--      { "sort_order": 0, "label": "选项文字", "score": 5 }
--      score 权重随题库持久化，但落地页 API（GET /api/assessment/questions）
--      返回时不包含 score 字段（S5），由服务端按需读取用于评分计算。
--   2. sort_order 全局唯一，决定题目在答题页的展示顺序；
--      管理员调整顺序时需保证唯一性约束不冲突，建议先 UPDATE 到临时值再换位。
--   3. is_active 允许题目下线而不删除，保留历史答题记录的可追溯性。
--   4. description 允许为空字符串（部分题目无需补充说明）。

CREATE TABLE public.assessment_questions (
  -- 主键：UUID，数据库自动生成
  id          uuid                          NOT NULL DEFAULT gen_random_uuid(),

  -- 所属题库模块（8 个维度），决定报告评分时的模块归属
  module_key  public.assessment_module_enum NOT NULL,

  -- 题目类型：单选 / 多选 / 区间选择
  type        public.question_type_enum     NOT NULL,

  -- 题目标题，不允许为空字符串
  title       text                          NOT NULL,

  -- 题目补充说明，允许为空字符串（部分题目无需描述）
  description text                          NOT NULL DEFAULT '',

  -- 全局排序序号（1 起始），决定落地页答题顺序
  -- 唯一约束保证不出现两道题排在同一位置
  sort_order  integer                       NOT NULL,

  -- 是否启用：false 时落地页不返回该题目（软下线，不删除历史答题记录）
  is_active   boolean                       NOT NULL DEFAULT true,

  -- 选项 JSONB 数组，格式：[{ sort_order: 0, label: "...", score: 5 }, ...]
  -- sort_order: 选项排序（0 起始），前端提交 selectedIndexes 时用此值
  -- label: 选项文字（落地页展示）
  -- score: 评分权重（S5：仅服务端读取，落地页 API 不返回）
  options     jsonb                         NOT NULL DEFAULT '[]',

  -- 创建时间（UTC），由数据库自动填充
  created_at  timestamptz                   NOT NULL DEFAULT now(),

  -- 更新时间（UTC），由 trigger 自动维护
  updated_at  timestamptz                   NOT NULL DEFAULT now(),

  CONSTRAINT assessment_questions_pkey        PRIMARY KEY (id),

  -- sort_order 全局唯一：保证题目展示顺序无冲突
  CONSTRAINT assessment_questions_sort_order_uq UNIQUE (sort_order),

  -- sort_order 必须为正整数（1 起始）
  CONSTRAINT assessment_questions_sort_order_ck CHECK (sort_order > 0),

  -- title 不允许为空字符串（trim 后长度 > 0）
  CONSTRAINT assessment_questions_title_ck CHECK (length(trim(title)) > 0),

  -- options 必须是 JSON 数组（不允许存对象、字符串等其他类型）
  CONSTRAINT assessment_questions_options_ck CHECK (jsonb_typeof(options) = 'array')
);

COMMENT ON TABLE  public.assessment_questions               IS '测评题库；替代落地页硬编码 questions 数组';
COMMENT ON COLUMN public.assessment_questions.id            IS 'UUID 主键';
COMMENT ON COLUMN public.assessment_questions.module_key    IS '所属题库模块（8 维度）；决定报告评分时的模块归属';
COMMENT ON COLUMN public.assessment_questions.type          IS '题目类型：single / multiple / range';
COMMENT ON COLUMN public.assessment_questions.title         IS '题目标题，不允许为空字符串';
COMMENT ON COLUMN public.assessment_questions.description   IS '题目补充说明，允许为空字符串';
COMMENT ON COLUMN public.assessment_questions.sort_order    IS '全局排序序号（1 起始），全局唯一';
COMMENT ON COLUMN public.assessment_questions.is_active     IS '是否启用；false 时落地页不返回该题';
COMMENT ON COLUMN public.assessment_questions.options       IS 'JSONB 数组，每项 {sort_order, label, score}；score 仅服务端读取（S5）';
COMMENT ON COLUMN public.assessment_questions.created_at    IS '创建时间（UTC）';
COMMENT ON COLUMN public.assessment_questions.updated_at    IS '更新时间（UTC），由 trigger 自动维护';

-- updated_at 自动更新 trigger
CREATE TRIGGER assessment_questions_set_updated_at
  BEFORE UPDATE ON public.assessment_questions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- TABLE: public.assessment_reports
-- ============================================================================
-- 存储每次测评的结果快照。
--
-- 设计决策：
--   1. user_id 允许为 null：支持未登录匿名测评（S5 不确定项 #5）；
--      用户登录后通过 POST /api/assessment/report/:id/claim 绑定 userId。
--   2. score / risk_level 均由服务端计算后写入，API 层严禁接受前端传入（S5）。
--   3. company 存快照：报告创建时从 users.company 复制，
--      用户后续修改企业信息不影响历史报告记录。
--   4. modules / suggestions 存 JSONB：
--      modules 为 ModuleScoreDTO 数组（含 module_key/score/risk_level/desc/advice）；
--      suggestions 为 string 数组。
--      两者结构稳定，查询时整体读取，不需要跨行 JOIN。
--   5. lead_status 冗余存储：主数据在 leads 表，此字段便于运营列表页快速筛选，
--      更新时需同步维护（由业务层负责）。
--   6. viewed / booked / is_saved 均由对应 API 端点落库（S3），不依赖前端 state。

CREATE TABLE public.assessment_reports (
  -- 主键：UUID，数据库自动生成（S5：非前端传入）
  id                  uuid                        NOT NULL DEFAULT gen_random_uuid(),

  -- 用户外键，允许 null（匿名测评，S5 不确定项 #5）
  -- ON DELETE SET NULL：用户被删除时报告保留，user_id 置 null
  user_id             uuid                        DEFAULT NULL
                        REFERENCES public.users(id) ON DELETE SET NULL,

  -- 企业名称快照：报告创建时从 users.company 复制
  -- 允许为空字符串（匿名测评或用户未填写企业信息时）
  company             text                        NOT NULL DEFAULT '',

  -- 综合风险分（0–100）
  -- S5：服务端在接收答案后计算，API 层不接受前端传入此字段
  score               integer                     NOT NULL,

  -- 风险等级枚举
  -- S5：服务端根据 score 和产品配置阈值计算，API 层不接受前端传入
  risk_level          public.risk_level_enum      NOT NULL,

  -- 结构化模块评分 JSONB 数组
  -- 每项格式：{ module_key, module_name, score, risk_level, desc, advice }
  -- 对应 ModuleScoreDTO；服务端评分时按题库模块→报告模块映射规则填充
  modules             jsonb                       NOT NULL DEFAULT '[]',

  -- 整改建议 JSONB 数组（string[]）
  -- 服务端根据答题结果生成；未解锁时 API 层不返回此字段（S3）
  suggestions         jsonb                       NOT NULL DEFAULT '[]',

  -- 用户是否已解锁完整报告（POST /api/assessment/report/:id/unlock 落库）
  -- S3：后端落库，替代落地页 isUnlocked 纯前端 state
  viewed              boolean                     NOT NULL DEFAULT false,

  -- 用户是否已预约顾问（预约接口触发后落库）
  booked              boolean                     NOT NULL DEFAULT false,

  -- 用户是否已保存到"我的报告"（POST /api/assessment/report/:id/save 落库）
  -- S3：后端落库，替代落地页 isSaved 纯前端 state
  is_saved            boolean                     NOT NULL DEFAULT false,

  -- 分配顾问外键，null 表示未分配（S1：替代 mock 中 advisor 姓名字符串）
  -- ON DELETE SET NULL：顾问账号被删除时报告保留，advisor_id 置 null
  advisor_id          uuid                        DEFAULT NULL
                        REFERENCES public.admin_users(id) ON DELETE SET NULL,

  -- 线索状态冗余字段，便于运营列表页快速筛选
  -- 主数据在 leads 表，此字段更新时由业务层负责同步
  lead_status         public.lead_status_enum     NOT NULL DEFAULT 'none',

  -- 来源二维码归因（S2），允许 null
  -- ON DELETE SET NULL：二维码被删除时报告保留，source_qr_id 置 null
  source_qr_id        uuid                        DEFAULT NULL
                        REFERENCES public.qr_codes(id) ON DELETE SET NULL,

  -- 来源活动归因（S2），允许 null
  -- ON DELETE SET NULL：活动被删除时报告保留，source_activity_id 置 null
  source_activity_id  uuid                        DEFAULT NULL
                        REFERENCES public.activities(id) ON DELETE SET NULL,

  -- 测评完成时间（UTC），默认为记录创建时间
  completed_at        timestamptz                 NOT NULL DEFAULT now(),

  -- 更新时间（UTC），由 trigger 自动维护
  updated_at          timestamptz                 NOT NULL DEFAULT now(),

  CONSTRAINT assessment_reports_pkey          PRIMARY KEY (id),

  -- score 范围约束：0 到 100
  CONSTRAINT assessment_reports_score_ck      CHECK (score BETWEEN 0 AND 100),

  -- modules 必须是 JSON 数组
  CONSTRAINT assessment_reports_modules_ck    CHECK (jsonb_typeof(modules) = 'array'),

  -- suggestions 必须是 JSON 数组
  CONSTRAINT assessment_reports_suggestions_ck CHECK (jsonb_typeof(suggestions) = 'array')
);

COMMENT ON TABLE  public.assessment_reports                    IS '测评报告；每次测评的结果快照';
COMMENT ON COLUMN public.assessment_reports.id                 IS 'UUID 主键（S5：服务端生成）';
COMMENT ON COLUMN public.assessment_reports.user_id            IS '用户外键，允许 null（匿名测评）；登录后通过 claim 接口绑定';
COMMENT ON COLUMN public.assessment_reports.company            IS '企业名称快照（报告创建时复制，保留历史记录）';
COMMENT ON COLUMN public.assessment_reports.score              IS '综合风险分 0-100（S5：服务端计算）';
COMMENT ON COLUMN public.assessment_reports.risk_level         IS '风险等级（S5：服务端根据 score 计算）';
COMMENT ON COLUMN public.assessment_reports.modules            IS 'ModuleScoreDTO[] JSONB；每项含 module_key/score/risk_level/desc/advice';
COMMENT ON COLUMN public.assessment_reports.suggestions        IS '整改建议 string[] JSONB；未解锁用户 API 层不返回';
COMMENT ON COLUMN public.assessment_reports.viewed             IS '用户已解锁完整报告（S3：unlock API 落库）';
COMMENT ON COLUMN public.assessment_reports.booked             IS '用户已预约顾问（S3：预约 API 落库）';
COMMENT ON COLUMN public.assessment_reports.is_saved           IS '用户已保存到"我的报告"（S3：save API 落库）';
COMMENT ON COLUMN public.assessment_reports.advisor_id         IS '分配顾问外键（S1：替代 mock advisor 姓名字符串）；null 表示未分配';
COMMENT ON COLUMN public.assessment_reports.lead_status        IS '线索状态冗余字段（主数据在 leads 表，便于运营列表快速筛选）';
COMMENT ON COLUMN public.assessment_reports.source_qr_id       IS '来源二维码归因（S2）';
COMMENT ON COLUMN public.assessment_reports.source_activity_id IS '来源活动归因（S2）';
COMMENT ON COLUMN public.assessment_reports.completed_at       IS '测评完成时间（UTC）';
COMMENT ON COLUMN public.assessment_reports.updated_at         IS '更新时间（UTC），由 trigger 自动维护';

-- updated_at 自动更新 trigger
CREATE TRIGGER assessment_reports_set_updated_at
  BEFORE UPDATE ON public.assessment_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- TABLE: public.report_raw_answers
-- ============================================================================
-- 存储每份报告的原始答题记录，每道题一行。
--
-- 设计决策：
--   1. 仅存 selected_indexes（选项 sort_order 索引数组），不存 score（S5）：
--      防止历史答题记录暴露选项权重，避免通过历史数据反推评分模型。
--      服务端需要重新计算分数时，从 assessment_questions.options 读取 score。
--   2. (report_id, question_id) 唯一约束：每份报告对每道题只能有一条记录，
--      保证提交幂等性（重复提交相同答案不会造成重复记录）。
--   3. ON DELETE CASCADE：报告删除时，对应的所有答题记录同步删除。
--   4. ON DELETE RESTRICT：题目不能在有关联答题记录时被删除，保护数据完整性。
--   5. 无 updated_at：答题记录一经创建不可修改（仅服务端在提交时写入一次）。

CREATE TABLE public.report_raw_answers (
  -- 主键：UUID，数据库自动生成
  id               uuid     NOT NULL DEFAULT gen_random_uuid(),

  -- 所属报告外键
  -- ON DELETE CASCADE：报告删除时对应答题记录同步删除
  report_id        uuid     NOT NULL
                     REFERENCES public.assessment_reports(id) ON DELETE CASCADE,

  -- 所属题目外键
  -- ON DELETE RESTRICT：题目不能在有关联答题记录时被删除（保护数据可追溯性）
  question_id      uuid     NOT NULL
                     REFERENCES public.assessment_questions(id) ON DELETE RESTRICT,

  -- 所选选项的 sort_order 索引数组
  -- 单选题：[0]；多选题：[0, 2]；区间选择：[1]
  -- S5：不存 score，防止历史数据反推权重
  selected_indexes integer[] NOT NULL DEFAULT '{}',

  -- 创建时间（UTC），由数据库自动填充
  created_at       timestamptz NOT NULL DEFAULT now(),

  -- 无 updated_at：答题记录一经创建不可修改

  CONSTRAINT report_raw_answers_pkey    PRIMARY KEY (id),

  -- 每份报告对每道题只能有一条记录（幂等写入保障）
  CONSTRAINT report_raw_answers_report_question_uq UNIQUE (report_id, question_id)
);

COMMENT ON TABLE  public.report_raw_answers                  IS '原始答题记录；每份报告每道题一行，不存 score（S5）';
COMMENT ON COLUMN public.report_raw_answers.id               IS 'UUID 主键';
COMMENT ON COLUMN public.report_raw_answers.report_id        IS '所属报告外键（CASCADE 删除）';
COMMENT ON COLUMN public.report_raw_answers.question_id      IS '所属题目外键（RESTRICT 删除）';
COMMENT ON COLUMN public.report_raw_answers.selected_indexes IS '所选选项的 sort_order 索引数组（S5：不存 score）';
COMMENT ON COLUMN public.report_raw_answers.created_at       IS '创建时间（UTC）；答题记录不可修改，无 updated_at';

-- ============================================================================
-- 索引
-- ============================================================================

-- ---------- assessment_questions 索引 ----------

-- module_key 索引：按模块筛选题目（管理员题库管理 / 服务端评分时按模块读题）
CREATE INDEX idx_assessment_questions_module_key
  ON public.assessment_questions (module_key);

-- is_active 部分索引：落地页 GET /api/assessment/questions 只取启用题目
-- 使用部分索引节省存储，停用题目不进入索引
CREATE INDEX idx_assessment_questions_active
  ON public.assessment_questions (sort_order)
  WHERE is_active = true;

-- sort_order 唯一索引已由 UNIQUE constraint 隐式创建，无需重复添加

-- ---------- assessment_reports 索引 ----------

-- user_id 部分索引：查询某用户的所有报告（GET /api/assessment/my-reports）
-- 部分索引排除匿名报告（user_id IS NULL），减少索引体积
CREATE INDEX idx_assessment_reports_user_id
  ON public.assessment_reports (user_id)
  WHERE user_id IS NOT NULL;

-- risk_level 索引：风险等级筛选（AssessmentReportQueryDTO.riskLevel）
-- 以及统计高风险报告数（highRiskCount）
CREATE INDEX idx_assessment_reports_risk_level
  ON public.assessment_reports (risk_level);

-- viewed 索引：筛选已查看/未查看报告（AssessmentReportQueryDTO.viewed）
-- 以及统计已解锁完整报告数（viewedCount）
CREATE INDEX idx_assessment_reports_viewed
  ON public.assessment_reports (viewed);

-- booked 索引：筛选已预约/未预约报告（AssessmentReportQueryDTO.booked）
-- 以及统计已预约顾问数（bookedCount）
CREATE INDEX idx_assessment_reports_booked
  ON public.assessment_reports (booked);

-- lead_status 索引：线索状态筛选（AssessmentReportQueryDTO.leadStatus）
CREATE INDEX idx_assessment_reports_lead_status
  ON public.assessment_reports (lead_status);

-- completed_at 降序索引：默认排序（sortBy=completedAt desc）
-- 以及时间范围筛选（completedFrom / completedTo）
CREATE INDEX idx_assessment_reports_completed_at
  ON public.assessment_reports (completed_at DESC);

-- score 降序索引：按风险分排序（sortBy=score desc）
CREATE INDEX idx_assessment_reports_score
  ON public.assessment_reports (score DESC);

-- advisor_id 部分索引：查询某顾问分配到的所有报告
-- 部分索引排除未分配报告（advisor_id IS NULL）
CREATE INDEX idx_assessment_reports_advisor_id
  ON public.assessment_reports (advisor_id)
  WHERE advisor_id IS NOT NULL;

-- ---------- report_raw_answers 索引 ----------

-- (report_id, question_id) 唯一索引已由 UNIQUE constraint 隐式创建，
-- 同时覆盖 "查某报告的所有答题记录" 查询，无需单独为 report_id 建索引

-- question_id 索引：统计某道题的答题分布（管理员题库分析 / 未来 A/B 测试）
CREATE INDEX idx_report_raw_answers_question_id
  ON public.report_raw_answers (question_id);

-- ============================================================================
-- Row Level Security（RLS）
-- ============================================================================

-- ---------- assessment_questions RLS ----------

ALTER TABLE public.assessment_questions ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何人（包括匿名用户）可查询已启用的题目
-- 用途：GET /api/assessment/questions（落地页公开接口，无需认证）
-- 注意：API 层负责在返回前过滤掉 options[].score 字段（S5）
CREATE POLICY assessment_questions_select_active
  ON public.assessment_questions
  FOR SELECT
  USING (is_active = true);

-- 策略 2：manager 可查询所有题目（含停用题目）
-- 用途：GET /api/admin/assessment/questions（管理员题库管理，含 score 权重）
CREATE POLICY assessment_questions_select_by_manager
  ON public.assessment_questions
  FOR SELECT
  USING (public.get_my_admin_role() = 'manager');

-- 策略 3：manager 可创建题目
-- 用途：题库初始化 / 新增题目
CREATE POLICY assessment_questions_insert_by_manager
  ON public.assessment_questions
  FOR INSERT
  WITH CHECK (public.get_my_admin_role() = 'manager');

-- 策略 4：manager 可更新题目
-- 用途：PATCH /api/admin/assessment/questions/:id（排序、启用状态、内容修改）
CREATE POLICY assessment_questions_update_by_manager
  ON public.assessment_questions
  FOR UPDATE
  USING (public.get_my_admin_role() = 'manager')
  WITH CHECK (public.get_my_admin_role() = 'manager');

-- 注意：题目不提供 DELETE 接口（RLS 层不开放，软下线通过 is_active=false 实现）
-- Service Role 保留删除能力（迁移场景），但不通过业务 API 暴露

-- ---------- assessment_reports RLS ----------

ALTER TABLE public.assessment_reports ENABLE ROW LEVEL SECURITY;

-- 策略 1：端用户可查询自己的报告
-- 用途：GET /api/assessment/report/:id（落地页查看自己的报告）
CREATE POLICY assessment_reports_select_self
  ON public.assessment_reports
  FOR SELECT
  USING (auth.uid() = user_id);

-- 策略 2：端用户可创建报告（提交测评）
-- 用途：POST /api/assessment/submit（已登录 / 匿名均可，user_id 可为 null）
-- 注意：score / risk_level 由服务端计算写入，API 层实现严禁接受前端传入（S5）
CREATE POLICY assessment_reports_insert_self
  ON public.assessment_reports
  FOR INSERT
  WITH CHECK (
    -- 已登录用户：user_id 必须等于 auth.uid()（防止伪造他人 userId）
    -- 匿名用户：user_id 为 null，auth.uid() 也为 null，条件成立
    (user_id IS NULL AND auth.uid() IS NULL)
    OR (user_id = auth.uid())
  );

-- 策略 3：端用户可更新自己的报告状态字段
-- 用途：POST /api/assessment/report/:id/unlock（viewed=true）
--       POST /api/assessment/report/:id/save（is_saved=true）
--       POST /api/assessment/report/:id/claim（user_id 绑定，匿名→实名迁移）
-- 列级限制在 API 层（Server Action）通过白名单字段实现，RLS 只做行级控制
CREATE POLICY assessment_reports_update_self
  ON public.assessment_reports
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 策略 4：任意管理员可查询所有报告
-- 用途：GET /api/admin/reports（管理后台报告列表 / 详情）
CREATE POLICY assessment_reports_select_by_admin
  ON public.assessment_reports
  FOR SELECT
  USING (public.is_admin());

-- 策略 5：market_ops / manager 可更新报告（分配顾问、更新 lead_status）
-- 用途：PATCH /api/admin/reports/:id/assign-advisor
--       从报告生成线索时同步更新 lead_status
-- tax_advisor 无写权限（仅读，权限矩阵 §7）
CREATE POLICY assessment_reports_update_by_ops_or_manager
  ON public.assessment_reports
  FOR UPDATE
  USING (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  )
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- ---------- report_raw_answers RLS ----------

ALTER TABLE public.report_raw_answers ENABLE ROW LEVEL SECURITY;

-- 策略 1：端用户可查询自己报告的答题记录
-- 用途：落地页查看自己的答题详情（如有）
-- 条件：report_id 对应的报告 user_id = auth.uid()
CREATE POLICY report_raw_answers_select_self
  ON public.report_raw_answers
  FOR SELECT
  USING (
    report_id IN (
      SELECT id FROM public.assessment_reports
      WHERE user_id = auth.uid()
    )
  );

-- 策略 2：端用户可创建答题记录（提交测评时写入）
-- 用途：POST /api/assessment/submit（服务端在事务中写入答题记录）
-- 条件：answer 对应的报告 user_id 与 auth.uid() 一致，或为匿名报告
CREATE POLICY report_raw_answers_insert_self
  ON public.report_raw_answers
  FOR INSERT
  WITH CHECK (
    report_id IN (
      SELECT id FROM public.assessment_reports
      WHERE user_id = auth.uid()
         OR (user_id IS NULL AND auth.uid() IS NULL)
    )
  );

-- 策略 3：任意管理员可查询所有答题记录
-- 用途：GET /api/admin/reports/:id/answers（管理后台答案明细抽屉）
CREATE POLICY report_raw_answers_select_by_admin
  ON public.report_raw_answers
  FOR SELECT
  USING (public.is_admin());

-- 注意：任何角色（包括 Service Role 以外的 manager）不能通过 RLS 更新或删除答题记录。
-- 答题记录一经创建不可修改（数据完整性保障）。
-- Service Role 保留操作能力（数据修正迁移场景），不通过业务 API 暴露。

-- ============================================================================
-- 本地开发 / 测试 SEED 数据
-- ============================================================================
-- 警告：以下 seed 仅用于本地开发和 CI 测试环境。
-- 生产环境部署前必须：
--   1. 清空或替换以下 seed 数据
--   2. 使用真实业务题库替换示例题目
--   3. 确认 seed UUID 不与生产数据冲突

-- ---------- seed: assessment_questions（3 道示例题目，company_basic 模块）----------
-- 选项 score 为示例权重值（0 / 3 / 5），不代表真实业务权重，部署前由产品确认替换

INSERT INTO public.assessment_questions (id, module_key, type, title, description, sort_order, is_active, options)
VALUES
  (
    'q0000000-0000-0000-0000-000000000001'::uuid,
    'company_basic',
    'single',
    '您的企业成立年限是？',
    '请选择企业实际运营年限（非注册年限）',
    1,
    true,
    '[
      {"sort_order": 0, "label": "1 年以内", "score": 5},
      {"sort_order": 1, "label": "1–3 年", "score": 3},
      {"sort_order": 2, "label": "3 年以上", "score": 0}
    ]'::jsonb
  ),
  (
    'q0000000-0000-0000-0000-000000000002'::uuid,
    'company_basic',
    'single',
    '您的企业年营业收入规模是？',
    '请选择最近一个完整财年的营业收入区间',
    2,
    true,
    '[
      {"sort_order": 0, "label": "500 万以下", "score": 0},
      {"sort_order": 1, "label": "500 万–2000 万", "score": 3},
      {"sort_order": 2, "label": "2000 万以上", "score": 5}
    ]'::jsonb
  ),
  (
    'q0000000-0000-0000-0000-000000000003'::uuid,
    'company_basic',
    'multiple',
    '您的企业目前有哪些关联方或关联交易？',
    '可多选，选择与贵企业存在业务往来或股权关联的情形',
    3,
    true,
    '[
      {"sort_order": 0, "label": "无关联方", "score": 0},
      {"sort_order": 1, "label": "有关联企业（同实控人）", "score": 3},
      {"sort_order": 2, "label": "有关联个人（家属或股东）", "score": 3},
      {"sort_order": 3, "label": "有跨境关联交易", "score": 5}
    ]'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

-- ---------- seed: assessment_reports（1 条示例报告）----------
-- 引用 users seed b0000000-0000-0000-0000-000000000001（示例科技有限公司，测试用户甲）
-- score=72（>65 阈值映射 high），risk_level='high'
-- modules 结构示例，desc/advice 为示意文本

INSERT INTO public.assessment_reports (
  id, user_id, company, score, risk_level,
  modules, suggestions,
  viewed, booked, is_saved,
  advisor_id, lead_status,
  source_qr_id, source_activity_id,
  completed_at
)
VALUES
  (
    'r0000000-0000-0000-0000-000000000001'::uuid,
    'b0000000-0000-0000-0000-000000000001'::uuid,  -- 测试用户甲
    '示例科技有限公司',
    72,
    'high',
    '[
      {
        "module_key": "report_invoice",
        "module_name": "发票合规风险",
        "score": 68,
        "risk_level": "high",
        "desc": "企业存在大量现金收款未开票情形，发票合规风险较高。",
        "advice": "建议梳理开票流程，规范发票管理，减少无票收入比例。"
      },
      {
        "module_key": "report_fund",
        "module_name": "公转私风险",
        "score": 80,
        "risk_level": "high",
        "desc": "频繁发生大额公转私转账，缺乏合规凭证支撑。",
        "advice": "建议通过合法薪酬或股东分红渠道取现，留存完整凭证。"
      },
      {
        "module_key": "report_cost",
        "module_name": "成本费用风险",
        "score": 60,
        "risk_level": "medium",
        "desc": "部分费用凭证不完整，存在所得税税前扣除风险。",
        "advice": "建议完善费用报销制度，确保凭证合规、真实、完整。"
      },
      {
        "module_key": "report_payroll",
        "module_name": "个税社保风险",
        "score": 55,
        "risk_level": "medium",
        "desc": "员工社保缴纳基数与实际工资存在差异。",
        "advice": "建议对照当地社保最低缴费基数，及时补缴差额。"
      },
      {
        "module_key": "report_audit",
        "module_name": "税务稽查应对风险",
        "score": 70,
        "risk_level": "high",
        "desc": "企业近两年税负率明显低于同行业水平，存在被稽查风险。",
        "advice": "建议提前梳理关键指标，准备好备查资料，必要时进行税务自查。"
      }
    ]'::jsonb,
    '["建议优先整改公转私问题，留存资金往来合规凭证。", "尽快补齐发票缺口，规范开票流程。", "建议与税务顾问预约深度诊断，制定整改路线图。"]'::jsonb,
    false,  -- 未解锁
    false,  -- 未预约
    false,  -- 未保存
    NULL,   -- 未分配顾问
    'new',  -- 线索状态
    NULL,   -- 无来源二维码
    NULL,   -- 无来源活动
    now() - interval '2 days'
  )
ON CONFLICT (id) DO NOTHING;

-- ---------- seed: report_raw_answers（3 条，对应上面 3 道题的答题记录）----------

INSERT INTO public.report_raw_answers (id, report_id, question_id, selected_indexes)
VALUES
  (
    'a0000000-0000-0000-0001-000000000001'::uuid,
    'r0000000-0000-0000-0000-000000000001'::uuid,
    'q0000000-0000-0000-0000-000000000001'::uuid,
    ARRAY[1]  -- 选"1–3 年"（sort_order=1，score=3）
  ),
  (
    'a0000000-0000-0000-0001-000000000002'::uuid,
    'r0000000-0000-0000-0000-000000000001'::uuid,
    'q0000000-0000-0000-0000-000000000002'::uuid,
    ARRAY[2]  -- 选"2000 万以上"（sort_order=2，score=5）
  ),
  (
    'a0000000-0000-0000-0001-000000000003'::uuid,
    'r0000000-0000-0000-0000-000000000001'::uuid,
    'q0000000-0000-0000-0000-000000000003'::uuid,
    ARRAY[1, 2]  -- 多选：关联企业 + 关联个人（sort_order=1,2，各 score=3）
  )
ON CONFLICT (report_id, question_id) DO NOTHING;

-- ============================================================================
-- ROLLBACK SECTION
-- ============================================================================
-- 回滚顺序（与创建顺序相反）：
--
-- -- 1. 删除答题记录表（依赖 assessment_reports 和 assessment_questions）
-- DROP TABLE IF EXISTS public.report_raw_answers CASCADE;
--
-- -- 2. 删除报告表
-- DROP TABLE IF EXISTS public.assessment_reports CASCADE;
--
-- -- 3. 删除题库表
-- DROP TABLE IF EXISTS public.assessment_questions CASCADE;
--
-- -- 4. 删除枚举类型（必须在依赖的表删除后执行）
-- DROP TYPE IF EXISTS public.risk_level_enum;
-- DROP TYPE IF EXISTS public.report_module_enum;
-- DROP TYPE IF EXISTS public.assessment_module_enum;
-- DROP TYPE IF EXISTS public.question_type_enum;
--
-- 注意：
--   CASCADE 删除表时会同时删除依赖的索引、trigger 和 RLS 策略。
--   若 risk_level_enum 已被其他表引用，需先移除其他表的依赖列再删除枚举。
--   回滚操作不可逆，执行前必须确认备份。
