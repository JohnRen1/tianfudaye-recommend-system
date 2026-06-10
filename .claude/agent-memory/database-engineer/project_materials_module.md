---
name: project-materials-module-migration
description: 资料管理模块 migration 已完成，记录关键设计决策和待完成项
metadata:
  type: project
---

资料管理模块 migration 已于 2026-06-10 完成，创建了以下文件：
- `supabase/migrations/20260610120002_create_materials_table.sql`
- `docs/database/资料管理.md`

**Why:** 修复审计 S3（领取不落库）、S4（字段命名混淆）、S1（activity 存名称字符串）三个高风险问题。

**How to apply:** materials 和 material_claims 依赖 users 表（migration 0）。activity_id FK 待 20260610120001 执行后通过新 migration 补全。

## 关键设计决策

- `material_claims.(user_id, material_id)` UNIQUE 约束保证领取幂等，重复领取返回 23505，API 层映射为 CLAIM_ALREADY_CLAIMED (409)。
- `materials.downloads` 由 trigger `increment_material_downloads` 在 `material_claims.downloaded_at` 从 null→非 null 时原子递增，不由客户端直接写入。
- 领取次数（claims）不落字段，通过 `COUNT(material_claims WHERE material_id=?)` 聚合获取，避免双写不一致。
- `material_claims` 无 `updated_at` trigger，因为此表只追加不修改，`downloaded_at` 本身即最后状态变更时间。
- `MaterialClaimStatus` 不是数据库字段，由 API 层根据 need_login、need_company_info、claim_exists、is_profile_complete 四个条件推导后返回。
- `materials.activity_id` 和 `material_claims.activity_id` 暂无 FK constraint，FK 删除策略应为 ON DELETE SET NULL（活动删除不应删除资料或领取记录）。
- `material_claims.user_id ON DELETE CASCADE`：用户注销时级联删除领取记录——若业务需要保留统计数据，待产品确认后通过新 migration 改为 ON DELETE SET NULL。
- seed 中 material_claims 第 2 条 downloaded_at 不为 null 是 INSERT 直接写入，不会触发 trigger，需手动对齐 downloads 计数或接受 seed 预设值。
- RLS 策略：materials 匿名用户策略（need_login=false AND status=published）和已登录用户策略（status=published）会同时评估，Supabase 取 OR，行为符合预期。

## 待完成（见 docs/database/资料管理.md 第 11 节）

- 待 20260610120001 执行后新建 migration 补全 materials.activity_id 和 material_claims.activity_id 的 FK
- 确认用户注销政策，决定是否将 material_claims.user_id 改为 ON DELETE SET NULL
- Supabase Storage bucket 配置（materials bucket + RLS signed URL 策略）
- 资料物理删除审计日志（待审计日志模块实现后补全）
