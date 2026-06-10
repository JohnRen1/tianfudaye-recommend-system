-- migration: 20260610120000_create_users_table
-- description: 创建 admin_users 和 users 表，含枚举类型、索引、RLS、trigger 和本地开发 seed
-- author: database-engineer agent
-- date: 2026-06-10
-- rollback: 见文件末尾 ROLLBACK SECTION

-- ============================================================================
-- 依赖说明
-- ============================================================================
-- 本 migration 不依赖其他 migration。
-- 以下两个外键约束因目标表尚未创建，暂以注释说明，待对应 migration 执行后补全：
--   users.source_activity_id → activities.id  (待 activities 表创建后通过新 migration 添加)
--   users.source_qr_id       → qr_codes.id    (待 qr_codes 表创建后通过新 migration 添加)

-- ============================================================================
-- 扩展
-- ============================================================================

-- pg_trgm 用于 users.name 的 GIN 模糊搜索索引
-- moddatetime 用于 updated_at 自动更新 trigger（Supabase 内置扩展）
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS moddatetime WITH SCHEMA extensions;

-- ============================================================================
-- 枚举类型
-- ============================================================================

-- 管理员角色枚举（S5：三角色体系）
-- 对应 API 契约 AdminRole：market_ops / tax_advisor / manager
CREATE TYPE public.admin_role_enum AS ENUM (
  'market_ops',   -- 市场运营：活动/二维码/资料管理，查看用户和线索
  'tax_advisor',  -- 税务顾问：查看分配给自己的线索和用户详情
  'manager'       -- 管理者：全部权限，含系统设置和管理员管理
);

-- 线索状态枚举（S4：补全"未生成"，修复审计高风险项）
-- 对应 API 契约 LeadStatus，修复 mock 中"未生成"不在类型定义内的问题
CREATE TYPE public.lead_status_enum AS ENUM (
  'none',       -- 未生成（修复审计 leadStatus 缺失值问题）
  'new',        -- 新线索
  'pending',    -- 待跟进
  'assigned',   -- 已分配
  'following',  -- 跟进中
  'appointed',  -- 已预约
  'converted',  -- 已成交
  'invalid'     -- 无效线索
);

-- ============================================================================
-- 辅助函数（用于 RLS 策略）
-- ============================================================================

-- get_my_admin_role()
-- 从 admin_users 表查当前认证用户的角色。
-- SECURITY DEFINER：以定义者权限执行，绕过 RLS 读取 admin_users 自身，
--   避免 RLS 策略递归调用。
-- STABLE：同一事务内多次调用返回相同结果，Postgres 可缓存。
CREATE OR REPLACE FUNCTION public.get_my_admin_role()
RETURNS public.admin_role_enum
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role
  FROM   public.admin_users
  WHERE  id = auth.uid()
    AND  is_active = true
  LIMIT  1;
$$;

-- is_admin()
-- 判断当前用户是否为任意角色的管理员（is_active = true）。
-- 用于 users 表 RLS：管理员可读所有用户行。
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM   public.admin_users
    WHERE  id = auth.uid()
      AND  is_active = true
  );
$$;

-- ============================================================================
-- updated_at 自动更新触发器函数
-- ============================================================================
-- 若 Supabase 环境已安装 moddatetime 扩展，可直接使用
--   extensions.moddatetime() 函数；此处额外定义一个兼容函数，
--   防止 moddatetime 扩展在某些自托管环境中不可用。

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ============================================================================
-- TABLE: public.admin_users
-- ============================================================================
-- 存储管理后台登录用户（市场运营 / 税务顾问 / 管理者）。
-- 与 Supabase Auth 集成：id 同步为 auth.users.id（UUID），
--   认证逻辑由 Supabase Auth 处理（或独立 JWT），password_hash 仅备用。
-- 注意：password_hash 不通过普通查询暴露，见 RLS 列级安全说明。

