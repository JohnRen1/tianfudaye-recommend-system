-- migration: 20260610120002_create_materials_table
-- description: 创建 materials（资料目录）和 material_claims（领取记录）表
-- depends_on: 20260610120000_create_users_table
-- note: activity_id FK 待 20260610120001_create_activities_qrcodes_table 执行后由新 migration 补全
-- rollback: 见文件末尾 ROLLBACK SECTION

-- ============================================================================
-- 依赖说明
-- ============================================================================
-- 本 migration 依赖：
--   20260610120000_create_users_table — 提供 public.users、public.set_updated_at()、
--     public.is_admin()、public.get_my_admin_role()、pg_trgm 扩展
--
-- 以下外键约束因目标表尚未创建，暂以注释说明，待对应 migration 执行后补全：
--   materials.activity_id     → activities.id  (待 20260610120001 执行后通过新 migration 添加)
--   material_claims.activity_id → activities.id (同上)

-- ============================================================================
-- 枚举类型
-- ============================================================================

-- 资料类型枚举
-- 对应 API 契约 MaterialType：courseware / policy / checklist / case
-- 审计 S4：统一英文枚举，废弃 admin mock 的中文值（沙龙课件/政策资料/工具表/案例资料）
CREATE TYPE public.material_type_enum AS ENUM (
  'courseware',  -- 沙龙课件
  'policy',      -- 政策资料
  'checklist',   -- 工具表（落地页展示为"自查表"）
  'case'         -- 案例资料
);

-- 文件格式枚举
-- 对应 API 契约 FileFormat：pdf / xlsx / pptx / docx
-- 审计 S4：统一小写枚举，废弃 mock 的 "XLSX" / "Excel" 歧义
CREATE TYPE public.file_format_enum AS ENUM (
  'pdf',    -- PDF 文件
  'xlsx',   -- Excel 文件（展示层映射为 "Excel"）
  'pptx',   -- PowerPoint 文件（展示层映射为 "PPT"）
  'docx'    -- Word 文件（展示层映射为 "Word"）
);

-- 资料上架状态枚举
-- 对应 API 契约 MaterialStatus：published / draft / unpublished
-- 审计 S4：区别于 MaterialClaimStatus（领取状态），两者同名异义冲突已通过重命名解决
CREATE TYPE public.material_status_enum AS ENUM (
  'published',    -- 已上架：落地页可见、可领取
  'draft',        -- 草稿：仅管理员可见
  'unpublished'   -- 已下架：不可领取
);

-- ============================================================================
-- TABLE: public.materials
-- ============================================================================
-- 资料目录：运营上传和管理的资料条目。
-- 对应 admin-system 资料管理后台，以及落地页资料领取模块。
--
-- 设计决策：
--   1. activity_id 暂无 FK constraint（目标表 activities 由并行 migration 创建），
--      待执行 20260610120001 后通过新 migration 补全。
--   2. downloads 字段记录实际文件下载次数，由 material_claims.downloaded_at
--      从 null 变为非 null 时的 trigger 原子递增，不由客户端直接写入。
--   3. 领取次数（claims）不单独存字段，通过 COUNT(material_claims) 聚合查询获取，
--      避免双写不一致。MaterialSummaryDTO.totalClaims 由聚合接口计算。
--   4. storage_key 存 Supabase Storage 对象 key，不存完整 URL；
--      signed URL 在 API 层按需生成。

