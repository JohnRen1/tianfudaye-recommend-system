---
name: project-leads-module-migration
description: 线索管理模块 migration 已完成，记录关键设计决策、枚举补充和待完成项
metadata:
  type: project
---

线索管理模块 migration 已于 2026-06-10 完成，创建了以下文件：
- `supabase/migrations/20260610120003_create_leads_table.sql`
- `docs/database/线索管理.md`

**Why:** 修复审计 S1（name 字符串关联）、S3（预约不落库）、S5（id 含日期编码）三个高风险问题，建立线索-预约联动机制。

**How to apply:** 依赖 migration 0（users / admin_users / lead_status_enum）和 migration 1（activities / qr_codes）。

## 新增枚举类型

- `lead_level_enum`（strong/high/potential/normal）：意向等级，本 migration 定义
- `appointment_status_enum`（pending/confirmed/completed/cancelled）：预约状态，本 migration 定义
- `appointment_topic_enum`（8 个咨询主题）：与落地页 appointment.ts 同步，本 migration 定义
- `risk_level_enum`：**定义于 migration 4（20260610120004）**，本 migration 不定义。`leads.risk_level` 暂用 text + CHECK 约束（合法值：low/medium/high/critical），待 migration 4 执行后通过新 migration 升级为枚举类型。

## 关键设计决策

- `leads.serial_no` 展示编号（L{YYYYMMDD}{3位}）由 BEFORE INSERT trigger 生成，id 改为 UUID，替代 mock 的 L20260605001 格式。trigger 使用 COUNT(*)+1，并发极低冲突概率由 UNIQUE 约束兜底。
- `leads.level_overridden = true` 时，score 变更不再自动更新 level，由服务端业务层控制（数据库层无此 trigger，逻辑在 API Handler 中）。
- `leads.risk_level` 冗余自 assessment_reports，由服务端写入，不接受前端直传。
- `leads.last_follow_up` 冗余缓存最新跟进记录前 50 字，每次写入 follow_up_records 时由服务端更新，避免列表页 JOIN。
- `follow_up_records` 无 updated_at（append-only），RLS 无 UPDATE/DELETE 策略（默认拒绝），实现不可变审计记录。
- `appointments.lead_id` 可空：预约提交时 lead_id 由服务端异步填充（用户无线索时先创建 Lead 再关联），不在 INSERT 时强制非空。
- `appointments.source_lead_id` 与 `appointments.lead_id` 语义不同：前者是前端 URL 参数传入的原始引用，后者是服务端确认/创建的关联线索，两者通常相同但有边界差异。
- `appointments` 冗余 name/phone 字段：便于后台未关联用户时仍可展示提交信息，不依赖 JOIN users。

## RLS 设计要点

- `leads` SELECT：`is_admin()` 已覆盖所有活跃管理员（含 tax_advisor），因此 tax_advisor 在 RLS 层可读所有行。`leads_select_advisor_own` 策略仅作直连 Supabase 客户端的兜底安全层。**业务层（API Handler）必须额外限制 tax_advisor 只查 `advisor_id = auth.uid()` 的数据。**
- `follow_up_records` INSERT：market_ops 无权添加跟进（仅 tax_advisor / manager），业务层须额外验证 tax_advisor 只能给自己负责的线索（leads.advisor_id = auth.uid()）添加跟进。
- `appointments` UPDATE：market_ops 无权更新预约，预约是顾问跟进环节。

## 外键删除策略

- `leads.user_id → users` RESTRICT：用户删除前须先处理线索
- `leads.activity_id → activities` SET NULL：活动删除不影响线索历史
- `leads.qr_code_id → qr_codes` SET NULL：同上
- `leads.advisor_id → admin_users` SET NULL：顾问账号删除不影响线索
- `follow_up_records.lead_id → leads` CASCADE：线索删除时跟进记录无保留价值
- `follow_up_records.advisor_id → admin_users` RESTRICT：顾问删除前须处理记录
- `appointments.user_id → users` RESTRICT：用户删除前须先处理预约
- `appointments.lead_id/source_lead_id/advisor_id` 均为 SET NULL

## Seed UUID 约定

- leads: e0000000-0000-0000-0000-000000000001 / 000000002
- follow_up_records: f0000000-0000-0000-0000-000000000001 / 000000002
- appointments: g0000000-0000-0000-0000-000000000001

## 待完成

- assessment_reports 模块：直接引用 risk_level_enum（不重新定义），并在写入报告时由服务端 UPDATE leads.risk_level
- 意向分计算服务：需实现 score 维度计算逻辑（assessment_high_risk / report_viewed / appointment_submitted / qa_high_risk），并在事件触发时更新 leads.score + level
- 线索自动创建触发点：测评完成 / 预约提交 / 运营手动创建，均需通过 Service Role 执行
