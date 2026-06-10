-- migration: 20260610120001_create_activities_qrcodes_table
-- description: 创建 activities、qr_codes、qr_scan_events 表，补全 users 外键
-- depends_on: 20260610120000_create_users_table
-- rollback: 见文件末尾 ROLLBACK SECTION

-- ============================================================================
-- 枚举类型
-- ============================================================================

-- 活动状态枚举
-- S4：修复 mock 中 status 直接存中文字符串问题（'已上架' / '草稿' / '已下架'）
CREATE TYPE public.activity_status_enum AS ENUM (
  'published',  -- 已上架：对外开放，落地页可见
  'draft',      -- 草稿：未发布，仅管理员可见
  'closed'      -- 已下架：停止运营，落地页展示"已结束"
);

-- 活动形式枚举
-- 审计不确定项 #4：暂不拆分 isOnline + location，单独维护活动形式
CREATE TYPE public.activity_type_enum AS ENUM (
  'offline',  -- 线下活动
  'online',   -- 线上直播
  'hybrid'    -- 线上+线下
);

-- 二维码类型枚举
-- S4：修复 mock 中存中文字符串（'活动二维码' 等），统一使用英文值
CREATE TYPE public.qr_type_enum AS ENUM (
  'activity',   -- 活动二维码：绑定活动，扫码进入活动落地页
  'advisor',    -- 顾问二维码："新建邀请码"快捷入口使用此值
  'channel',    -- 渠道二维码：渠道合作方分发
  'material',   -- 资料二维码：扫码直达资料领取
  'assessment'  -- 测评二维码：扫码直达风险测评
);

-- 二维码状态枚举
-- S4：修复 mock 中存中文字符串（'启用中' / '暂停中'）
CREATE TYPE public.qr_status_enum AS ENUM (
  'active',  -- 启用中：可正常扫码，scans 计数正常触发
  'paused'   -- 暂停中：扫码接口返回 QR_DISABLED，落地页展示失效提示
);

-- ============================================================================
-- TABLE: public.activities
-- ============================================================================
-- 存储活动记录（线下沙龙、线上直播、混合活动等）。
-- 统计计数器（scan / register / material_claims / ai_questions /
--   assessments / appointments / high_intent_leads / material_count）
-- 采用预存计数器方案（审计不确定项 #6 决策）：
--   事件发生时原子递增，避免频繁聚合查询；定期对账任务校验一致性。
-- creator_id 外键指向 admin_users.id，记录活动创建人（S1：存外键而非名称字符串）。