CREATE TABLE public.materials (
  -- 主键：UUID，由数据库自动生成
  id                  uuid                      NOT NULL DEFAULT gen_random_uuid(),

  -- 资料名称，不允许为空
  name                text                      NOT NULL,

  -- 资料类型枚举（courseware/policy/checklist/case）
  type                public.material_type_enum NOT NULL,

  -- 细分类型标签（如"课程课件"、"答疑整理"、"专题指南"），自由字符串
  -- 用于落地页资料卡片的细分 Badge 展示（materials-page.tsx material.type 字段）
  -- 设计：type 是大分类枚举，sub_type 是小分类标签，两者共存
  sub_type            text                               DEFAULT NULL,

  -- 文件格式枚举（pdf/xlsx/pptx/docx）
  format              public.file_format_enum   NOT NULL,

  -- Supabase Storage 对象 key，不允许为空
  -- 格式示例：materials/2026/06/filename.pdf
  -- signed URL 由 API 层按需生成，不存入数据库
  storage_key         text                      NOT NULL,

  -- 文件大小（字节数），可空（旧数据迁移场景）
  file_size_bytes     bigint                             DEFAULT NULL,

  -- 资料描述，可空
  -- 审计：admin mock 缺失此字段，materials-page.tsx 有展示需求
  description         text                               DEFAULT NULL,

  -- 关联活动 UUID（S1：修复 mock 中存活动名称字符串的高风险问题）
  -- 暂无 FK constraint，待 activities 表创建后通过新 migration 补全
  -- 索引：WHERE NOT NULL 部分索引（大多数资料不关联活动）
  activity_id         uuid                               DEFAULT NULL,

  -- 领取门槛：是否需要登录才能领取
  -- 层级关系：need_company_info=true 时 need_login 必须也为 true
  need_login          boolean                   NOT NULL DEFAULT false,

  -- 领取门槛：是否需要补充企业信息才能领取
  -- 审计 S4：统一命名 need_company_info（无 s），修复 mock 的 needsCompanyInfo/needCompanyInfo 冲突
  -- 层级关系：need_company_info=true 隐含 need_login=true
  need_company_info   boolean                   NOT NULL DEFAULT false,

  -- 上架状态枚举（published/draft/unpublished）
  -- 审计 S4：与领取状态（MaterialClaimStatus）彻底分离，不再同名异义
  status              public.material_status_enum NOT NULL DEFAULT 'draft',

  -- 实际文件下载次数（下载与领取是两个独立动作）
  -- 由 trigger 在 material_claims.downloaded_at 从 null 变为非 null 时原子递增
  -- 不允许客户端直接写入
  downloads           integer                   NOT NULL DEFAULT 0,

  -- 创建时间（UTC），由数据库自动填充
  created_at          timestamptz               NOT NULL DEFAULT now(),

  -- 更新时间（UTC），由 trigger 自动维护
  updated_at          timestamptz               NOT NULL DEFAULT now(),

  -- ── 约束 ──────────────────────────────────────────────────────────────────

  CONSTRAINT materials_pkey PRIMARY KEY (id),

  -- name 长度约束：1-200 字符
  CONSTRAINT materials_name_length_ck
    CHECK (length(trim(name)) BETWEEN 1 AND 200),

  -- downloads 不允许为负数
  CONSTRAINT materials_downloads_non_negative_ck
    CHECK (downloads >= 0),

  -- file_size_bytes 若不为 null，则必须大于 0
  CONSTRAINT materials_file_size_positive_ck
    CHECK (file_size_bytes IS NULL OR file_size_bytes > 0),

  -- 门槛层级约束：need_company_info=true 时 need_login 也必须为 true
  -- 即：不允许 need_company_info=true AND need_login=false 的组合
  -- 业务逻辑：企业信息门槛隐含登录门槛
  CONSTRAINT materials_auth_gate_hierarchy_ck
    CHECK (NOT (need_company_info = true AND need_login = false))
);

COMMENT ON TABLE  public.materials                    IS '资料目录：运营上传和管理的资料条目';
COMMENT ON COLUMN public.materials.id                 IS 'UUID 主键，由数据库自动生成';
COMMENT ON COLUMN public.materials.name               IS '资料名称，1-200 字符';
COMMENT ON COLUMN public.materials.type               IS '资料大分类枚举（courseware/policy/checklist/case）';
COMMENT ON COLUMN public.materials.sub_type           IS '细分类型标签（自由字符串，如"课程课件"），可为 null';
COMMENT ON COLUMN public.materials.format             IS '文件格式枚举（pdf/xlsx/pptx/docx）';
COMMENT ON COLUMN public.materials.storage_key        IS 'Supabase Storage 对象 key，不含完整 URL；signed URL 由 API 层生成';
COMMENT ON COLUMN public.materials.file_size_bytes    IS '文件大小（字节数），可空（旧数据迁移时允许缺失）';
COMMENT ON COLUMN public.materials.description        IS '资料描述，落地页卡片展示用，可为 null';
COMMENT ON COLUMN public.materials.activity_id        IS '关联活动 UUID（S1）；暂无 FK，待 activities 表创建后通过新 migration 补全';
COMMENT ON COLUMN public.materials.need_login         IS '是否需要登录才能领取；层级：need_company_info=true 时此字段必须也为 true';
COMMENT ON COLUMN public.materials.need_company_info  IS '是否需要补充企业信息才能领取（S4：统一命名，无 s）；隐含 need_login=true';
COMMENT ON COLUMN public.materials.status             IS '上架状态枚举（published/draft/unpublished）；S4：与领取状态分离';
COMMENT ON COLUMN public.materials.downloads          IS '实际文件下载次数；由 trigger 在 downloaded_at 从 null→非 null 时原子递增';
COMMENT ON COLUMN public.materials.created_at         IS '创建时间（UTC），由数据库自动填充';
COMMENT ON COLUMN public.materials.updated_at         IS '最近修改时间（UTC），由 trigger 自动更新';

