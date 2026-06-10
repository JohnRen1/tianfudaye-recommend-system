---
name: project-user-module-migration
description: 用户管理模块 migration 已完成，记录关键设计决策和待完成项
metadata:
  type: project
---

用户管理模块 migration 已于 2026-06-10 完成，创建了以下文件：
- `supabase/migrations/20260610120000_create_users_table.sql`
- `docs/database/用户管理.md`

**Why:** 第一个数据库模块，为后续活动管理、二维码、线索等模块提供 users / admin_users 基础表。

**How to apply:** 后续所有模块的外键若指向 users 或 admin_users，可直接引用。活动和二维码表创建后需补全 migration `20260610130000_add_users_fk_constraints.sql`。

## 关键设计决策

- `users.source_activity_id` 和 `users.source_qr_id` 暂无 FK constraint，待 activities / qr_codes 表创建后通过新 migration 补全，删除策略为 ON DELETE SET NULL。
- `users.phone` 存完整 11 位手机号，脱敏由 API 层处理（phoneMasked）。
- `admin_users.password_hash` 不通过 RLS 或列级安全屏蔽，由 API 层在 SELECT 语句中显式排除此列。
- seed 中的 password_hash 全部为占位符（`$2b$12$PLACEHOLDER_...`），部署前必须替换。
- seed 手机号为 138000000X 格式占位，不使用真实号码。

## 待完成（见 docs/database/用户管理.md 第 10 节）

- activities 表创建后补全 users.source_activity_id FK
- qr_codes 表创建后补全 users.source_qr_id FK
- user_timeline_events 表（含 user_id 外键）待行为时间线模块设计
- tags 并发更新需在服务层用 array_cat + array_remove 原子操作