CREATE TABLE public.activities (
  -- 主键：UUID，由数据库生成
  id               uuid         NOT NULL DEFAULT gen_random_uuid(),

  -- 活动名称，1-200 字符
  name             text         NOT NULL,

  -- 活动主题标签，如"汇算清缴"、"税务稽查"
  theme            text         NOT NULL,

  -- 活动开始时间（带时区），存储标准时间（UTC），展示层转换为本地时区
  -- S4：替代 mock 中 `time: "2026-06-18 14:00"` 非标准字符串格式
  start_at         timestamptz  NOT NULL,

  -- 活动结束时间，null 表示未设置结束时间（纯展示性活动）
  end_at           timestamptz  DEFAULT NULL,

  -- 活动地点（admin 侧字段名），落地页映射为 location
  -- S4：字段名对齐 API 契约 ActivityCreateDTO.place
  place            text         NOT NULL,

  -- 主讲老师姓名（admin 侧字段名），落地页映射为 speaker
  -- S4：字段名对齐 API 契约 ActivityCreateDTO.teacher
  teacher          text         NOT NULL,

  -- 主讲老师职称，落地页展示用（S4：补全 admin-system mock 缺失字段）
  speaker_title    text         NOT NULL DEFAULT '',

  -- 活动状态枚举
  status           public.activity_status_enum NOT NULL DEFAULT 'draft',

  -- 活动简介全文（S4：补全 admin-system mock 缺失字段）
  description      text         NOT NULL DEFAULT '',

  -- 活动封面图 URL（S4：补全 admin-system mock 缺失字段），null 表示未上传
  cover_image      text         DEFAULT NULL,

  -- 活动形式枚举，可选
  type             public.activity_type_enum DEFAULT NULL,

  -- ---- 统计计数器（预存，原子递增，避免聚合慢查询）----
  -- 扫码人数：扫码事件上报时递增（qr_scan_events 写入时 +1）
  scan             integer      NOT NULL DEFAULT 0,
  -- 注册人数：注册接口携带 source_activity_id 时递增
  register         integer      NOT NULL DEFAULT 0,
  -- 资料领取人数：资料领取接口携带 activity_id 时递增
  material_claims  integer      NOT NULL DEFAULT 0,
  -- AI 问答人数（S6：替代 mock 中 register * 0.61 写死系数）
  ai_questions     integer      NOT NULL DEFAULT 0,
  -- 完成测评人数
  assessments      integer      NOT NULL DEFAULT 0,
  -- 预约顾问人数
  appointments     integer      NOT NULL DEFAULT 0,
  -- 高意向线索数：线索状态变更为高意向时递增
  high_intent_leads integer     NOT NULL DEFAULT 0,
  -- 关联资料数（冗余计数，关联/取消资料时同步维护）
  -- 审计不确定项 #6 决策：冗余计数，避免频繁 count 查询
  material_count   integer      NOT NULL DEFAULT 0,

  -- 创建人（S1：外键关联 admin_users，不存姓名字符串）
  -- ON DELETE RESTRICT：删除管理员前需先处理其创建的活动
  creator_id       uuid         NOT NULL,

  -- 时间戳
  created_at       timestamptz  NOT NULL DEFAULT now(),
  updated_at       timestamptz  NOT NULL DEFAULT now(),

  -- ---- 约束 ----
  CONSTRAINT activities_pkey
    PRIMARY KEY (id),

  -- 外键：创建人必须是已存在的管理员
  CONSTRAINT activities_creator_id_fk
    FOREIGN KEY (creator_id)
    REFERENCES public.admin_users(id)
    ON DELETE RESTRICT,

  -- end_at 晚于 start_at（仅在 end_at 不为 null 时校验）
  CONSTRAINT activities_end_after_start_ck
    CHECK (end_at IS NULL OR end_at > start_at),

  -- 活动名称长度 1-200
  CONSTRAINT activities_name_length_ck
    CHECK (length(trim(name)) BETWEEN 1 AND 200),

  -- 所有计数器不能为负
  CONSTRAINT activities_scan_non_negative_ck          CHECK (scan >= 0),
  CONSTRAINT activities_register_non_negative_ck      CHECK (register >= 0),
  CONSTRAINT activities_material_claims_non_neg_ck    CHECK (material_claims >= 0),
  CONSTRAINT activities_ai_questions_non_neg_ck       CHECK (ai_questions >= 0),
  CONSTRAINT activities_assessments_non_neg_ck        CHECK (assessments >= 0),
  CONSTRAINT activities_appointments_non_neg_ck       CHECK (appointments >= 0),
  CONSTRAINT activities_high_intent_leads_non_neg_ck  CHECK (high_intent_leads >= 0),
  CONSTRAINT activities_material_count_non_neg_ck     CHECK (material_count >= 0)
);