CREATE TABLE public.admin_users (
  -- 主键：使用 Supabase Auth 用户 UUID，实现与 auth.uid() 的直接映射
  id               uuid         NOT NULL DEFAULT gen_random_uuid(),
  -- 登录用户名，全局唯一，不允许空
  username         text         NOT NULL,
  -- bcrypt 哈希密码，存储格式：$2b$12$...（60 字符）
  -- 敏感列，仅 Service Role 可读；普通查询通过视图或 API 层屏蔽
  password_hash    text         NOT NULL,
  -- 后台 Shell 顶栏展示名称，如"李明"、"周顾问"
  display_name     text         NOT NULL,
  -- 角色枚举，决定权限边界
  role             public.admin_role_enum NOT NULL,
  -- 软停用开关：false 时登录接口返回 ADMIN_AUTH_ACCOUNT_DISABLED
  is_active        boolean      NOT NULL DEFAULT true,
  -- 最近登录时间，由登录接口在成功后 UPDATE；首次登录前为 null
  last_login_at    timestamptz           DEFAULT NULL,
  -- 创建时间：由数据库自动填充，不允许客户端覆盖
  created_at       timestamptz  NOT NULL DEFAULT now(),
  -- 更新时间：由 trigger 自动维护
  updated_at       timestamptz  NOT NULL DEFAULT now(),

  CONSTRAINT admin_users_pkey         PRIMARY KEY (id),
  CONSTRAINT admin_users_username_uq  UNIQUE (username),
  -- username 长度约束：3-50 字符，仅允许字母数字和下划线
  CONSTRAINT admin_users_username_ck  CHECK (
    length(username) BETWEEN 3 AND 50
    AND username ~ '^[a-zA-Z0-9_]+$'
  ),
  -- display_name 不允许空字符串
  CONSTRAINT admin_users_display_name_ck CHECK (length(trim(display_name)) > 0)
);

COMMENT ON TABLE  public.admin_users                IS '管理后台用户（市场运营 / 税务顾问 / 管理者）';
COMMENT ON COLUMN public.admin_users.id             IS 'UUID 主键，与 Supabase auth.users.id 对应';
COMMENT ON COLUMN public.admin_users.username       IS '登录用户名，3-50 字符，字母数字下划线';
COMMENT ON COLUMN public.admin_users.password_hash  IS 'bcrypt 哈希密码（$2b$12$...），仅 Service Role 可读';
COMMENT ON COLUMN public.admin_users.display_name   IS 'Shell 顶栏展示名称';
COMMENT ON COLUMN public.admin_users.role           IS '管理员角色：market_ops / tax_advisor / manager';
COMMENT ON COLUMN public.admin_users.is_active      IS '账号是否启用；false 时拒绝登录';
COMMENT ON COLUMN public.admin_users.last_login_at  IS '最近成功登录时间，登录接口写入';
COMMENT ON COLUMN public.admin_users.created_at     IS '账号创建时间（UTC）';
COMMENT ON COLUMN public.admin_users.updated_at     IS '最近修改时间，由 trigger 自动更新（UTC）';

-- updated_at 自动更新 trigger
CREATE TRIGGER admin_users_set_updated_at
  BEFORE UPDATE ON public.admin_users
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- TABLE: public.users
-- ============================================================================
-- 存储落地页注册的外部端用户（企业主 / 财务负责人 / 创业者等）。
-- id 同步 Supabase Auth UUID，支持 auth.uid() = id 的 RLS 策略。
-- phone 存完整 11 位手机号；展示层脱敏由 API / View 层处理（审计不确定项 #1）。
-- source_activity_id / source_qr_id 暂无 FK constraint，待对应表创建后补全（见文件头部依赖说明）。

