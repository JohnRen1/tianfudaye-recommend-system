-- migration: 20260610120003_create_leads_table
-- description: 创建 leads、follow_up_records、appointments 表；lead_level_enum / appointment_status_enum / appointment_topic_enum 枚举
-- depends_on: 20260610120001_create_activities_qrcodes_table
-- rollback: 见文件末尾 ROLLBACK SECTION

-- ============================================================================
-- 依赖说明
-- ============================================================================
-- 本 migration 依赖：
--   20260610120000_create_users_table      — public.users、public.admin_users、
--                                             public.lead_status_enum、public.set_updated_at()、
--                                             public.is_admin()、public.get_my_admin_role()
--   20260610120001_create_activities_qrcodes_table — public.activities、public.qr_codes

-- ============================================================================
-- 枚举类型
-- ============================================================================

-- risk_level_enum
-- 注意：risk_level_enum 在 20260610120004_create_assessment_table 中定义。
-- 因为 20260610120003（本 migration）在 20260610120004 之前执行，
-- 但 leads.risk_level 字段类型依赖此枚举，需在此声明为 text + CHECK，
-- 待 migration 4 执行后（risk_level_enum 已存在），
-- 通过 ALTER TABLE 将列类型升级为 risk_level_enum。
--
-- 实际处理方案（见下方 leads 表定义）：
--   leads.risk_level 在本 migration 定义为 text DEFAULT NULL，
--   并添加 CHECK 约束限制合法值，与 risk_level_enum 语义等价。
--   migration 4 执行后，由独立 migration（20260610120006 或更高）补全类型转换：
--     ALTER TABLE public.leads
--       ALTER COLUMN risk_level TYPE public.risk_level_enum
--         USING risk_level::public.risk_level_enum;

-- lead_level_enum — 线索意向等级
-- S5：由服务端根据 score 计算，不接受前端直接传入。
-- 人工覆写时配合 leads.level_overridden = true 标记。
-- 分级阈值：strong >= 100 / high >= 70 / potential >= 40 / normal < 40
CREATE TYPE public.lead_level_enum AS ENUM (
  'strong',    -- 强意向（score >= 100）
  'high',      -- 高意向（score >= 70）
  'potential', -- 潜在线索（score >= 40）
  'normal'     -- 普通用户（score < 40）
);

-- appointment_status_enum — 预约状态
-- 独立于 lead_status_enum，描述单次预约事件的生命周期。
-- 状态机：pending → confirmed → completed
--                    └──────────────┴──► cancelled
CREATE TYPE public.appointment_status_enum AS ENUM (
  'pending',    -- 待联系：预约刚提交，尚无顾问跟进
  'confirmed',  -- 已确认：顾问已确认联系时间
  'completed',  -- 已完成：通话/会面已完成
  'cancelled'   -- 已取消：用户取消或顾问标记无效
);

-- appointment_topic_enum — 预约咨询主题
-- 与落地页 lib/contracts/appointment.ts AppointmentTopic 同步。
-- 任何新增值必须两端同步更新。
CREATE TYPE public.appointment_topic_enum AS ENUM (
  'tax_risk_check',          -- 税务风险排查
  'invoice_compliance',      -- 发票合规
  'public_to_private_risk',  -- 公转私风险
  'corporate_income_tax',    -- 企业所得税筹划
  'individual_tax_social',   -- 个税社保合规
  'tax_audit_response',      -- 税务稽查应对
  'company_structure',       -- 公司架构设计
  'other'                    -- 其他问题
);

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- generate_lead_serial_no()
-- 在 BEFORE INSERT 触发器中调用，当 serial_no 为空时自动生成。
-- 格式：L{YYYYMMDD}{3位序号}，如 L20260610001。
-- 注意：此函数用 COUNT(*)+1 生成序号，并发极低冲突概率极小；
--   若业务量激增可改为 advisory lock 或独立序列表方案。
--   同一天的第 1000 条线索起序号会变为 4 位，不影响唯一性（UNIQUE 约束保证）。
CREATE OR REPLACE FUNCTION public.generate_lead_serial_no()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  today_prefix text;
  seq_num      integer;
BEGIN
  -- 仅在 serial_no 未提供时生成（WHEN 条件已在 trigger 定义中过滤，此处双重保险）
  IF NEW.serial_no IS NOT NULL AND NEW.serial_no <> '' THEN
    RETURN NEW;
  END IF;

  today_prefix := 'L' || to_char(now() AT TIME ZONE 'Asia/Shanghai', 'YYYYMMDD');

  SELECT COUNT(*) + 1 INTO seq_num
  FROM   public.leads
  WHERE  serial_no LIKE today_prefix || '%';

  NEW.serial_no := today_prefix || lpad(seq_num::text, 3, '0');
  RETURN NEW;
END;
$$;