COMMENT ON TABLE  public.activities                    IS '活动记录（线下沙龙/线上直播/混合活动）';
COMMENT ON COLUMN public.activities.id                 IS 'UUID 主键';
COMMENT ON COLUMN public.activities.name               IS '活动名称，1-200 字符';
COMMENT ON COLUMN public.activities.theme              IS '活动主题标签（如"汇算清缴"）';
COMMENT ON COLUMN public.activities.start_at           IS '活动开始时间（UTC，带时区）';
COMMENT ON COLUMN public.activities.end_at             IS '活动结束时间（UTC，带时区），null 表示未设置';
COMMENT ON COLUMN public.activities.place              IS '活动地点（admin 侧字段名），落地页映射为 location';
COMMENT ON COLUMN public.activities.teacher            IS '主讲老师姓名（admin 侧字段名），落地页映射为 speaker';
COMMENT ON COLUMN public.activities.speaker_title      IS '主讲老师职称（补全 mock 缺失字段），落地页展示';
COMMENT ON COLUMN public.activities.status             IS '活动状态枚举：published / draft / closed';
COMMENT ON COLUMN public.activities.description        IS '活动简介全文（补全 mock 缺失字段）';
COMMENT ON COLUMN public.activities.cover_image        IS '活动封面图 URL（补全 mock 缺失字段），null 用默认背景';
COMMENT ON COLUMN public.activities.type               IS '活动形式：offline / online / hybrid，可空';
COMMENT ON COLUMN public.activities.scan               IS '累计扫码人数，预存计数器，原子递增';
COMMENT ON COLUMN public.activities.register           IS '累计注册人数，预存计数器';
COMMENT ON COLUMN public.activities.material_claims    IS '累计资料领取人数，预存计数器';
COMMENT ON COLUMN public.activities.ai_questions       IS '累计 AI 问答人数，替代 mock 中 register*0.61 系数';
COMMENT ON COLUMN public.activities.assessments        IS '累计完成测评人数，预存计数器';
COMMENT ON COLUMN public.activities.appointments       IS '累计预约顾问人数，预存计数器';
COMMENT ON COLUMN public.activities.high_intent_leads  IS '累计高意向线索数，预存计数器';
COMMENT ON COLUMN public.activities.material_count     IS '关联资料数，冗余计数，关联/取消资料时同步';
COMMENT ON COLUMN public.activities.creator_id         IS '创建人 admin_users.id（外键）';
COMMENT ON COLUMN public.activities.created_at         IS '创建时间（UTC）';
COMMENT ON COLUMN public.activities.updated_at         IS '最近修改时间（UTC），trigger 自动更新';

-- updated_at 自动更新 trigger
CREATE TRIGGER activities_set_updated_at
  BEFORE UPDATE ON public.activities
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- TABLE: public.qr_codes
-- ============================================================================
-- 存储二维码 / 邀请码记录，统一管理扫码归因链。
--
-- 标识体系（S2 核心修复）：
--   id（UUID）— 系统内部主键，URL qr_id 参数来源，归因链唯一外键
--   invite_code（可读短码）— 对外展示，URL invite 参数来源，人工可识别
-- 两者均存储：id 做系统查询键，invite_code 做人类可读标识。
--
-- 统计计数器（scans / registers / leads）采用预存方案（审计不确定项 #2 决策）：
--   事件发生时原子递增，定期对账任务校验一致性。

