---
name: project-aux-modules-audit
description: 辅助模块（知识库/看板/设置/客服页）mock 审计完成，11 个冲突项，报告在 docs/mock-audit/辅助模块（知识库-看板-设置）-mock-audit.md
metadata:
  type: project
---

辅助模块审计已完成，报告位于 `docs/mock-audit/辅助模块（知识库-看板-设置）-mock-audit.md`。

**Why:** 三个管理后台辅助模块（知识库、数据看板、系统设置）和落地页客服页均依赖 mock 数据，下阶段接入 Supabase 前需明确真实数据模型和接口。

**How to apply:** 实现这些模块的真实 API 时，参考报告第 4、6、7 节；优先处理 P0 项（留言提交/客服电话/通知开关/保存按钮）。

核心发现：

- 系统设置 settings/page.tsx 中 roles/admins/auditLogs/integrationItems 均为组件内硬编码数组，未提取到 mock-data.ts
- 看板 trendData 内联在 page.tsx，与 mock-data.ts 中的 dashboardMetrics 指标部分重叠，接入时需合并为单一 API
- 客服电话在落地页（400-888-6688）与后台配置（400-888-2026）硬编码不一致，P0 冲突
- 落地页留言表单提交仅 setSubmitted(true)，无任何网络请求，用户数据全部丢失
- 通知设置 9 个 Switch 全部使用 defaultValue（非受控），所有通知偏好无法持久化
- 知识库 FAQ 类型条目与落地页客服 FAQ 完全割裂，应统一从知识库动态读取
- AdminAccount.role / AuditLog.user / KnowledgeItem.uploader 均为姓名字符串，无 ID 外键，与用户管理模块同类问题一致