-- ============================================================================
-- TABLE: public.leads
-- ============================================================================
-- 线索主表，对应落地页用户在转化漏斗中的商机记录。
-- 一个用户可以有多条线索（多次活动、多个渠道归因），业务层通常维护每用户一条"激活"线索。
--
-- 核心设计决策：
--   S1  — 全部关联字段使用外键（user_id / activity_id / qr_code_id / advisor_id）
--   S5  — serial_no / score / level / last_follow_up 均为服务端生成/计算字段
--   Mock 修复 — 废弃 id 含日期格式（L20260605001），id 改为 UUID，展示用 serial_no 独立字段

CREATE TABLE public.leads (
  -- 主键：UUID，系统内部路由键（替代 mock 中 L20260605001 格式 id）
  id                uuid         NOT NULL DEFAULT gen_random_uuid(),

  -- 展示编号：L{YYYYMMDD}{3位序号}，由 trigger 生成，全局唯一
  -- 设为可空以兼容 trigger 执行前的瞬态（trigger BEFORE INSERT 时填充）
  serial_no         text         NOT NULL DEFAULT '',

  -- 关联端用户（S1：必须为外键，替代 mock 中 name 字符串关联）
  -- ON DELETE RESTRICT：用户删除前须先处理其线索（或由业务层先软停用）
  user_id           uuid         NOT NULL,

  -- 来源活动（S1：替代 mock 中 activity 字符串）
  -- ON DELETE SET NULL：活动删除后线索保留，仅解除关联
  activity_id       uuid         DEFAULT NULL,

  -- 来源二维码（S1：替代 mock 中 qr 字符串混用 inviteCode/id 问题）
  -- ON DELETE SET NULL：二维码删除后线索保留
  qr_code_id        uuid         DEFAULT NULL,

  -- 分配顾问（S1：替代 mock 中 advisor 字符串）
  -- ON DELETE SET NULL：顾问账号删除后线索保留，仅解除分配
  advisor_id        uuid         DEFAULT NULL,

  -- 需求标签数组（运营人工打标 + 预约 topic 自动映射）
  tags              text[]       NOT NULL DEFAULT '{}',

  -- 意向分：服务端计算（各维度之和，无上限）
  -- 分级阈值：>=100 strong / >=70 high / >=40 potential / <40 normal
  score             integer      NOT NULL DEFAULT 0,

  -- 意向等级：服务端根据 score 自动计算，level_overridden=true 时人工覆写生效
  level             public.lead_level_enum NOT NULL DEFAULT 'normal',

  -- 人工覆写标记：true 时 score 变更不再自动更新 level
  level_overridden  boolean      NOT NULL DEFAULT false,

  -- 风险等级：冗余自 assessment_reports.risk_level，方便列表展示无需 JOIN
  -- null 表示该用户尚未完成测评
  -- 注意：risk_level_enum 在 migration 4 中定义，晚于本 migration。
  --   此处暂用 text + CHECK 约束（语义等价），待 migration 4 执行后
  --   通过新 migration 执行：
  --     ALTER TABLE public.leads
  --       ALTER COLUMN risk_level TYPE public.risk_level_enum
  --         USING risk_level::public.risk_level_enum;
  risk_level        text DEFAULT NULL,

  -- 线索状态（状态机，见文件末尾说明）
  -- 状态机：new→pending→assigned→following→appointed→converted / 任意→invalid
  status            public.lead_status_enum NOT NULL DEFAULT 'new',

  -- 最近跟进摘要（冗余缓存 follow_up_records 最新记录的前 50 字）
  -- 每次写入 follow_up_records 时由服务端更新此字段，避免详情列表频繁 JOIN
  last_follow_up    text         DEFAULT NULL,

  -- 时间戳
  created_at        timestamptz  NOT NULL DEFAULT now(),
  updated_at        timestamptz  NOT NULL DEFAULT now(),

  -- ---- 约束 ----
  CONSTRAINT leads_pkey
    PRIMARY KEY (id),

  CONSTRAINT leads_serial_no_uq
    UNIQUE (serial_no),

  -- 关联端用户（S1：外键必须建立）
  CONSTRAINT leads_user_id_fk
    FOREIGN KEY (user_id)
    REFERENCES public.users(id)
    ON DELETE RESTRICT,

  -- 关联来源活动（活动删除后置 NULL，不影响线索历史）
  CONSTRAINT leads_activity_id_fk
    FOREIGN KEY (activity_id)
    REFERENCES public.activities(id)
    ON DELETE SET NULL,

  -- 关联来源二维码（二维码删除后置 NULL）
  CONSTRAINT leads_qr_code_id_fk
    FOREIGN KEY (qr_code_id)
    REFERENCES public.qr_codes(id)
    ON DELETE SET NULL,

  -- 关联分配顾问（顾问删除后置 NULL，保留线索）
  CONSTRAINT leads_advisor_id_fk
    FOREIGN KEY (advisor_id)
    REFERENCES public.admin_users(id)
    ON DELETE SET NULL,

  -- 意向分不能为负
  CONSTRAINT leads_score_non_negative_ck
    CHECK (score >= 0),

  -- risk_level 合法值约束（与 migration 4 中定义的 risk_level_enum 枚举值语义等价）
  -- 待 migration 4 执行后，通过新 migration 将此列升级为 risk_level_enum 类型
  CONSTRAINT leads_risk_level_ck
    CHECK (risk_level IN ('low', 'medium', 'high', 'critical') OR risk_level IS NULL),

  -- tags 数量上限 30（对应 API 约定，防止无上限增长）
  CONSTRAINT leads_tags_count_ck
    CHECK (array_length(tags, 1) IS NULL OR array_length(tags, 1) <= 30)
);