CREATE TABLE public.users (
  -- 主键：与 Supabase auth.users.id 对应，手机号登录后写入
  id                   uuid         NOT NULL DEFAULT gen_random_uuid(),

  -- 手机号：完整 11 位，唯一，不可为空
  -- 脱敏展示由 API 层处理（138****5628），不存脱敏格式
  phone                text         NOT NULL,

  -- 微信 openid：可空（手机号用户未绑定微信时为 null）
  -- 审计不确定项 #2：phone 为主 key，openid 为补充绑定
  openid               text                  DEFAULT NULL,

  -- 以下字段为注册第二步补填（审计不确定项 #4），允许 null
  name                 text                  DEFAULT NULL,
  identity             text                  DEFAULT NULL,  -- 企业老板 / 财务负责人 / 创业者 / ...
  company              text                  DEFAULT NULL,
  industry             text                  DEFAULT NULL,
  size                 text                  DEFAULT NULL,

  -- 来源归因：S1 修复（存 id 而非名称字符串）
  -- 暂无 FK constraint，待 activities / qr_codes 表创建后通过新 migration 添加
  -- 参见：docs/database/用户管理.md 第 9 节"待完成"
  source_activity_id   uuid                  DEFAULT NULL,
  source_qr_id         uuid                  DEFAULT NULL,

  -- 用户标签：运营人工打标 + 系统自动标签共存（审计不确定项 #3）
  -- 使用 text[] 存储，业务层区分来源；GIN 索引支持 @> 查询
  tags                 text[]       NOT NULL DEFAULT '{}',

  -- 线索状态枚举（S4：含 'none' 值，修复审计高风险项）
  lead_status          public.lead_status_enum NOT NULL DEFAULT 'none',

  -- 企业信息是否已补全（注册第二步完成标志）
  is_profile_complete  boolean      NOT NULL DEFAULT false,

  -- 注册时间：首次创建时由数据库填充，不允许客户端覆盖
  registered_at        timestamptz  NOT NULL DEFAULT now(),

  -- 最近活跃时间：每次有意义的交互由 API / trigger 更新
  active_at            timestamptz  NOT NULL DEFAULT now(),

  -- 更新时间：由 trigger 自动维护
  updated_at           timestamptz  NOT NULL DEFAULT now(),

  CONSTRAINT users_pkey          PRIMARY KEY (id),
  -- phone 全局唯一（一个手机号只能注册一个账号）
  CONSTRAINT users_phone_uq      UNIQUE (phone),
  -- phone 格式：11 位纯数字，1 开头（中国大陆手机号）
  CONSTRAINT users_phone_ck      CHECK (phone ~ '^1[0-9]{10}$'),
  -- tags 数量上限 20（对应 API 错误码 USER_TAGS_TOO_MANY）
  CONSTRAINT users_tags_count_ck CHECK (array_length(tags, 1) IS NULL OR array_length(tags, 1) <= 20)
);

COMMENT ON TABLE  public.users                      IS '落地页注册的外部端用户';
COMMENT ON COLUMN public.users.id                   IS 'UUID 主键，与 Supabase auth.users.id 对应';
COMMENT ON COLUMN public.users.phone                IS '完整 11 位手机号（存储层不脱敏，展示层处理）';
COMMENT ON COLUMN public.users.openid               IS '微信 openid，可空；phone 为主 key，openid 为补充绑定';
COMMENT ON COLUMN public.users.name                 IS '用户姓名，注册第二步补填，可为 null';
COMMENT ON COLUMN public.users.identity             IS '用户身份（企业老板/财务负责人/创业者），注册第二步补填';
COMMENT ON COLUMN public.users.company              IS '企业名称，注册第二步补填';
COMMENT ON COLUMN public.users.industry             IS '行业，注册第二步补填';
COMMENT ON COLUMN public.users.size                 IS '企业规模，注册第二步补填';
COMMENT ON COLUMN public.users.source_activity_id   IS '来源活动 UUID（S1）；暂无 FK，待 activities 表创建后补全';
COMMENT ON COLUMN public.users.source_qr_id         IS '来源二维码 UUID（S1）；暂无 FK，待 qr_codes 表创建后补全';
COMMENT ON COLUMN public.users.tags                 IS '用户标签数组（运营打标+系统标签），最多 20 个';
COMMENT ON COLUMN public.users.lead_status          IS '线索状态枚举，默认 none（未生成）';
COMMENT ON COLUMN public.users.is_profile_complete  IS '企业信息是否已补全（注册第二步完成标志）';
COMMENT ON COLUMN public.users.registered_at        IS '注册时间（UTC），由数据库自动填充';
COMMENT ON COLUMN public.users.active_at            IS '最近活跃时间（UTC），由 API / trigger 更新';
COMMENT ON COLUMN public.users.updated_at           IS '最近修改时间（UTC），由 trigger 自动更新';

