---
name: project-materials-module-audit
description: Materials management module mock audit completed; key findings about two distinct entities (Material vs MaterialClaim), 5 high-risk field conflicts, and missing claim record entity
metadata:
  type: project
---

资料管理模块 mock 审计已完成，报告位于 `docs/mock-audit/资料管理-mock-audit.md`。

**Why:** 资料管理横跨两个系统，存在字段命名冲突、同名异义、枚举不一致和完全缺失的领取记录实体，是下阶段接入 Supabase 的高风险模块。

**How to apply:** 实现资料模块真实 API 时，优先解决 P0 项（字段命名统一、status 语义分离、创建 MaterialClaim 表）；参考报告第 4 节区分 Material 和 MaterialClaim 两个不同实体。

核心发现：

- `materialItems` 是资料目录，`MaterialClaim` 领取记录实体在整个 codebase 中不存在，是完全缺失的模型
- `needCompanyInfo` vs `needsCompanyInfo`：同一字段 admin 无 s，landing-page 有 s，高风险命名冲突
- `status` 同名异义：admin 中是上架状态（已上架/草稿/已下架），landing-page 中是用户领取状态（available/claimed/needs_company_info）
- 资料类型枚举两端完全不同：admin 用中文 4 类，landing-page 用英文 key + 细分 type，无法直接映射
- `material.activity` 存名称字符串而非活动 id 外键，与用户管理模块 sourceActivity 问题同类
- 用户详情页"资料领取记录"用 `materialItems.slice(0,3)` 误充，`createdAt`（资料创建时间）被误作领取时间
- `event-landing-page.tsx` 内有独立的第二套资料 Mock（字段 title/type/size/icon/downloaded），与主 mock 完全孤立
- 领取门槛（needLogin / needCompanyInfo）在落地页实际未拦截，`handleClaim` 对 needs_company_info 状态资料可直接领取
- 领取数据 Drawer 趋势数组和用户画像文字对所有资料完全写死，接入后必须替换为真实统计 API