COMMENT ON TABLE  public.leads                    IS '线索主表：落地页用户在转化漏斗中的商机记录';
COMMENT ON COLUMN public.leads.id                 IS 'UUID 主键，API 路由键；替代 mock 的 L20260605001 格式';
COMMENT ON COLUMN public.leads.serial_no          IS '展示编号 L{YYYYMMDD}{3位序号}，由 trigger 生成，全局唯一';
COMMENT ON COLUMN public.leads.user_id            IS '关联端用户外键（S1，替代 name 字符串关联）';
COMMENT ON COLUMN public.leads.activity_id        IS '来源活动外键（S1，替代 activity 字符串），可空';
COMMENT ON COLUMN public.leads.qr_code_id         IS '来源二维码外键（S1，修复 mock qr 字段混用 id/inviteCode），可空';
COMMENT ON COLUMN public.leads.advisor_id         IS '分配顾问外键（S1，替代 advisor 字符串），可空';
COMMENT ON COLUMN public.leads.tags               IS '需求标签数组，运营人工打标 + 系统自动映射，最多 30 个';
COMMENT ON COLUMN public.leads.score              IS '意向分，服务端计算（各维度之和，无上限），100 为高亮阈值';
COMMENT ON COLUMN public.leads.level              IS '意向等级，服务端按 score 自动计算；level_overridden=true 时人工覆写';
COMMENT ON COLUMN public.leads.level_overridden   IS 'true=人工覆写意向等级生效，score 变更时系统不再自动更新 level';
COMMENT ON COLUMN public.leads.risk_level         IS '风险等级，冗余自 assessment_reports，null 表示未完成测评';
COMMENT ON COLUMN public.leads.status             IS '线索状态，状态机：new→pending→assigned→following→appointed→converted / →invalid';
COMMENT ON COLUMN public.leads.last_follow_up     IS '最近跟进摘要（最新 follow_up_records.content 前 50 字冗余缓存）';
COMMENT ON COLUMN public.leads.created_at         IS '线索创建时间（UTC）';
COMMENT ON COLUMN public.leads.updated_at         IS '最近修改时间（UTC），trigger 自动更新';

-- updated_at 自动更新 trigger
CREATE TRIGGER leads_set_updated_at
  BEFORE UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- serial_no 自动生成 trigger
-- WHEN 条件：仅在 serial_no 为空字符串（DEFAULT ''）时触发，
--   避免批量导入时对已有编号的数据重新生成。
CREATE TRIGGER leads_generate_serial_no
  BEFORE INSERT ON public.leads
  FOR EACH ROW
  WHEN (NEW.serial_no = '' OR NEW.serial_no IS NULL)
  EXECUTE FUNCTION public.generate_lead_serial_no();

-- ============================================================================
-- TABLE: public.follow_up_records
-- ============================================================================
-- 线索跟进记录，append-only（追加不可变）。
-- 每次顾问跟进操作写入一条记录，写入后不允许修改或删除（无 updated_at）。
-- 写入成功后，服务端同步更新 leads.last_follow_up（前 50 字摘要）。
--
-- Mock 修复：原 mock 仅有 leads.last 字符串，无独立实体，历史记录完全丢失。

CREATE TABLE public.follow_up_records (
  -- 主键：UUID
  id          uuid         NOT NULL DEFAULT gen_random_uuid(),

  -- 归属线索（CASCADE：线索删除则同步删除所有跟进记录）
  lead_id     uuid         NOT NULL,

  -- 操作人（RESTRICT：顾问账号删除前需先处理其跟进记录，或由业务层先转移）
  advisor_id  uuid         NOT NULL,

  -- 跟进内容正文（不允许空字符串）
  content     text         NOT NULL,

  -- 本次跟进后更新的线索状态，null 表示本次跟进未变更状态
  new_status  public.lead_status_enum DEFAULT NULL,

  -- 创建时间（唯一时间字段，无 updated_at，记录不可变）
  created_at  timestamptz  NOT NULL DEFAULT now(),

  -- ---- 约束 ----
  CONSTRAINT follow_up_records_pkey
    PRIMARY KEY (id),

  -- 归属线索外键（线索删除时级联删除跟进记录）
  CONSTRAINT follow_up_records_lead_id_fk
    FOREIGN KEY (lead_id)
    REFERENCES public.leads(id)
    ON DELETE CASCADE,

  -- 操作人外键（顾问删除前须先处理，防止孤立记录）
  CONSTRAINT follow_up_records_advisor_id_fk
    FOREIGN KEY (advisor_id)
    REFERENCES public.admin_users(id)
    ON DELETE RESTRICT,

  -- 跟进内容不允许空白字符串
  CONSTRAINT follow_up_records_content_not_blank_ck
    CHECK (length(trim(content)) > 0)
);

