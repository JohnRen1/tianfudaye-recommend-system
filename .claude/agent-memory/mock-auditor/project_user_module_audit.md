---
name: project-user-module-audit
description: User management module mock audit completed; key findings about entity relationships, missing fields, and high-risk inconsistencies
metadata:
  type: project
---

用户管理模块 mock 审计已完成，报告位于 `docs/mock-audit/用户管理-mock-audit.md`。

**Why:** MVP 阶段所有数据来自 mock，下阶段接入 Supabase 前需要明确真实数据模型。

**How to apply:** 实现用户模块真实 API 时，参考报告第 4、6、7 节的字段分类和 API 建议；优先处理 P0/P1 迁移项。

核心发现：

- 端用户实体（User）有 14 个需持久化字段，落地页注册表单只收集 phone+code，企业信息补录步骤缺失
- `leadStatus` 枚举定义了 7 个值但实际数据用了"未生成"这个未定义值，统计逻辑直接依赖该值
- 报告、线索、问答均通过 `user.name` 字符串关联用户，未使用 `user.id`，高风险
- 管理后台 token 为固定字符串 `mock-admin-token`，认证守卫形同虚设
- `userTimeline` 无 userId 字段，所有用户详情页显示同一条时间线
- 资料领取记录、问答记录在详情页均为全量展示，未按用户过滤