-- updated_at 自动更新 trigger（复用 migration 1 中定义的 public.set_updated_at()）
CREATE TRIGGER materials_set_updated_at
  BEFORE UPDATE ON public.materials
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- TABLE: public.material_claims
-- ============================================================================
-- 领取记录：用户领取资料产生的 join 表记录。
--
-- 这是修复审计 S3 最关键的表：
--   "落地页领取资料只更新前端 state，不落库" → 此表解决持久化缺失问题。
--   "用户详情页资料领取记录用 materialItems.slice(0,3) 误充" → 此表提供真实领取数据。
--
-- 设计决策：
--   1. (user_id, material_id) UNIQUE — 每个用户每个资料只能领取一次（幂等保护）。
--      重复领取请求返回 CLAIM_ALREADY_CLAIMED (409)，不创建新记录。
--   2. 无 updated_at 字段：领取记录追加不修改，只有 downloaded_at 会在下载时 UPDATE。
--      通用 updated_at trigger 对此表无意义，不添加。
--   3. download_url / url_expires_at 字段缓存 signed URL，有效期短，可重新生成。
--      这两个字段是辅助缓存，不是关键业务数据。
--   4. activity_id 暂无 FK constraint，待 activities 表创建后通过新 migration 补全。

CREATE TABLE public.material_claims (
  -- 主键：UUID，由数据库自动生成
  id              uuid        NOT NULL DEFAULT gen_random_uuid(),

  -- 领取用户（端用户）外键
  -- ON DELETE CASCADE：用户删除时级联删除其所有领取记录
  user_id         uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

  -- 被领取的资料外键
  -- ON DELETE CASCADE：资料删除时级联删除相关领取记录
  material_id     uuid        NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,

  -- 来源活动 UUID（S2：归因链，记录用户从哪个活动进入后领取了此资料）
  -- 可空：独立访问资料领取页（无活动上下文）时为 null
  -- 暂无 FK constraint，待 activities 表创建后通过新 migration 补全
  activity_id     uuid                 DEFAULT NULL,

  -- 领取时间（UTC）：用户点击"领取"按钮的时刻
  -- 与 downloaded_at 的差异：领取是意向动作，下载是实际获取文件的动作
  claimed_at      timestamptz NOT NULL DEFAULT now(),

  -- 实际下载时间（UTC）：用户点击下载/打开文件的时刻
  -- null 表示已领取但尚未实际下载
  -- 此字段从 null 变为非 null 时，trigger 原子递增 materials.downloads
  downloaded_at   timestamptz          DEFAULT NULL,

  -- 缓存的 signed 下载 URL（有效期短，可按需重新生成）
  -- 审计 S3：MaterialClaimCreateResponseDTO.downloadUrl 对应此字段
  -- 此字段仅作服务端缓存，不是权威数据源；前端可凭 claim id 重新请求 signed URL
  download_url    text                 DEFAULT NULL,

  -- download_url 的过期时间（UTC）
  -- API 层据此判断是否需要重新生成 signed URL
  url_expires_at  timestamptz          DEFAULT NULL,

  -- ── 约束 ──────────────────────────────────────────────────────────────────

  CONSTRAINT material_claims_pkey PRIMARY KEY (id),

  -- 幂等约束：每个用户每个资料只能领取一次
  -- 重复 INSERT 时数据库返回 unique_violation (23505)，API 层映射为 CLAIM_ALREADY_CLAIMED (409)
  CONSTRAINT material_claims_user_material_uq UNIQUE (user_id, material_id),

  -- 时序约束：实际下载时间不能早于领取时间
  -- 仅在 downloaded_at 不为 null 时校验
  CONSTRAINT material_claims_download_after_claim_ck
    CHECK (downloaded_at IS NULL OR downloaded_at >= claimed_at)
);

