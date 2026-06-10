---
name: project-leads-module-audit
description: 线索管理（含预约）模块审计完成，5 个高风险项，报告在 docs/mock-audit/线索管理-mock-audit.md
metadata:
  type: project
---

线索管理（含预约）模块 mock 审计已完成，报告位于 `docs/mock-audit/线索管理-mock-audit.md`。

**Why:** MVP 阶段线索和预约数据全来自 mock，下阶段接入 Supabase 前需明确数据模型和状态机。

**How to apply:** 实现线索模块真实 API 时，参考报告第 4、6、7 节的字段分类和 API 建议；优先处理 P0/P1 迁移项。

核心发现：

- Lead 实体有 14 个持久化字段，但通过 `name` 字符串关联 User / Report / QaRecord（3 处），必须改为 `userId` 外键
- `leads.activity` 存活动名称字符串，`leads.qr` 混用 inviteCode 和 qrCodeId，关联关系模糊且易断裂
- `leads.advisor` 存顾问名称字符串，无独立 Advisor 实体或 AdminUser 外键
- 预约表单（`appointment/page.tsx`）提交仅调用 `setSubmitted(true)`，无 API 调用，数据完全不落库
- 预约与线索无联动逻辑：提交预约后 Lead.status 不会自动变为"已预约"
- 意向分构成（4 个维度）对所有线索展示相同写死数值，无法反映单条线索真实行为
- `LeadStatus` 枚举缺少"未生成"（与用户管理审计 P0 重叠），需两个模块联动修复
- 线索列表 Tab 切换、筛选控件全部无过滤逻辑，抽屉跟进表单无提交逻辑

关联记忆：[[project-user-module-audit]]