CREATE TABLE public.qr_codes (
  -- 主键：UUID，归因链唯一外键（S2：替代 mock 中 'QR-ACT-001' 等格式不规范主键）
  id              uuid         NOT NULL DEFAULT gen_random_uuid(),

  -- 二维码名称，1-100 字符
  name            text         NOT NULL,

  -- 二维码类型枚举
  type            public.qr_type_enum NOT NULL,

  -- 可读短码，系统生成，全局唯一（S2：如 ACT20260702）
  -- 字母数字，3-50 字符，UNIQUE 约束隐式建索引
  invite_code     text         NOT NULL,

  -- 绑定活动外键（S1：不存活动名称字符串）
  -- ON DELETE SET NULL：活动删除后二维码仍保留，解除关联
  activity_id     uuid         DEFAULT NULL,

  -- 绑定顾问外键（S1：不存顾问名称字符串，null 表示未绑定）
  -- ON DELETE SET NULL：顾问账号删除后二维码仍保留
  advisor_id      uuid         DEFAULT NULL,

  -- 渠道标识（当前阶段后端维护字典）
  channel         text         NOT NULL DEFAULT '',

  -- 有效期结构化字段（S2：替代 mock 中 validPeriod 非结构化字符串）
  -- null = 无起始限制
  valid_from      timestamptz  DEFAULT NULL,
  -- null = 长期有效（对应 mock validPeriod = '长期有效'）
  valid_to        timestamptz  DEFAULT NULL,

  -- 二维码状态枚举
  status          public.qr_status_enum NOT NULL DEFAULT 'active',

  -- ---- 统计计数器（预存，原子递增）----
  -- 累计扫码次数（POST /api/track/qr-scan 时 +1）
  scans           integer      NOT NULL DEFAULT 0,
  -- 扫码后注册的用户数（注册接口携带 source_qr_id 时 +1）
  registers       integer      NOT NULL DEFAULT 0,
  -- 由此二维码归因产生的线索数（线索生成时 +1）
  leads           integer      NOT NULL DEFAULT 0,

  -- 二维码图片 URL（服务端生成后存储，前端直接渲染）
  qr_image_url    text         DEFAULT NULL,

  -- 时间戳
  created_at      timestamptz  NOT NULL DEFAULT now(),
  updated_at      timestamptz  NOT NULL DEFAULT now(),

  -- ---- 约束 ----
  CONSTRAINT qr_codes_pkey
    PRIMARY KEY (id),

  -- invite_code 全局唯一（支持通过 URL invite 参数的历史兼容查询）
  CONSTRAINT qr_codes_invite_code_uq
    UNIQUE (invite_code),

  -- 外键：绑定活动（活动删除后 SET NULL，二维码仍保留历史记录）
  CONSTRAINT qr_codes_activity_id_fk
    FOREIGN KEY (activity_id)
    REFERENCES public.activities(id)
    ON DELETE SET NULL,

  -- 外键：绑定顾问（顾问删除后 SET NULL）
  CONSTRAINT qr_codes_advisor_id_fk
    FOREIGN KEY (advisor_id)
    REFERENCES public.admin_users(id)
    ON DELETE SET NULL,

  -- valid_to 晚于 valid_from（仅在两者都不为 null 时校验）
  CONSTRAINT qr_codes_valid_period_ck
    CHECK (
      valid_from IS NULL
      OR valid_to IS NULL
      OR valid_to > valid_from
    ),

  -- invite_code 格式：字母数字，3-50 字符
  CONSTRAINT qr_codes_invite_code_format_ck
    CHECK (
      length(invite_code) BETWEEN 3 AND 50
      AND invite_code ~ '^[a-zA-Z0-9_-]+$'
    ),

  -- name 长度 1-100
  CONSTRAINT qr_codes_name_length_ck
    CHECK (length(trim(name)) BETWEEN 1 AND 100),

  -- 所有计数器不能为负
  CONSTRAINT qr_codes_scans_non_negative_ck     CHECK (scans >= 0),
  CONSTRAINT qr_codes_registers_non_negative_ck CHECK (registers >= 0),
  CONSTRAINT qr_codes_leads_non_negative_ck     CHECK (leads >= 0)
);

COMMENT ON TABLE  public.qr_codes                 IS '二维码/邀请码记录，统一扫码归因链';
COMMENT ON COLUMN public.qr_codes.id              IS 'UUID 主键，S2 归因链唯一外键，URL qr_id 参数来源';
COMMENT ON COLUMN public.qr_codes.name            IS '二维码名称，1-100 字符';
COMMENT ON COLUMN public.qr_codes.type            IS '二维码类型枚举：activity/advisor/channel/material/assessment';
COMMENT ON COLUMN public.qr_codes.invite_code     IS '可读短码，系统生成全局唯一（如 ACT20260702），URL invite 参数来源';
COMMENT ON COLUMN public.qr_codes.activity_id     IS '绑定活动外键（S1），null 表示未绑定';
COMMENT ON COLUMN public.qr_codes.advisor_id      IS '绑定顾问外键（S1），null 表示未绑定';
COMMENT ON COLUMN public.qr_codes.channel         IS '渠道标识，后端维护字典';
COMMENT ON COLUMN public.qr_codes.valid_from      IS '有效期起始（UTC），null 表示无起始限制';
COMMENT ON COLUMN public.qr_codes.valid_to        IS '有效期截止（UTC），null 表示长期有效';
COMMENT ON COLUMN public.qr_codes.status          IS '二维码状态：active（启用中）/ paused（暂停中）';
COMMENT ON COLUMN public.qr_codes.scans           IS '累计扫码次数，预存计数器，原子递增';
COMMENT ON COLUMN public.qr_codes.registers       IS '扫码后注册用户数，预存计数器';
COMMENT ON COLUMN public.qr_codes.leads           IS '归因产生线索数，预存计数器';
COMMENT ON COLUMN public.qr_codes.qr_image_url    IS '二维码图片 URL，服务端生成后存储';
COMMENT ON COLUMN public.qr_codes.created_at      IS '创建时间（UTC）';
COMMENT ON COLUMN public.qr_codes.updated_at      IS '最近修改时间（UTC），trigger 自动更新';