COMMENT ON TABLE  public.material_claims                   IS '资料领取记录：用户领取资料产生的 join 表（S3：修复领取不落库问题）';
COMMENT ON COLUMN public.material_claims.id                IS 'UUID 主键，由数据库自动生成';
COMMENT ON COLUMN public.material_claims.user_id           IS '端用户外键 → public.users(id)，ON DELETE CASCADE';
COMMENT ON COLUMN public.material_claims.material_id       IS '资料外键 → public.materials(id)，ON DELETE CASCADE';
COMMENT ON COLUMN public.material_claims.activity_id       IS '来源活动 UUID（S2 归因链）；暂无 FK，待 activities 表创建后补全；可空（无活动上下文）';
COMMENT ON COLUMN public.material_claims.claimed_at        IS '领取时间（UTC）：用户点击"领取"按钮的时刻';
COMMENT ON COLUMN public.material_claims.downloaded_at     IS '实际下载时间（UTC）；null 表示已领取未下载；从 null→非 null 时 trigger 递增 materials.downloads';
COMMENT ON COLUMN public.material_claims.download_url      IS '缓存的 signed 下载 URL（有效期短），可按需重新生成；非权威数据源';
COMMENT ON COLUMN public.material_claims.url_expires_at    IS 'download_url 的过期时间（UTC）；API 层据此判断是否需要重新生成';

-- ============================================================================
-- 索引
-- ============================================================================

-- ---------- materials 索引 ----------

-- type 索引：按资料类型筛选（MaterialQueryDTO.type）
CREATE INDEX idx_materials_type
  ON public.materials (type);

-- status 部分索引（published）：落地页查可领取资料的高频路径
-- WHERE status='published' 条件固定，部分索引比全量索引更小、更快
CREATE INDEX idx_materials_status_published
  ON public.materials (status)
  WHERE status = 'published';

-- status 全量索引：admin 列表按状态筛选（含 draft/unpublished）
CREATE INDEX idx_materials_status
  ON public.materials (status);

-- activity_id 部分索引：按活动筛选关联资料（大多数资料无活动，部分索引节省空间）
CREATE INDEX idx_materials_activity_id
  ON public.materials (activity_id)
  WHERE activity_id IS NOT NULL;

-- name GIN 模糊搜索索引（pg_trgm，已在 migration 1 中启用）
-- 支持 name LIKE '%搜索词%'（MaterialQueryDTO.name 字段）
CREATE INDEX idx_materials_name_trgm
  ON public.materials USING GIN (name extensions.gin_trgm_ops);

-- format 索引：按文件格式筛选（MaterialQueryDTO.format）
CREATE INDEX idx_materials_format
  ON public.materials (format);

-- need_login + need_company_info 复合索引：筛选需要留资的资料
-- 对应 MaterialQueryDTO.needsAuth 参数，以及 MaterialSummaryDTO.withAuthGate 统计
CREATE INDEX idx_materials_auth_gate
  ON public.materials (need_login, need_company_info);

-- created_at 倒序索引：列表默认排序（sortBy=createdAt desc）
CREATE INDEX idx_materials_created_at_desc
  ON public.materials (created_at DESC);

-- downloads 倒序索引：按下载次数排序（sortBy=downloads desc）
CREATE INDEX idx_materials_downloads_desc
  ON public.materials (downloads DESC);

-- ---------- material_claims 索引 ----------

-- (user_id, material_id) UNIQUE constraint 已隐式创建 B-Tree 索引，
-- 同时支持：
--   1. 查"用户是否已领取某资料"（WHERE user_id=? AND material_id=?）
--   2. 幂等保护

-- user_id 索引：查某用户所有领取记录（用户详情页"资料领取记录"标签页）
-- 审计修复：原 mock 用 materialItems.slice(0,3) 误充，真实数据从此索引查询
CREATE INDEX idx_material_claims_user_id
  ON public.material_claims (user_id);

-- material_id 索引：查某资料所有领取记录（统计 claims 总数，MaterialStatisticsDTO.claims）
CREATE INDEX idx_material_claims_material_id
  ON public.material_claims (material_id);

