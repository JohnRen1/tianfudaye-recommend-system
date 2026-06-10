---
name: project-qa-module-audit
description: AI 问答记录模块 mock 审计完成；核心发现是两端枚举体系不兼容、AI 回答字段类型冲突、落地页完全无持久化
metadata:
  type: project
---

AI 问答记录模块 mock 审计已完成，报告位于 `docs/mock-audit/问答记录-mock-audit.md`。

**Why:** 落地页 AI 助手和 admin 问答记录管理是同一业务数据的两端，但当前两端类型定义完全独立，存在多处结构性冲突，必须在 API 设计前统一。

**How to apply:** 实现 `/api/ai/chat` 和 `/api/qa-records` 时，参考报告第 4.2 节的字段对照表和第 6 节的 `AiAnswerDTO` 建议；优先处理 P0 枚举统一问题。

核心发现（4 个高风险项）：

1. **枚举体系不兼容**：落地页 `RiskLevel = "medium" | "high" | "uncertain"`（英文三值），admin `RiskLevel = '低风险' | '中风险' | '高风险' | '严重风险'`（中文四值），`uncertain` 在 admin 枚举中不存在，真实接入后 AI 生成的 uncertain 记录无法存储
2. **AI 回答字段类型冲突**：`involvedRisks: string[]`（落地页）vs `risks: string`（admin）；`suggestions: string[]`（落地页）vs `suggestion: string`（admin），同一数据两种存储结构
3. **用户关联仍用字符串姓名**：`users.find(item => item.name === current.user)` 继承自用户管理审计高风险项 1，问答记录模块同样存在
4. **落地页问答完全无持久化路径**：`buildAiAnswer()` 为纯客户端关键词匹配，无任何 API 调用，admin 侧 `qaRecords` 与落地页真实问答数据完全断开

其他发现：
- 落地页 `AiAnswer` 接口有 7 个字段，admin `qaRecords` 对应字段命名风格不一致（camelCase 全称 vs 缩写）
- admin 筛选 Select 的 `value` 全部写死为 `"all"`，无 onChange，筛选完全无效
- 概览统计卡片通过 `useMemo` 遍历全量数据计算，真实接入后需改为后端聚合
- 落地页高风险回答的"预约顾问"按钮登录成功后无跳转逻辑
- 知识库 Badge 声称"基于财税知识库"但 `buildAiAnswer()` 实际是关键词匹配，与 `knowledgeItems` 完全无关
