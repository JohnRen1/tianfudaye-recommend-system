---
name: project-assessment-module-audit
description: Assessment report module mock audit completed; key findings about quiz hardcoding, client-side scoring, missing submit API, and module mapping gaps
metadata:
  type: project
---

测评报告模块 mock 审计已完成，报告位于 `docs/mock-audit/测评报告-mock-audit.md`。

**Why:** 测评是整个业务漏斗的核心转化环节（答题→报告→预约顾问→线索），当前数据流完全断裂，服务端无任何测评数据。

**How to apply:** 实现测评模块真实 API 时，参考报告第 4、6、10 节；P0 优先级是将评分逻辑移至服务端并接通提交接口。

核心发现：

- 题库（15道题）完全硬编码在 `components/mobile/risk-assessment-quiz-page.tsx:27–43`，无后端存储
- 评分逻辑（option.score 权重累加）在客户端 useMemo 中完成，score 通过 URL query param 传递给报告页，服务端完全不参与
- 报告提交无 API：`window.setTimeout(1200)` 模拟后直接跳转，管理后台无法看到任何落地页测评记录
- 报告页"解锁"和"保存"均为纯前端 state，刷新即丢失，admin 侧 viewed 字段永远不会被触发
- 报告模块（5个：发票/公转私/个税社保/成本费用/税务稽查）与题库模块（8个）命名和数量均不对应，无自动映射逻辑
- `reports.answers` 存自然语言摘要（string[]），答题 state 存选项索引（Record<number, number[]>），格式不兼容
- `reports` 通过 user.name 字符串关联用户（同用户管理审计高风险项 #1）
- 报告页模块分数（76/82/58等）为硬编码常量，与用户实际答案无关

4个高风险项：
1. 评分全在客户端，提交无 API，服务端无数据
2. reports 通过 user.name 关联用户
3. answers 字段含义双重（摘要 vs 索引）
4. 题库模块与报告模块映射断裂