-- activity_id 部分索引：按来源活动统计领取数（S2 归因链分析）
CREATE INDEX idx_material_claims_activity_id
  ON public.material_claims (activity_id)
  WHERE activity_id IS NOT NULL;

-- claimed_at 倒序索引：领取记录时间排序（MaterialClaimQueryDTO 默认排序）
CREATE INDEX idx_material_claims_claimed_at_desc
  ON public.material_claims (claimed_at DESC);

-- ============================================================================
-- Trigger 函数：downloads 计数递增
-- ============================================================================
-- 当 material_claims 记录的 downloaded_at 从 null 变为非 null 时，
-- 原子递增对应资料的 downloads 计数。
--
-- 触发场景：
--   API 层调用 UPDATE material_claims SET downloaded_at=now(), download_url=...,
--   url_expires_at=... WHERE id=? AND user_id=?
--
-- 设计决策：
--   使用 trigger 而非应用层双写，保证 downloads 计数与 downloaded_at 的原子一致性。
--   即使 API 调用失败重试，trigger 不会重复计数（因为 OLD.downloaded_at IS NULL 的
--   条件只有首次更新时成立）。

CREATE OR REPLACE FUNCTION public.increment_material_downloads()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- 仅当 downloaded_at 从 null 变为非 null 时触发递增
  -- 防止重复 UPDATE downloaded_at 导致 downloads 多次递增
  IF OLD.downloaded_at IS NULL AND NEW.downloaded_at IS NOT NULL THEN
    UPDATE public.materials
    SET downloads = downloads + 1
    WHERE id = NEW.material_id;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.increment_material_downloads() IS
  '当 material_claims.downloaded_at 从 null 变为非 null 时，原子递增 materials.downloads 计数';

CREATE TRIGGER material_claims_increment_downloads
  AFTER UPDATE OF downloaded_at ON public.material_claims
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_material_downloads();

-- ============================================================================
-- Row Level Security（RLS）
-- ============================================================================

-- ---------- materials RLS ----------

ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何管理员可查询所有资料（含草稿、已下架）
-- 条件：is_admin()（任意活跃管理员角色）
-- 用途：admin-system 资料管理后台列表、详情、统计
CREATE POLICY materials_select_by_admin
  ON public.materials
  FOR SELECT
  USING (public.is_admin());

-- 策略 2：market_ops / manager 可创建资料
-- 条件：角色为 market_ops 或 manager
-- tax_advisor 无写权限（权限矩阵：查看 yes，上传/更新 no）
CREATE POLICY materials_insert_by_market_ops_or_manager
  ON public.materials
  FOR INSERT
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 3：market_ops / manager 可更新资料元数据和状态
-- 包含：更新资料字段（PATCH /api/admin/materials/:id）
--       上架/下架（PATCH /api/admin/materials/:id/status）
--       批量上架/下架（PATCH /api/admin/materials/bulk-status）
CREATE POLICY materials_update_by_market_ops_or_manager
  ON public.materials
  FOR UPDATE
  USING (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  )
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 4：仅 manager 可删除资料
-- 权限矩阵：删除资料 market_ops=否，tax_advisor=否，manager=是
-- 注意：API 层须在删除前校验资料已下架（status='unpublished'），
--       数据库层不重复此业务规则
CREATE POLICY materials_delete_by_manager
  ON public.materials
  FOR DELETE
  USING (
    public.get_my_admin_role() = 'manager'
  );

-- 策略 5：已登录的端用户可查询已上架资料
-- 条件：auth.uid() IS NOT NULL（已登录）AND status='published'
-- 用途：落地页资料列表（需要登录的资料，need_login=true）
CREATE POLICY materials_select_by_authenticated_user
  ON public.materials
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND status = 'published'
  );

-- 策略 6：匿名用户可查询已上架且无需登录的资料
-- 条件：status='published' AND need_login=false
-- 用途：落地页未登录状态下可预览不需要登录的资料列表
-- 注意：匿名用户无法领取（领取接口需要 JWT），
--       此策略仅允许列表展示（预览卡片不含 fileUrl）
CREATE POLICY materials_select_by_anonymous
  ON public.materials
  FOR SELECT
  USING (
    status = 'published'
    AND need_login = false
  );