COMMENT ON TABLE  public.follow_up_records              IS '线索跟进记录，append-only，写入后不可修改';
COMMENT ON COLUMN public.follow_up_records.id           IS 'UUID 主键';
COMMENT ON COLUMN public.follow_up_records.lead_id      IS '归属线索外键（CASCADE 删除）';
COMMENT ON COLUMN public.follow_up_records.advisor_id   IS '操作人管理员外键（RESTRICT 删除）';
COMMENT ON COLUMN public.follow_up_records.content      IS '跟进内容正文，不允许空白';
COMMENT ON COLUMN public.follow_up_records.new_status   IS '本次跟进后的线索状态变更；null 表示未变更';
COMMENT ON COLUMN public.follow_up_records.created_at   IS '跟进时间（UTC），不可变';

-- 注意：follow_up_records 无 updated_at 字段，记录追加后不可修改，无需 trigger。

-- ============================================================================
-- TABLE: public.appointments
-- ============================================================================
-- 预约记录，同时服务于落地页（用户提交）和管理后台（顾问管理）。
-- 设计为独立实体（非 Lead 的字段扩展），通过 lead_id 外键与 Lead 关联。
--
-- Mock 修复：
--   S3  — 原落地页 handleSubmit 仅 setSubmitted(true)，此表承接真实落库
--   S1  — user_id / lead_id / advisor_id 全部为外键
--   Mock 审计不确定项 #1 决策 — Appointment 作为独立实体，通过 lead_id 外键关联
--
-- 认证说明：
--   - 已登录用户提交：user_id 由服务端从 JWT 注入
--   - 未登录用户提交：通过 phone 匹配已有用户，匹配失败则 user_id 暂为服务端占位 UUID
--     （后续接入时可扩展匿名用户逻辑，当前阶段要求已登录才能提交）
--   - name / phone 冗余保存在记录中，便于未关联用户时的后台查看

CREATE TABLE public.appointments (
  -- 主键：UUID
  id              uuid         NOT NULL DEFAULT gen_random_uuid(),

  -- 关联端用户（RESTRICT：用户删除前须先处理其预约）
  user_id         uuid         NOT NULL,

  -- 关联线索（SET NULL：线索删除后预约保留历史记录）
  -- null 表示预约提交时尚无对应线索（由服务端后续补全）
  lead_id         uuid         DEFAULT NULL,

  -- 分配顾问（SET NULL：顾问删除后预约保留，解除顾问关联）
  advisor_id      uuid         DEFAULT NULL,

  -- 咨询主题枚举（与 AppointmentTopic 同步）
  topic           public.appointment_topic_enum NOT NULL,

  -- 问题描述（不允许空白字符串）
  description     text         NOT NULL,

  -- 企业名称（可空，提交时填写）
  company         text         DEFAULT NULL,

  -- 行业（可空）
  industry        text         DEFAULT NULL,

  -- 方便联系时间（自由文本，如"工作日下午"，可空）
  contact_time    text         DEFAULT NULL,

  -- 微信号（可空）
  wechat          text         DEFAULT NULL,

  -- 是否愿意上传资料（自由文本，意向信号，可空）
  upload_intent   text         DEFAULT NULL,

  -- 提交时的手机号（冗余，便于后台查看和用户匹配）
  -- 存完整 11 位，展示层脱敏；格式约束与 users.phone 一致
  phone           text         NOT NULL,

  -- 提交时的姓名（冗余，便于后台查看）
  name            text         NOT NULL,

  -- 预约状态
  status          public.appointment_status_enum NOT NULL DEFAULT 'pending',

  -- 顾问确认的联系时间（顾问操作后填写，提交时为 null）
  scheduled_at    timestamptz  DEFAULT NULL,

  -- 来源线索 id（若从报告页跳转则由 URL 参数传入）
  -- 与 lead_id 的区别：lead_id 是服务端关联/创建的线索，source_lead_id 是前端传入的原始引用
  -- 两者通常相同，但存在前端传入 source_lead_id 后服务端决定创建新线索的边界情况
  source_lead_id  uuid         DEFAULT NULL,

  -- 时间戳
  created_at      timestamptz  NOT NULL DEFAULT now(),
  updated_at      timestamptz  NOT NULL DEFAULT now(),

  -- ---- 约束 ----
  CONSTRAINT appointments_pkey
    PRIMARY KEY (id),

  -- 关联端用户（RESTRICT：用户删除前须先处理其预约）
  CONSTRAINT appointments_user_id_fk
    FOREIGN KEY (user_id)
    REFERENCES public.users(id)
    ON DELETE RESTRICT,

  -- 关联线索（线索删除后置 NULL，预约历史记录保留）
  CONSTRAINT appointments_lead_id_fk
    FOREIGN KEY (lead_id)
    REFERENCES public.leads(id)
    ON DELETE SET NULL,

  -- 分配顾问（顾问删除后置 NULL）
  CONSTRAINT appointments_advisor_id_fk
    FOREIGN KEY (advisor_id)
    REFERENCES public.admin_users(id)
    ON DELETE SET NULL,

  -- 来源线索（线索删除后置 NULL）
  CONSTRAINT appointments_source_lead_id_fk
    FOREIGN KEY (source_lead_id)
    REFERENCES public.leads(id)
    ON DELETE SET NULL,

  -- 手机号格式：1 开头 11 位（中国大陆手机号）
  CONSTRAINT appointments_phone_ck
    CHECK (phone ~ '^1[0-9]{10}$'),

  -- 问题描述不允许空白字符串
  CONSTRAINT appointments_description_not_blank_ck
    CHECK (length(trim(description)) > 0),

  -- 姓名不允许空白字符串
  CONSTRAINT appointments_name_not_blank_ck
    CHECK (length(trim(name)) > 0)
);