-- updated_at 自动更新 trigger
CREATE TRIGGER qr_codes_set_updated_at
  BEFORE UPDATE ON public.qr_codes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- TABLE: public.qr_scan_events
-- ============================================================================
-- 扫码事件日志，用于 S2 归因链追踪。
-- 核心流程：扫码 → 上报（写入此表 + scans+1）→ 注册后回填 user_id。
--
-- 此表为只追加（append-only）模式：
--   事件一旦记录不修改（无 updated_at），仅在注册后通过 UPDATE 回填 user_id。
-- session_id 用于在用户未登录时追踪同一扫码会话的行为链路。

CREATE TABLE public.qr_scan_events (
  -- 主键：UUID
  id          uuid         NOT NULL DEFAULT gen_random_uuid(),

  -- 来源二维码（ON DELETE CASCADE：二维码删除则清除扫码历史）
  qr_code_id  uuid         NOT NULL,

  -- 匿名会话 id（未登录时由落地页生成并存入 sessionStorage，追踪同一扫码用户）
  session_id  text         DEFAULT NULL,

  -- 注册用户 id，注册前为 null，注册后通过注册接口回填
  -- ON DELETE SET NULL：用户删除后保留日志，仅清除关联
  user_id     uuid         DEFAULT NULL,

  -- 用户代理信息（设备类型统计用）
  user_agent  text         DEFAULT NULL,

  -- 扫码时间（UTC）
  scanned_at  timestamptz  NOT NULL DEFAULT now(),

  -- ---- 约束 ----
  CONSTRAINT qr_scan_events_pkey
    PRIMARY KEY (id),

  -- 外键：必须关联存在的二维码
  CONSTRAINT qr_scan_events_qr_code_id_fk
    FOREIGN KEY (qr_code_id)
    REFERENCES public.qr_codes(id)
    ON DELETE CASCADE,

  -- 外键：关联用户（注册后回填，可为 null）
  CONSTRAINT qr_scan_events_user_id_fk
    FOREIGN KEY (user_id)
    REFERENCES public.users(id)
    ON DELETE SET NULL
);

COMMENT ON TABLE  public.qr_scan_events             IS '扫码事件日志，S2 归因链追踪，append-only';
COMMENT ON COLUMN public.qr_scan_events.id          IS 'UUID 主键';
COMMENT ON COLUMN public.qr_scan_events.qr_code_id  IS '来源二维码外键（CASCADE 删除）';
COMMENT ON COLUMN public.qr_scan_events.session_id  IS '匿名会话 id（未登录时追踪同一扫码用户）';
COMMENT ON COLUMN public.qr_scan_events.user_id     IS '注册用户 id，注册前 null，注册后回填';
COMMENT ON COLUMN public.qr_scan_events.user_agent  IS '用户代理，设备类型统计用';
COMMENT ON COLUMN public.qr_scan_events.scanned_at  IS '扫码时间（UTC）';

-- 注意：qr_scan_events 无 updated_at 字段，事件不可变，不需要 trigger。

-- ============================================================================
-- 索引
-- ============================================================================

-- ---------- activities 索引 ----------

-- status 索引：按状态筛选（活动列表页 status 筛选）
CREATE INDEX idx_activities_status
  ON public.activities (status);

-- status = 'published' 部分索引：落地页查询活跃活动，过滤绝大多数非 published 行
CREATE INDEX idx_activities_status_published
  ON public.activities (id)
  WHERE status = 'published';

-- creator_id 索引：按创建人筛选（ActivityQueryDTO.creatorId）
CREATE INDEX idx_activities_creator_id
  ON public.activities (creator_id);

-- start_at DESC 索引：默认排序（sortBy=startAt）及日期范围筛选
CREATE INDEX idx_activities_start_at_desc
  ON public.activities (start_at DESC);

