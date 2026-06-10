---
name: project-mock-architecture
description: Where mock data lives in each project and how it is structured
metadata:
  type: project
---

admin-system 所有 mock 数据集中在 `拓客系统-管理后台/lib/mock-data.ts`，包含类型定义和数据数组。landing-page 无集中 mock 文件，mock 通过组件内 setTimeout 和硬编码逻辑实现。

**Why:** 两个项目 mock 策略不同，审计时需分别查找。

**How to apply:** 审计其他模块时，admin-system 直接读 `lib/mock-data.ts`；landing-page 需逐个读组件文件查找 setTimeout 和硬编码对象。

mock-data.ts 中的数据实体：
- `users` — 端用户列表（5条）
- `userTimeline` — 行为时间线（全局静态，无 userId）
- `reports` — 测评报告（按 user.name 关联）
- `leads` — 线索（按 user.name 关联）
- `qaRecords` — 问答记录（按 user.name 关联）
- `materialItems` — 资料
- `activities` — 活动
- `qrCodeItems` — 二维码
- `knowledgeItems` — 知识库（13字段，全部在页面使用）
- `dashboardMetrics`, `funnelData` — 看板数据（mock-data.ts）
- `trendData` — 看板折线图（内联在 app/page.tsx，未提取到 mock-data.ts）
- `roles`, `admins`, `auditLogs`, `integrationItems` — 系统设置实体（全部内联在 settings/page.tsx，未提取到 mock-data.ts）
- PlatformConfig — 无独立数据结构，以表单 value= 硬编码形式分散在 settings/page.tsx