COMMENT ON TABLE  public.appointments                    IS '预约记录，落地页用户提交 + 管理后台管理，与 leads 通过 lead_id 关联';
COMMENT ON COLUMN public.appointments.id                 IS 'UUID 主键';
COMMENT ON COLUMN public.appointments.user_id            IS '关联端用户外键（S1，RESTRICT 删除）';
COMMENT ON COLUMN public.appointments.lead_id            IS '关联线索外键（S1），null 表示尚未关联；服务端提交时自动填充';
COMMENT ON COLUMN public.appointments.advisor_id         IS '分配顾问外键（S1），null 表示尚未分配';
COMMENT ON COLUMN public.appointments.topic              IS '咨询主题枚举，与落地页 AppointmentTopic 同步';
COMMENT ON COLUMN public.appointments.description        IS '问题描述，不允许空白';
COMMENT ON COLUMN public.appointments.company            IS '企业名称（冗余字段，可空）';
COMMENT ON COLUMN public.appointments.industry           IS '行业（可空）';
COMMENT ON COLUMN public.appointments.contact_time       IS '方便联系时间（自由文本，可空）';
COMMENT ON COLUMN public.appointments.wechat             IS '微信号（可空）';
COMMENT ON COLUMN public.appointments.upload_intent      IS '是否愿意上传资料（意向信号，可空）';
COMMENT ON COLUMN public.appointments.phone              IS '提交时手机号（冗余，11 位中国大陆格式，展示层脱敏）';
COMMENT ON COLUMN public.appointments.name               IS '提交时姓名（冗余，不允许空白）';
COMMENT ON COLUMN public.appointments.status             IS '预约状态：pending→confirmed→completed / →cancelled';
COMMENT ON COLUMN public.appointments.scheduled_at       IS '顾问确认的联系时间（UTC），顾问操作后填写';
COMMENT ON COLUMN public.appointments.source_lead_id     IS '来源线索 id（前端 URL 参数传入），与 lead_id 通常相同';
COMMENT ON COLUMN public.appointments.created_at         IS '预约提交时间（UTC）';
COMMENT ON COLUMN public.appointments.updated_at         IS '最近修改时间（UTC），trigger 自动更新';

-- updated_at 自动更新 trigger
CREATE TRIGGER appointments_set_updated_at
  BEFORE UPDATE ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 索引
-- ============================================================================

-- ---------- leads 索引 ----------

-- user_id 索引：查某用户的所有线索（核心查询）
CREATE INDEX idx_leads_user_id
  ON public.leads (user_id);

-- advisor_id 部分索引：按顾问筛选（LeadQueryDTO.advisorId），仅对已分配行建索引
CREATE INDEX idx_leads_advisor_id
  ON public.leads (advisor_id)
  WHERE advisor_id IS NOT NULL;

-- activity_id 部分索引：按来源活动筛选（LeadQueryDTO.activityId）
CREATE INDEX idx_leads_activity_id
  ON public.leads (activity_id)
  WHERE activity_id IS NOT NULL;

-- qr_code_id 部分索引：按来源二维码筛选（LeadQueryDTO.qrCodeId）
CREATE INDEX idx_leads_qr_code_id
  ON public.leads (qr_code_id)
  WHERE qr_code_id IS NOT NULL;

-- status 索引：线索状态筛选（Tab 切换，LeadQueryDTO.status）
CREATE INDEX idx_leads_status
  ON public.leads (status);

-- level 索引：意向等级筛选（LeadQueryDTO.level）
CREATE INDEX idx_leads_level
  ON public.leads (level);

-- score DESC 索引：按意向分排序（LeadQueryDTO.sortBy=score）
CREATE INDEX idx_leads_score_desc
  ON public.leads (score DESC);

-- created_at DESC 索引：默认排序（LeadQueryDTO.sortBy=createdAt desc），分页稳定性
CREATE INDEX idx_leads_created_at_desc
  ON public.leads (created_at DESC);