-- created_at DESC 索引：默认排序（sortBy=createdAt desc）
CREATE INDEX idx_activities_created_at_desc
  ON public.activities (created_at DESC);

-- name GIN trgm 索引：全文模糊搜索（ActivityQueryDTO.q 字段的 name LIKE 匹配）
-- 依赖 migration 0 已启用的 pg_trgm 扩展
CREATE INDEX idx_activities_name_trgm
  ON public.activities USING GIN (name extensions.gin_trgm_ops);

-- teacher GIN trgm 索引：全文模糊搜索（ActivityQueryDTO.q 字段的 teacher LIKE 匹配）
CREATE INDEX idx_activities_teacher_trgm
  ON public.activities USING GIN (teacher extensions.gin_trgm_ops);

-- ---------- qr_codes 索引 ----------
-- 注意：invite_code 的唯一索引已由 UNIQUE constraint 隐式创建，无需重复添加。

-- activity_id 部分索引：按绑定活动筛选（QrCodeQueryDTO.activityId）
-- 部分索引仅对有绑定活动的行建索引，节省空间
CREATE INDEX idx_qr_codes_activity_id
  ON public.qr_codes (activity_id)
  WHERE activity_id IS NOT NULL;

-- advisor_id 部分索引：按绑定顾问筛选（QrCodeQueryDTO.advisorId）
CREATE INDEX idx_qr_codes_advisor_id
  ON public.qr_codes (advisor_id)
  WHERE advisor_id IS NOT NULL;

-- status 索引：按状态筛选（QrCodeQueryDTO.status）
CREATE INDEX idx_qr_codes_status
  ON public.qr_codes (status);

-- type 索引：按类型筛选（QrCodeQueryDTO.type）
CREATE INDEX idx_qr_codes_type
  ON public.qr_codes (type);

-- created_at DESC 索引：默认排序（sortBy=createdAt desc）
CREATE INDEX idx_qr_codes_created_at_desc
  ON public.qr_codes (created_at DESC);

-- name GIN trgm 索引：关键字搜索（QrCodeQueryDTO.keyword 的 name LIKE 匹配）
CREATE INDEX idx_qr_codes_name_trgm
  ON public.qr_codes USING GIN (name extensions.gin_trgm_ops);

-- ---------- qr_scan_events 索引 ----------

-- qr_code_id 索引：按二维码查扫码事件（核心查询）
CREATE INDEX idx_qr_scan_events_qr_code_id
  ON public.qr_scan_events (qr_code_id);

-- user_id 部分索引：按用户查扫码历史（注册后回填，归因分析）
CREATE INDEX idx_qr_scan_events_user_id
  ON public.qr_scan_events (user_id)
  WHERE user_id IS NOT NULL;

-- scanned_at DESC 索引：时间排序，扫码明细列表分页
CREATE INDEX idx_qr_scan_events_scanned_at_desc
  ON public.qr_scan_events (scanned_at DESC);

-- session_id 部分索引：按会话 id 追踪匿名用户行为链
CREATE INDEX idx_qr_scan_events_session_id
  ON public.qr_scan_events (session_id)
  WHERE session_id IS NOT NULL;

-- ============================================================================
-- Row Level Security（RLS）
-- ============================================================================

-- ---------- activities RLS ----------

ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何已认证管理员可读所有活动行
-- 条件：is_admin()（任意活跃管理员角色）
-- 用途：GET /api/admin/activities，GET /api/admin/activities/:id
CREATE POLICY activities_select_by_admin
  ON public.activities
  FOR SELECT
  USING (public.is_admin());

-- 策略 2：market_ops / manager 可创建活动
-- tax_advisor 无写权限（权限矩阵 7.1）
CREATE POLICY activities_insert_by_market_ops_or_manager
  ON public.activities
  FOR INSERT
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 3：market_ops / manager 可更新活动（含上架/下架/编辑）
CREATE POLICY activities_update_by_market_ops_or_manager
  ON public.activities
  FOR UPDATE
  USING (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  )
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 4：仅 manager 可删除活动（须先下架，API 层校验）
CREATE POLICY activities_delete_by_manager
  ON public.activities
  FOR DELETE
  USING (public.get_my_admin_role() = 'manager');