-- ---------- material_claims RLS ----------

ALTER TABLE public.material_claims ENABLE ROW LEVEL SECURITY;

-- 策略 1：端用户可查询自己的领取记录
-- 条件：auth.uid() = user_id
-- 用途：
--   GET /api/me/material-claims（落地页个人领取历史）
--   落地页计算当前用户对每条资料的 claimStatus（是否已领取）
CREATE POLICY material_claims_select_self
  ON public.material_claims
  FOR SELECT
  USING (auth.uid() = user_id);

-- 策略 2：端用户可创建自己的领取记录
-- 条件：auth.uid() = user_id（服务端从 JWT 读取 userId 后写入，客户端不能伪造）
-- 用途：POST /api/material-claims（落地页领取资料，S3 修复）
CREATE POLICY material_claims_insert_self
  ON public.material_claims
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 策略 3：端用户可更新自己的领取记录（仅 downloaded_at 字段）
-- 条件：auth.uid() = user_id
-- 用途：API 层在用户实际下载文件后更新 downloaded_at、download_url、url_expires_at
-- 注意：行级策略无法限制到列；API 层（Server Action）负责白名单字段，
--       仅允许更新 downloaded_at / download_url / url_expires_at
CREATE POLICY material_claims_update_self
  ON public.material_claims
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 策略 4：任何管理员可查询所有领取记录
-- 条件：is_admin()（任意活跃管理员）
-- 用途：
--   GET /api/admin/materials/:id/claims（资料维度领取记录列表）
--   GET /api/admin/users/:id/materials（用户维度领取记录，修复 users/[id]/page.tsx 误用）
--   GET /api/admin/materials/:id/stats（领取趋势和用户画像统计）
CREATE POLICY material_claims_select_by_admin
  ON public.material_claims
  FOR SELECT
  USING (public.is_admin());

-- 注意：任何角色（含 manager）均不能通过 RLS 删除领取记录。
-- 领取记录只增不删，保留数据完整性（审计溯源需要）。
-- 若需要物理删除，必须通过 Service Role 执行，并记录审计日志。

-- ============================================================================
-- 本地开发 / 测试 SEED 数据
-- ============================================================================
-- 警告：以下 seed 仅用于本地开发和 CI 测试环境。
-- 生产环境部署前必须删除此 seed 段或使用真实数据替换。
-- storage_key 使用 'seed/placeholder-xxx.pdf' 格式，不含真实文件路径。
-- 引用 migration 1 中的 user UUID（b0000000-0000-0000-0000-000000000001）。

-- seed 资料目录（4 条，覆盖四种类型和各种门槛组合）
INSERT INTO public.materials (
  id, name, type, sub_type, format, storage_key, file_size_bytes,
  description, activity_id, need_login, need_company_info, status, downloads
)
VALUES
  -- 1. 沙龙课件，已上架，PDF，需要登录，不需要企业信息
  (
    'c0000000-0000-0000-0000-000000000001'::uuid,
    '金税四期风险识别与应对实操指南',
    'courseware',
    '课程课件',
    'pdf',
    'seed/placeholder-courseware-001.pdf',
    2457600,  -- 约 2.4 MB
    '系统讲解金税四期背景下企业税务风险识别方法，适合财务负责人和企业老板。',
    NULL,     -- 暂无关联活动（待 activities 表创建后可更新）
    true,     -- need_login=true
    false,    -- need_company_info=false
    'published',
    128
  ),
  -- 2. 政策资料，已上架，PDF，需要登录，需要企业信息（最高门槛）
  (
    'c0000000-0000-0000-0000-000000000002'::uuid,
    '2026年小微企业税收优惠政策汇编',
    'policy',
    '政策解读',
    'pdf',
    'seed/placeholder-policy-001.pdf',
    1048576,  -- 约 1 MB
    '汇编最新小微企业所得税、增值税优惠政策，含申请流程和注意事项。',
    NULL,
    true,     -- need_login=true（need_company_info=true 隐含此项）
    true,     -- need_company_info=true（最高门槛）
    'published',
    64
  ),
  -- 3. 工具表，已上架，Excel，无需登录，无门槛（公开资料）
  (
    'c0000000-0000-0000-0000-000000000003'::uuid,
    '企业税务自查核查清单（通用版）',
    'checklist',
    '自查工具',
    'xlsx',
    'seed/placeholder-checklist-001.xlsx',
    204800,   -- 约 200 KB
    '涵盖增值税、企业所得税、个人所得税三大税种的自查要点，适用大多数中小企业。',
    NULL,
    false,    -- need_login=false
    false,    -- need_company_info=false
    'published',
    312
  ),
  -- 4. 案例资料，草稿，PDF，需要登录，不需要企业信息（draft 不对外可见）
  (
    'c0000000-0000-0000-0000-000000000004'::uuid,
    '制造业企业税务筹划典型案例集',
    'case',
    '案例资料',
    'pdf',
    'seed/placeholder-case-001.pdf',
    3145728,  -- 约 3 MB
    '收录 10 个真实制造业企业税务筹划案例（已脱敏处理），含问题分析和解决方案。',
    NULL,
    true,     -- need_login=true
    false,    -- need_company_info=false
    'draft',  -- 草稿，不对外可见
    0
  )