-- updated_at DESC 索引：按更新时间排序（LeadQueryDTO.sortBy=updatedAt）
CREATE INDEX idx_leads_updated_at_desc
  ON public.leads (updated_at DESC);

-- tags GIN 索引：标签包含查询（LeadQueryDTO.tag → array contains @>）
CREATE INDEX idx_leads_tags_gin
  ON public.leads USING GIN (tags);

-- risk_level 部分索引：风险等级筛选（LeadQueryDTO.riskLevel），仅对非 null 行建索引
CREATE INDEX idx_leads_risk_level
  ON public.leads (risk_level)
  WHERE risk_level IS NOT NULL;

-- ---------- follow_up_records 索引 ----------

-- lead_id 索引：查某线索的所有跟进记录（核心查询，与 created_at 联合支持分页）
CREATE INDEX idx_follow_up_records_lead_id_created_at
  ON public.follow_up_records (lead_id, created_at DESC);

-- advisor_id 索引：查某顾问的所有跟进记录（运营统计用）
CREATE INDEX idx_follow_up_records_advisor_id
  ON public.follow_up_records (advisor_id);

-- created_at DESC 索引：时间排序（跟进记录时间线倒序展示）
CREATE INDEX idx_follow_up_records_created_at_desc
  ON public.follow_up_records (created_at DESC);

-- ---------- appointments 索引 ----------

-- user_id 索引：查某用户的所有预约（GET /api/appointments/me）
CREATE INDEX idx_appointments_user_id
  ON public.appointments (user_id);

-- lead_id 部分索引：查某线索的关联预约（线索详情卡片）
CREATE INDEX idx_appointments_lead_id
  ON public.appointments (lead_id)
  WHERE lead_id IS NOT NULL;

-- advisor_id 部分索引：按顾问筛选（已分配顾问的预约）
CREATE INDEX idx_appointments_advisor_id
  ON public.appointments (advisor_id)
  WHERE advisor_id IS NOT NULL;

-- status 索引：预约状态筛选
CREATE INDEX idx_appointments_status
  ON public.appointments (status);

-- created_at DESC 索引：默认排序（分页稳定性）
CREATE INDEX idx_appointments_created_at_desc
  ON public.appointments (created_at DESC);

-- ============================================================================
-- Row Level Security（RLS）
-- ============================================================================

-- ---------- leads RLS ----------

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何已认证管理员可读所有线索行
-- 用途：GET /api/admin/leads、GET /api/admin/leads/:id
-- is_admin() 覆盖所有活跃角色（market_ops / tax_advisor / manager）
CREATE POLICY leads_select_by_admin
  ON public.leads
  FOR SELECT
  USING (public.is_admin());

-- 策略 2：tax_advisor 仅可读分配给自己的线索
-- 注意：策略 1 与策略 2 对 tax_advisor 的覆盖关系
--   PostgreSQL RLS 多策略使用 OR 逻辑（FOR SELECT），两策略均匹配时行可见。
--   策略 1 中 is_admin() 已对 tax_advisor 返回 true，因此 tax_advisor 实际能读所有行。
--   业务层（API Handler）需额外校验 tax_advisor 只能查自己分配的线索：
--     WHERE advisor_id = auth.uid() OR role IN ('market_ops', 'manager')
--   此策略保留为"直连 Supabase 客户端"场景的兜底安全层（防止绕过 API 层直查）。
CREATE POLICY leads_select_advisor_own
  ON public.leads
  FOR SELECT
  USING (
    public.get_my_admin_role() = 'tax_advisor'
    AND advisor_id = auth.uid()
  );

-- 策略 3：market_ops / manager 可创建线索（手动创建线索，系统自动创建走 Service Role）
CREATE POLICY leads_insert_by_market_ops_or_manager
  ON public.leads
  FOR INSERT
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 4：market_ops / manager 可更新线索（含标签/levelOverride/状态/顾问分配）
CREATE POLICY leads_update_by_market_ops_or_manager
  ON public.leads
  FOR UPDATE
  USING (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  )
  WITH CHECK (
    public.get_my_admin_role() IN ('market_ops', 'manager')
  );

-- 策略 5：tax_advisor / manager 可更新自己分配的线索（状态变更、跟进摘要更新）
-- 此策略与策略 4 通过 OR 逻辑联合生效
CREATE POLICY leads_update_by_tax_advisor_own
  ON public.leads
  FOR UPDATE
  USING (
    public.get_my_admin_role() = 'tax_advisor'
    AND advisor_id = auth.uid()
  )
  WITH CHECK (
    public.get_my_admin_role() = 'tax_advisor'
    AND advisor_id = auth.uid()
  );

-- 策略 6：仅 manager 可删除线索（生产环境建议改为软删除，此策略仅作权限边界）
CREATE POLICY leads_delete_by_manager
  ON public.leads
  FOR DELETE
  USING (public.get_my_admin_role() = 'manager');