-- 策略 5：落地页端用户（含匿名）可读取 published 活动
-- 实际落地页 API 使用 Service Role（绕过 RLS），此策略作为兜底安全层。
-- anon role（匿名用户）通过此策略读取已上架活动数据。
CREATE POLICY activities_select_published_by_anon
  ON public.activities
  FOR SELECT
  USING (status = 'published');

-- 注意：Service Role（后端 API / Server Action）绕过 RLS，拥有全部权限。

-- ---------- qr_codes RLS ----------

ALTER TABLE public.qr_codes ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何已认证管理员可读所有二维码行
CREATE POLICY qr_codes_select_by_admin
  ON public.qr_codes
  FOR SELECT
  USING (public.is_admin());

-- 策略 2：market_ops / manager 可创建二维码（含"新建邀请码"快捷入口）
-- tax_advisor 无写权限（权限矩阵 8.2）
CREATE POLICY qr_codes_insert_by_market_ops_or_manager
  ON public.qr_codes
  FOR INSERT
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 3：market_ops / manager 可更新二维码（含停用/启用/编辑）
CREATE POLICY qr_codes_update_by_market_ops_or_manager
  ON public.qr_codes
  FOR UPDATE
  USING (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  )
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 4：market_ops / manager 可删除二维码
-- 注意：删除二维码会级联删除 qr_scan_events，建议改为 status = 'paused' 软停用
CREATE POLICY qr_codes_delete_by_market_ops_or_manager
  ON public.qr_codes
  FOR DELETE
  USING (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 5：匿名用户（落地页扫码）可读取 active 状态二维码
-- 用于 POST /api/track/qr-scan 验证二维码有效性（API 层使用 Service Role，此为兜底）
CREATE POLICY qr_codes_select_active_by_anon
  ON public.qr_codes
  FOR SELECT
  USING (status = 'active');

-- ---------- qr_scan_events RLS ----------

ALTER TABLE public.qr_scan_events ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何已认证管理员可读扫码事件（归因分析、明细查询）
CREATE POLICY qr_scan_events_select_by_admin
  ON public.qr_scan_events
  FOR SELECT
  USING (public.is_admin());

-- 策略 2：所有人（含匿名）可写入扫码事件
-- 扫码事件上报（POST /api/track/qr-scan）为公开接口，无需认证。
-- 实际由 Service Role 执行写入，此策略覆盖 anon role 的直连场景（兜底）。
CREATE POLICY qr_scan_events_insert_by_all
  ON public.qr_scan_events
  FOR INSERT
  WITH CHECK (true);

-- 策略 3：注册接口（Service Role）回填 user_id，无需额外 RLS 策略。
-- Service Role 绕过 RLS，可直接 UPDATE qr_scan_events.user_id。
-- 说明：如需允许端用户通过 JWT 自行回填，可添加：
--   CREATE POLICY qr_scan_events_update_user_id_by_self ON public.qr_scan_events
--     FOR UPDATE USING (user_id IS NULL) WITH CHECK (auth.uid() = user_id);
-- 当前阶段由 Service Role 统一处理，暂不开放。

-- ============================================================================
-- 补全 users 表悬空外键
-- ============================================================================
-- 在 migration 0 中，users.source_activity_id 和 users.source_qr_id
-- 暂无 FK constraint（目标表尚未创建），现在补全。
-- 两列均允许 null，ON DELETE SET NULL 保证活动/二维码删除后不级联删除用户。

ALTER TABLE public.users
  ADD CONSTRAINT users_source_activity_id_fk
    FOREIGN KEY (source_activity_id)
    REFERENCES public.activities(id)
    ON DELETE SET NULL;

ALTER TABLE public.users
  ADD CONSTRAINT users_source_qr_id_fk
    FOREIGN KEY (source_qr_id)
    REFERENCES public.qr_codes(id)
    ON DELETE SET NULL;

-- ============================================================================
-- 本地开发 / 测试 SEED 数据
-- ============================================================================
-- 警告：以下 seed 仅用于本地开发和 CI 测试环境，生产环境不应执行此段。
-- 生产环境部署前必须：
--   1. 替换占位 UUID 为真实 Supabase Auth 用户 UUID
--   2. 删除或替换 seed 数据

-- seed 活动数据（2 条：1 published + 1 draft）
-- creator_id 引用 migration 0 seed 中的管理员 UUID
INSERT INTO public.activities (
  id, name, theme, start_at, end_at,
  place, teacher, speaker_title, status,
  description, cover_image, type,
  scan, register, material_claims, ai_questions,
  assessments, appointments, high_intent_leads, material_count,
  creator_id
)
VALUES
  (
    'c0000000-0000-0000-0000-000000000001'::uuid,
    '金税四期风险识别专题课',
    '税务稽查',
    '2026-07-02T19:30:00+08:00',
    '2026-07-02T21:00:00+08:00',
    '线上直播',
    '刘老师',
    '注册税务师',
    'published',
    '本次专题课将深入讲解金税四期系统对企业的影响，帮助企业提前识别和规避涉税风险。',
    NULL,
    'online',
    120, 65, 48, 40, 22, 15, 8, 3,
    'a0000000-0000-0000-0000-000000000001'::uuid
  ),
  (
    'c0000000-0000-0000-0000-000000000002'::uuid,
    '2026 汇算清缴实操培训',
    '汇算清缴',
    '2026-08-15T14:00:00+08:00',
    '2026-08-15T17:00:00+08:00',
    '上海·静安区会议中心',
    '王老师',
    '高级税务师 / 合伙人',
    'draft',
    '',
    NULL,
    'offline',
    0, 0, 0, 0, 0, 0, 0, 0,
    'a0000000-0000-0000-0000-000000000002'::uuid
  )
ON CONFLICT (id) DO NOTHING;

-- seed 二维码数据（2 条：对应上面两个活动）
INSERT INTO public.qr_codes (
  id, name, type, invite_code,
  activity_id, advisor_id, channel,
  valid_from, valid_to, status,
  scans, registers, leads
)
VALUES
  (
    'd0000000-0000-0000-0000-000000000001'::uuid,
    '金税四期专题课-活动码',
    'activity',
    'ACT20260702',
    'c0000000-0000-0000-0000-000000000001'::uuid,
    NULL,
    '微信公众号',
    '2026-06-01T00:00:00+08:00',
    '2026-07-02T23:59:59+08:00',
    'active',
    120, 65, 8
  ),
  (
    'd0000000-0000-0000-0000-000000000002'::uuid,
    '周顾问专属邀请码',
    'advisor',
    'CONSULT-ZHOU',
    NULL,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    '顾问私域',
    NULL,
    NULL,
    'active',
    0, 0, 0
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ROLLBACK SECTION
-- ============================================================================
-- 回滚顺序（与创建顺序相反）：
--
-- -- 1. 先移除 users 表补全的外键约束（避免删表时被外键阻止）
-- ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_source_activity_id_fk;
-- ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_source_qr_id_fk;
--
-- -- 2. 删表（依赖顺序：qr_scan_events 先删，然后 qr_codes，最后 activities）
-- DROP TABLE IF EXISTS public.qr_scan_events CASCADE;
-- DROP TABLE IF EXISTS public.qr_codes CASCADE;
-- DROP TABLE IF EXISTS public.activities CASCADE;
--
-- -- 3. 删除枚举类型（必须在依赖表删除后执行）
-- DROP TYPE IF EXISTS public.qr_status_enum;
-- DROP TYPE IF EXISTS public.qr_type_enum;
-- DROP TYPE IF EXISTS public.activity_type_enum;
-- DROP TYPE IF EXISTS public.activity_status_enum;
--
-- 注意：
--   - 删表操作使用 CASCADE，会同时删除所有依赖对象（索引、触发器、RLS 策略）。
--   - 回滚后 users.source_activity_id 和 users.source_qr_id 列仍保留（无外键约束），
--     与 migration 0 的原始状态一致，无需额外处理。
--   - 回滚不影响 migration 0 创建的内容（admin_users / users / 枚举 / 函数）。