ON CONFLICT (id) DO NOTHING;

-- seed 领取记录（2 条，引用 migration 1 seed 中的 user b0000000-0000-0000-0000-000000000001）
INSERT INTO public.material_claims (
  id, user_id, material_id, activity_id,
  claimed_at, downloaded_at, download_url, url_expires_at
)
VALUES
  -- user 1 领取了资料 1（课件），已领取但未实际下载
  (
    'd0000000-0000-0000-0000-000000000001'::uuid,
    'b0000000-0000-0000-0000-000000000001'::uuid,  -- 测试用户甲（migration 1 seed）
    'c0000000-0000-0000-0000-000000000001'::uuid,  -- 金税四期风险识别课件
    NULL,         -- 无来源活动上下文
    now() - interval '3 days',  -- 3 天前领取
    NULL,         -- 尚未下载（downloaded_at=null）
    NULL,         -- 无缓存 signed URL
    NULL
  ),
  -- user 1 领取了资料 3（工具表），已领取且已下载
  (
    'd0000000-0000-0000-0000-000000000002'::uuid,
    'b0000000-0000-0000-0000-000000000001'::uuid,  -- 测试用户甲
    'c0000000-0000-0000-0000-000000000003'::uuid,  -- 企业税务自查核查清单
    NULL,
    now() - interval '5 days',                    -- 5 天前领取
    now() - interval '5 days' + interval '2 hours', -- 领取后 2 小时下载
    NULL,  -- seed 中不写入 signed URL（占位，实际由 API 层生成）
    NULL
  )
ON CONFLICT (user_id, material_id) DO NOTHING;

-- 注意：seed 的 material_claims 第 2 条 downloaded_at 不为 null，
-- 但此处是直接 INSERT 而非 UPDATE，所以 trigger increment_material_downloads
-- 不会被触发（trigger 只监听 UPDATE 事件）。
-- 本地验证时可手动执行：
--   UPDATE public.materials SET downloads = 1
--   WHERE id = 'c0000000-0000-0000-0000-000000000003';
-- 或直接接受 seed 的 downloads=312 覆盖此逻辑（seed 已预设合理值）。

-- ============================================================================
-- ROLLBACK SECTION
-- ============================================================================
-- 回滚顺序（与创建顺序相反）：
--
-- -- 1. 删除 trigger 和 trigger 函数
-- DROP TRIGGER IF EXISTS material_claims_increment_downloads ON public.material_claims;
-- DROP TRIGGER IF EXISTS materials_set_updated_at ON public.materials;
-- DROP FUNCTION IF EXISTS public.increment_material_downloads();
--
-- -- 2. 删除表（依赖枚举类型和外键，必须先删表）
-- DROP TABLE IF EXISTS public.material_claims CASCADE;
-- DROP TABLE IF EXISTS public.materials CASCADE;
--
-- -- 3. 删除枚举类型（必须在删表后执行）
-- DROP TYPE IF EXISTS public.material_status_enum;
-- DROP TYPE IF EXISTS public.file_format_enum;
-- DROP TYPE IF EXISTS public.material_type_enum;
--
-- 注意：
--   CASCADE 会同时删除依赖这些表的视图、外键等对象。
--   执行回滚前确认无其他 migration 依赖本 migration 创建的对象。
--   回滚不可恢复数据，执行前备份。