-- 注意：Service Role（后端 API / Server Action）绕过 RLS，拥有全部权限。
-- 系统自动创建线索（测评完成 / 预约提交触发）均通过 Service Role 执行。

-- ---------- follow_up_records RLS ----------

ALTER TABLE public.follow_up_records ENABLE ROW LEVEL SECURITY;

-- 策略 1：任何已认证管理员可读所有跟进记录
CREATE POLICY follow_up_records_select_by_admin
  ON public.follow_up_records
  FOR SELECT
  USING (public.is_admin());

-- 策略 2：tax_advisor / manager 可添加跟进记录
-- market_ops 无权添加跟进记录（仅管理线索分配，不参与销售跟进）
-- 注意：业务层需额外校验 tax_advisor 只能给自己负责的线索添加跟进（通过 leads.advisor_id = auth.uid()）
CREATE POLICY follow_up_records_insert_by_advisor_or_manager
  ON public.follow_up_records
  FOR INSERT
  WITH CHECK (
    public.get_my_admin_role() IN ('tax_advisor', 'manager')
  );

-- 策略 3：任何人均不能 UPDATE / DELETE 跟进记录（追加不可变原则）
-- 不显式定义 UPDATE / DELETE 策略，默认拒绝（RLS 开启后无策略 = 拒绝）

-- ---------- appointments RLS ----------

ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- 策略 1：端用户可读取自己的预约记录（GET /api/appointments/me）
CREATE POLICY appointments_select_self
  ON public.appointments
  FOR SELECT
  USING (auth.uid() = user_id);

-- 策略 2：端用户可创建预约（POST /api/appointments）
-- 用途：落地页预约顾问提交；user_id 由服务端从 JWT 注入后校验
CREATE POLICY appointments_insert_self
  ON public.appointments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 策略 3：任何已认证管理员可读所有预约记录
-- 用途：GET /api/admin/leads/:id（线索详情中的预约卡片）
CREATE POLICY appointments_select_by_admin
  ON public.appointments
  FOR SELECT
  USING (public.is_admin());

-- 策略 4：tax_advisor / manager 可更新预约（状态变更、分配顾问、填写联系时间）
-- market_ops 无权更新预约（预约是顾问跟进环节，不属于运营管理范围）
CREATE POLICY appointments_update_by_advisor_or_manager
  ON public.appointments
  FOR UPDATE
  USING (
    public.get_my_admin_role() IN ('tax_advisor', 'manager')
  )
  WITH CHECK (
    public.get_my_admin_role() IN ('tax_advisor', 'manager')
  );

-- 注意：Service Role 绕过 RLS，用于：
--   1. 预约提交后自动关联/创建 Lead（触发 Lead 状态联动）
--   2. 更新 leads.status 为 'appointed'
--   3. 更新 leads.last_follow_up 摘要缓存

-- ============================================================================
-- 本地开发 / 测试 SEED 数据
-- ============================================================================
-- 警告：以下 seed 仅用于本地开发和 CI 测试环境，生产环境不应执行此段。
-- 生产环境部署前必须删除或替换所有 seed 数据。
--
-- 依赖 seed UUID（来自已有 migration seed）：
--   users:       b0000000-0000-0000-0000-000000000001 (测试用户甲)
--                b0000000-0000-0000-0000-000000000002 (测试用户乙)
--   admin_users: a0000000-0000-0000-0000-000000000003 (advisor_demo / 周顾问)
--                a0000000-0000-0000-0000-000000000002 (ops_demo / 运营小李)
--   activities:  c0000000-0000-0000-0000-000000000001 (金税四期风险识别专题课)
--   qr_codes:    d0000000-0000-0000-0000-000000000001 (金税四期专题课-活动码)

-- seed leads（2 条）
INSERT INTO public.leads (
  id,
  serial_no,
  user_id,
  activity_id,
  qr_code_id,
  advisor_id,
  tags,
  score,
  level,
  level_overridden,
  risk_level,
  status,
  last_follow_up,
  created_at,
  updated_at
)
VALUES
  (
    'e0000000-0000-0000-0000-000000000001'::uuid,
    'L20260610001',
    'b0000000-0000-0000-0000-000000000001'::uuid,  -- 测试用户甲
    'c0000000-0000-0000-0000-000000000001'::uuid,  -- 金税四期风险识别专题课
    'd0000000-0000-0000-0000-000000000001'::uuid,  -- 金税四期专题课-活动码
    'a0000000-0000-0000-0000-000000000003'::uuid,  -- 周顾问
    ARRAY['公转私风险', '税务稽查'],
    118,
    'strong',
    false,
    'high',
    'following',
    '已电话联系，客户表示本周五有时间详聊，约定周五下午三点回访。',
    now() - interval '5 days',
    now() - interval '1 day'
  ),
  (
    'e0000000-0000-0000-0000-000000000002'::uuid,
    'L20260610002',
    'b0000000-0000-0000-0000-000000000002'::uuid,  -- 测试用户乙
    'c0000000-0000-0000-0000-000000000001'::uuid,  -- 金税四期风险识别专题课
    NULL,
    NULL,
    ARRAY['发票合规'],
    58,
    'potential',
    false,
    'medium',
    'new',
    NULL,
    now() - interval '2 days',
    now() - interval '2 days'
  )
