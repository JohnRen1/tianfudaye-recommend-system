---
name: project-activity-module-audit
description: Activity management module mock audit completed; key findings about field splits between admin and landing-page, missing fields, and funnel data isolation issues
metadata:
  type: project
---

活动管理模块 mock 审计已完成，报告位于 `docs/mock-audit/活动管理-mock-audit.md`。

**Why:** MVP 阶段所有数据来自 mock，下阶段接入 Supabase 前需要明确真实数据模型，活动实体是整个漏斗的入口，与用户、二维码、资料、线索四个实体均有关联。

**How to apply:** 实现活动模块真实 API 时，参考报告第 4、6、7 节的字段分类和 API 建议；优先处理 P0 迁移项（activity_id 参数传递、time 格式统一、缺失字段补全）。

核心发现（5 个高风险项）：

- 落地页 `app/page.tsx` 无 `activity_id` 参数读取，所有扫码用户看到同一硬编码 `defaultEventData`，活动归因入口完全失效
- `activities.time` 单字符串（`2026-06-18 14:00`）与落地页 `date`（`2026年6月15日`）+`time`（`14:00 - 17:00`）双字段分裂，格式和语言均不一致
- `teacher` 字段与落地页 `speaker`+`speakerTitle` 字段分裂；`speakerTitle`、`description`、`coverImage` 三个字段在 admin-system activities 数组中完全缺失
- 活动表单关联资料 `materialOptions.value`（`risk-list`）与 `materialItems.id`（`MAT-001`）格式完全不同，无法建立关联关系
- `funnelData` 为全局共享数据（无 activityId 绑定），所有活动数据抽屉展示同一漏斗，运营数据严重失真

Activity 实体字段分类：
- 持久化字段（11 个）：`id`, `name`, `theme`, `time`, `place`, `teacher`, `status`, `creator`, `description`（缺失）, `coverImage`（缺失）, `speakerTitle`（缺失）
- 统计/计算字段（6 个，只读）：`scan`, `register`, `materialClaims`, `assessments`, `appointments`, `highIntentLeads`
- 关联字段（1 个）：`materials`（关联资料数，冗余计数）
- `aiQuestions` 字段缺失，当前用 `register * 0.61` 写死系数替代

跨实体关联问题（同用户模块）：
- `qrCodeItems.activity`、`materialItems.activity`、`users.sourceActivity`、`leads.activity` 均通过活动名称字符串关联，非 id 外键，活动改名将导致全量断裂

落地页 EventLandingDTO 与 admin Activity 实体字段对齐需求：
- `name → title`、`teacher → speaker`、`place → location`
- `time` 需拆分为 `date` + `time` 两字段
- 新增 `speakerTitle`、`description`、`coverImage`