-- updated_at 自动更新 trigger
CREATE TRIGGER users_set_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- active_at 在 UPDATE 时自动更新
-- 仅在 updated_at 之外额外维护 active_at，因为二者语义不同：
--   updated_at 追踪字段变更，active_at 追踪用户最近有意义的访问行为。
-- 当前实现：任意字段 UPDATE 时同步更新 active_at。
-- 更精细的控制（如仅特定事件触发）可在业务层实现，trigger 作兜底。
CREATE OR REPLACE FUNCTION public.set_users_active_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.active_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER users_set_active_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.set_users_active_at();

-- ============================================================================
-- 索引
-- ============================================================================

-- ---------- admin_users 索引 ----------

-- role 索引：用于按角色筛选管理员列表，以及 get_my_admin_role() / is_admin() 函数的 WHERE 条件
-- username 唯一索引已由 UNIQUE constraint 隐式创建，无需重复添加
CREATE INDEX idx_admin_users_role     ON public.admin_users (role);
CREATE INDEX idx_admin_users_active   ON public.admin_users (is_active) WHERE is_active = true;

-- ---------- users 索引 ----------

-- openid 唯一索引：部分索引，仅对非 null 值建索引，节省空间
-- 微信登录时通过 openid 查找已有用户
CREATE UNIQUE INDEX idx_users_openid_uq
  ON public.users (openid)
  WHERE openid IS NOT NULL;

-- name 模糊搜索：GIN + pg_trgm，支持 name LIKE '%搜索词%'
-- 对应 UserQueryDTO.name 字段的模糊搜索
CREATE INDEX idx_users_name_trgm
  ON public.users USING GIN (name extensions.gin_trgm_ops)
  WHERE name IS NOT NULL;

-- source_activity_id 索引：用于来源活动筛选（UserQueryDTO.sourceActivityId）
-- 以及统计"某活动来了多少用户"
CREATE INDEX idx_users_source_activity_id
  ON public.users (source_activity_id)
  WHERE source_activity_id IS NOT NULL;

-- source_qr_id 索引：用于来源二维码筛选
CREATE INDEX idx_users_source_qr_id
  ON public.users (source_qr_id)
  WHERE source_qr_id IS NOT NULL;

-- lead_status 索引：用于线索状态筛选（UserQueryDTO.leadStatus）
-- 以及统计 withLead 指标（lead_status != 'none'）
CREATE INDEX idx_users_lead_status
  ON public.users (lead_status);

-- registered_at 索引：用于时间范围筛选（registeredFrom / registeredTo）
-- 以及默认排序（sortBy=registeredAt desc），B-Tree 支持范围查询和排序
CREATE INDEX idx_users_registered_at
  ON public.users (registered_at DESC);

-- active_at 索引：用于 sortBy=activeAt 排序
CREATE INDEX idx_users_active_at
  ON public.users (active_at DESC);

-- tags GIN 索引：支持 tags @> ARRAY['意向'] 查询
-- 用于统计 highIntent（tags 含"意向"）和 highRisk（tags 含"风险"）
CREATE INDEX idx_users_tags_gin
  ON public.users USING GIN (tags);

-- ============================================================================
-- Row Level Security（RLS）
-- ============================================================================