ON CONFLICT (id) DO NOTHING;

-- seed follow_up_records（2 条，均属于 lead e0000000-...0001）
INSERT INTO public.follow_up_records (
  id,
  lead_id,
  advisor_id,
  content,
  new_status,
  created_at
)
VALUES
  (
    'f0000000-0000-0000-0000-000000000001'::uuid,
    'e0000000-0000-0000-0000-000000000001'::uuid,  -- 线索甲
    'a0000000-0000-0000-0000-000000000003'::uuid,  -- 周顾问
    '初次电话沟通，客户为制造业企业财务负责人，主要关注公转私合规性问题。已介绍服务内容，客户表示需要进一步了解。',
    'assigned',
    now() - interval '4 days'
  ),
  (
    'f0000000-0000-0000-0000-000000000002'::uuid,
    'e0000000-0000-0000-0000-000000000001'::uuid,  -- 线索甲
    'a0000000-0000-0000-0000-000000000003'::uuid,  -- 周顾问
    '二次回访，客户确认需要税务风险全面体检服务，计划下周签约。状态更新为跟进中。',
    'following',
    now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

-- seed appointments（1 条，关联用户甲和线索甲）
INSERT INTO public.appointments (
  id,
  user_id,
  lead_id,
  advisor_id,
  topic,
  description,
  company,
  industry,
  contact_time,
  wechat,
  upload_intent,
  phone,
  name,
  status,
  scheduled_at,
  source_lead_id,
  created_at,
  updated_at
)
VALUES
  (
    'g0000000-0000-0000-0000-000000000001'::uuid,
    'b0000000-0000-0000-0000-000000000001'::uuid,  -- 测试用户甲
    'e0000000-0000-0000-0000-000000000001'::uuid,  -- 线索甲
    'a0000000-0000-0000-0000-000000000003'::uuid,  -- 周顾问
    'public_to_private_risk',
    '公司近期存在频繁公转私操作，担心触发金税四期预警，希望顾问详细解读风险并提供合规建议。',
    '示例科技有限公司',
    '互联网',
    '工作日下午',
    'testuser_wx_001',
    '愿意上传相关账目资料',
    '13800000001',   -- 与 users seed 一致，非真实号码
    '测试用户甲',
    'confirmed',
    now() + interval '2 days',
    'e0000000-0000-0000-0000-000000000001'::uuid,
    now() - interval '3 days',
    now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Lead 状态机说明（注释）
-- ============================================================================
--
-- 合法转换路径：
--
--   new ──► pending ──► assigned ──► following ──► appointed ──► converted
--    │                      │             │              │
--    └──────────────────────┴─────────────┴──────────────┴──► invalid
--
-- 终态约束（API 层强制）：
--   - converted / invalid 不允许再转换到其他状态
--   - invalid 只能由 manager / market_ops 设置
--   - converted 只能由 tax_advisor / manager 设置
--
-- 预约联动（POST /api/appointments 服务端处理）：
--   若线索 status 不是 'appointed' / 'converted'，自动更新为 'appointed'。
--   若用户尚无线索（User.lead_status = 'none'），先创建 Lead（status='appointed'），
--   再创建 Appointment 并填入 lead_id。
--
-- Appointment 状态机：
--   pending ──► confirmed ──► completed
--      │              │
--      └──────────────┴──► cancelled
--
-- ============================================================================
-- ROLLBACK SECTION
-- ============================================================================
-- 回滚顺序（与创建顺序相反，先删依赖方）：
--
-- -- 1. 删除表（按依赖顺序：appointments 先删，然后 follow_up_records，最后 leads）
-- DROP TABLE IF EXISTS public.appointments CASCADE;
-- DROP TABLE IF EXISTS public.follow_up_records CASCADE;
-- DROP TABLE IF EXISTS public.leads CASCADE;
--
-- -- 2. 删除触发器函数
-- DROP FUNCTION IF EXISTS public.generate_lead_serial_no();
--
-- -- 3. 删除枚举类型（必须在依赖表删除后执行）
-- DROP TYPE IF EXISTS public.appointment_topic_enum;
-- DROP TYPE IF EXISTS public.appointment_status_enum;
-- DROP TYPE IF EXISTS public.lead_level_enum;
--
-- 注意：
--   - DROP TABLE 使用 CASCADE，会同时删除所有依赖对象（索引、触发器、RLS 策略）。
--   - 回滚不影响 migration 0-2 创建的内容。
--   - risk_level_enum 在本 migration 中未定义（定义于 migration 4），回滚此 migration 不删除该枚举。
--   - leads.risk_level 列为 text 类型（暂用 CHECK 约束），回滚后随表删除，无需额外处理。
