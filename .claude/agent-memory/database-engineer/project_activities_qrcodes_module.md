---
name: project-activities-qrcodes-module-migration
description: 活动与二维码模块 migration 已完成，记录关键设计决策和待完成项
metadata:
  type: project
---

活动与二维码模块 migration 已于 2026-06-10 完成，创建了以下文件：
- `supabase/migrations/20260610120001_create_activities_qrcodes_table.sql`
- `docs/database/活动与二维码.md`

**Why:** 修复审计 S1（跨实体字符串关联）、S2（四套标识不对齐、validPeriod 非结构化）、S4（字段命名两端不一致、枚举存中文字符串）、S6（统计字段混乱、写死系数）四个高风险问题。

**How to apply:** 依赖 migration 0（admin_users / users 表），同文件末尾补全了 users 表两个悬空外键。材料模块（20260610120002）的 activity_id FK 待单独 migration 补全（见 [[project-materials-module-migration]]）。

## 关键设计决策

- `activities` 和 `qr_codes` 在同一 migration 文件，因为 qr_codes.activity_id 依赖 activities 表。
- `users.source_activity_id` 和 `users.source_qr_id` 两个悬空外键在本文件末尾通过 ALTER TABLE 补全，删除策略 ON DELETE SET NULL。
- 统计计数器（scan/register/material_claims/ai_questions/assessments/appointments/high_intent_leads/material_count）全部采用预存方案，原子递增，定期对账——不实时聚合，避免列表页慢查询。
- `qr_codes.id`（UUID）为归因链唯一外键；`qr_codes.invite_code` 为人类可读短码，两者并存，各司其职（审计不确定项 #1）。
- `qr_codes.valid_to = NULL` 表示长期有效，不引入 `is_permanent` 布尔字段（审计不确定项 #4）。
- `activities.teacher` / `activities.place` 保留 admin 侧字段名；落地页的 `speaker` / `location` 由后端在响应 DTO 中映射，数据库不存落地页字段名（S4）。
- `activities.ai_questions` 新增统计字段，替代 mock 中 `register * 0.61` 写死系数（S6，审计不确定项 #5）。
- `qr_scan_events` 无 `updated_at` trigger，事件不可变（append-only），仅通过 UPDATE 回填 `user_id`。
- `qr_scan_events.qr_code_id ON DELETE CASCADE`：二维码删除时清除所有扫码事件（含归因历史）。如需保留历史可改为 ON DELETE SET NULL，待产品确认。
- RLS 中同时存在管理员策略和匿名用户策略（activities / qr_codes），两者 OR 叠加；落地页实际走 Service Role 绕过 RLS，匿名策略作为安全兜底。
- `invite_code` format CHECK 允许字母数字加短横线和下划线（`^[a-zA-Z0-9_-]+$`），兼容 `CONSULT-ZHOU` 格式的历史 seed 数据。

## 补全的外键关系

本 migration 补全了以下三个模块的外键：
1. `users.source_activity_id → activities.id ON DELETE SET NULL`
2. `users.source_qr_id → qr_codes.id ON DELETE SET NULL`

## 待完成

- 待本 migration 执行后，资料模块需新建 migration 补全 `materials.activity_id` 和 `material_claims.activity_id` 的 FK（见 [[project-materials-module-migration]]）
- `qr_scan_events.qr_code_id` 删除策略（CASCADE vs SET NULL）待产品确认是否需要保留历史扫码数据
- 扫码归因定期对账定时任务（校验 qr_codes.scans 与 qr_scan_events count 一致性）
- 二维码图片生成服务（qr_codes.qr_image_url 填充逻辑）
- channel 字典表（当前 channel 为自由文本，未来可做成外键关联）