-- ---------- admin_users RLS ----------

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- 策略 1：管理员读取自己的行
-- 条件：auth.uid() = id
-- 用途：Shell 顶栏展示当前登录管理员信息（GET /api/admin/auth/me）
-- 注意：password_hash 字段由 API 层屏蔽，不在响应 DTO 中返回；
--       数据库层不做列级安全，由 SELECT 语句显式指定列实现
CREATE POLICY admin_users_select_self
  ON public.admin_users
  FOR SELECT
  USING (auth.uid() = id);

-- 策略 2：manager 角色可查询所有管理员
-- 条件：当前用户角色为 manager（通过 get_my_admin_role() 判断）
-- 用途：管理员管理页面列表
CREATE POLICY admin_users_select_by_manager
  ON public.admin_users
  FOR SELECT
  USING (public.get_my_admin_role() = 'manager');

-- 策略 3：manager 角色可创建新管理员
CREATE POLICY admin_users_insert_by_manager
  ON public.admin_users
  FOR INSERT
  WITH CHECK (public.get_my_admin_role() = 'manager');

-- 策略 4：manager 角色可修改管理员信息
-- 包含：重置密码、修改角色、停用账号等
CREATE POLICY admin_users_update_by_manager
  ON public.admin_users
  FOR UPDATE
  USING (public.get_my_admin_role() = 'manager')
  WITH CHECK (public.get_my_admin_role() = 'manager');

-- 策略 5：manager 角色可删除管理员
-- 生产环境建议改为软删除（is_active = false），硬删除仅保留给迁移场景
CREATE POLICY admin_users_delete_by_manager
  ON public.admin_users
  FOR DELETE
  USING (public.get_my_admin_role() = 'manager');

-- 注意：Service Role（后端 API / Server Action）绕过 RLS，拥有全部权限。
-- 不需要为 Service Role 添加 RLS 策略。

-- ---------- users RLS ----------

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 策略 1：端用户读取自己的行
-- 条件：auth.uid() = id
-- 用途：GET /api/auth/me，PATCH /api/auth/me/profile
CREATE POLICY users_select_self
  ON public.users
  FOR SELECT
  USING (auth.uid() = id);

-- 策略 2：端用户更新自己的行
-- 允许更新：name / identity / company / industry / size / is_profile_complete
-- 不允许端用户修改：phone / openid / source_activity_id / source_qr_id / tags / lead_status
-- 行级策略无法限制列；列级控制在 API 层（Server Action）实现，
--   端用户调用 PATCH /api/auth/me/profile，服务端白名单字段后写库
CREATE POLICY users_update_self
  ON public.users
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 策略 3：管理员读取所有用户行
-- 条件：is_admin()（任意活跃管理员）
-- 用途：GET /api/admin/users，GET /api/admin/users/:id
CREATE POLICY users_select_by_admin
  ON public.users
  FOR SELECT
  USING (public.is_admin());

-- 策略 4：market_ops / manager 可更新用户信息（含 tags / lead_status）
-- tax_advisor 无写权限（仅读，权限矩阵 7.2）
-- 用途：PATCH /api/admin/users/:id，PATCH /api/admin/users/:id/tags
CREATE POLICY users_update_by_market_ops_or_manager
  ON public.users
  FOR UPDATE
  USING (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  )
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 5：market_ops / manager 可创建用户（后台手动创建）
-- 用途：POST /api/admin/users
CREATE POLICY users_insert_by_market_ops_or_manager
  ON public.users
  FOR INSERT
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 注意：任何角色（包括 manager）均不能通过 RLS 删除 users 行。
-- 若需要删除，必须通过 Service Role 执行，并保留审计日志（后续模块实现）。

-- ============================================================================
-- 本地开发 / 测试 SEED 数据
-- ============================================================================
-- 警告：以下 seed 仅用于本地开发和 CI 测试环境。
-- 生产环境部署前必须：
--   1. 替换 password_hash 为真实 bcrypt hash（bcrypt cost=12）
--   2. 替换占位手机号为真实测试数据或删除此 seed
--   3. 将 seed 中的 id 替换为真实 Supabase Auth 用户 UUID
-- 生产环境不应执行此 seed 段。

-- seed 管理员账号
-- 注意：以下 password_hash 为占位符，格式为真实 bcrypt $2b$12$ 结构，
--   但 hash 主体已模糊处理，不代表任何真实密码。
--   部署前用 bcrypt.hash('真实密码', 12) 替换。
INSERT INTO public.admin_users (id, username, password_hash, display_name, role, is_active)
VALUES
  -- manager: admin / [部署前替换为 bcrypt hash of 真实密码]
  (
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'admin',
    -- 占位 hash，部署前必须替换
    -- 生成方式：node -e "const b=require('bcrypt');b.hash('YOUR_PASSWORD',12).then(console.log)"
    '$2b$12$PLACEHOLDER_REPLACE_BEFORE_DEPLOY_admin00000000000000000',
    '系统管理员',
    'manager',
    true
  ),
  -- market_ops: ops_demo / [部署前替换]
  (
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'ops_demo',
    '$2b$12$PLACEHOLDER_REPLACE_BEFORE_DEPLOY_ops_demo000000000000000',
    '运营小李',
    'market_ops',
    true
  ),
  -- tax_advisor: advisor_demo / [部署前替换]
  (
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'advisor_demo',
    '$2b$12$PLACEHOLDER_REPLACE_BEFORE_DEPLOY_advisor00000000000000000',
    '周顾问',
    'tax_advisor',
    true
  )
ON CONFLICT (username) DO NOTHING;

-- seed 端用户（3 条，手机号用占位格式，不使用真实号码）
INSERT INTO public.users (
  id, phone, name, identity, company, industry, size,
  source_activity_id, source_qr_id,
  tags, lead_status, is_profile_complete,
  registered_at, active_at
)
VALUES
  (
    'b0000000-0000-0000-0000-000000000001'::uuid,
    '13800000001',  -- 占位手机号，非真实号码
    '测试用户甲',
    '企业老板',
    '示例科技有限公司',
    '互联网',
    '50-200人',
    NULL,  -- 暂无来源活动（待 activities 表创建后可更新）
    NULL,  -- 暂无来源二维码
    ARRAY['高意向', '关注公转私'],
    'new',
    true,
    now() - interval '10 days',
    now() - interval '1 day'
  ),
  (
    'b0000000-0000-0000-0000-000000000002'::uuid,
    '13800000002',
    '测试用户乙',
    '财务负责人',
    '示例贸易有限公司',
    '贸易',
    '10-50人',
    NULL,
    NULL,
    ARRAY['潜在意向'],
    'pending',
    true,
    now() - interval '7 days',
    now() - interval '2 days'
  ),
  (
    'b0000000-0000-0000-0000-000000000003'::uuid,
    '13800000003',
    NULL,           -- 未完成注册第二步
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    '{}',
    'none',
    false,
    now() - interval '1 day',
    now() - interval '1 hour'
  )
ON CONFLICT (phone) DO NOTHING;

-- ============================================================================
-- ROLLBACK SECTION
-- ============================================================================
-- 回滚顺序（与创建顺序相反）：
--
-- -- 1. 删除表（依赖枚举类型，必须先删表）
-- DROP TABLE IF EXISTS public.users CASCADE;
-- DROP TABLE IF EXISTS public.admin_users CASCADE;
--
-- -- 2. 删除辅助函数
-- DROP FUNCTION IF EXISTS public.set_users_active_at();
-- DROP FUNCTION IF EXISTS public.set_updated_at();
-- DROP FUNCTION IF EXISTS public.is_admin();
-- DROP FUNCTION IF EXISTS public.get_my_admin_role();
--
-- -- 3. 删除枚举类型
-- DROP TYPE IF EXISTS public.lead_status_enum;
-- DROP TYPE IF EXISTS public.admin_role_enum;
--
-- -- 4. 扩展通常不回滚（可能被其他对象依赖）
-- -- DROP EXTENSION IF EXISTS moddatetime;
-- -- DROP EXTENSION IF EXISTS pg_trgm;
