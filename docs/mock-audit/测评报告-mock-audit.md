# 测评报告（风险测评）模块 Mock 数据审计报告

**审计日期**：2026-06-10
**审计员**：mock-auditor agent
**项目阶段**：MVP 原型阶段，无真实数据库和身份认证
**关联报告**：[用户管理-mock-audit.md](./用户管理-mock-audit.md)

---

## 1. 审计范围

| 系统 | 文件路径 | 页面 / 用途 |
|------|----------|-------------|
| admin-system | `拓客系统-管理后台/app/assessment-reports/page.tsx` | 测评报告管理列表 + 详情抽屉 + 答案抽屉 |
| admin-system | `拓客系统-管理后台/lib/mock-data.ts` | `reports` 数组、`RiskLevel` 类型（第 1、59–63 行） |
| admin-system | `拓客系统-管理后台/lib/ui.ts` | `riskTheme()` 工具函数（第 3–7 行） |
| landing-page | `拓客系统-落地页/app/risk-assessment/page.tsx` | 测评入口（仅壳，委托组件） |
| landing-page | `拓客系统-落地页/components/mobile/risk-assessment-start-page.tsx` | 测评开始页（维度介绍） |
| landing-page | `拓客系统-落地页/app/risk-assessment/quiz/page.tsx` | 答题页（仅壳，委托组件） |
| landing-page | `拓客系统-落地页/components/mobile/risk-assessment-quiz-page.tsx` | 答题核心组件（题库、评分、状态机） |
| landing-page | `拓客系统-落地页/app/risk-assessment/report/page.tsx` | 报告展示页（含解锁流程） |

---

## 2. Mock 来源清单

| 来源类型 | 文件 | 具体内容 | 证据位置 |
|----------|------|----------|----------|
| 硬编码对象数组 | `lib/mock-data.ts` | `reports` 数组，3 条测评报告记录 | `mock-data.ts:59–63` |
| 类型枚举（union） | `lib/mock-data.ts` | `RiskLevel = '低风险' \| '中风险' \| '高风险' \| '严重风险'` | `mock-data.ts:1` |
| 硬编码题库 | `components/mobile/risk-assessment-quiz-page.tsx` | `questions` 数组，15 道题，含 id/module/type/title/description/options | `risk-assessment-quiz-page.tsx:27–43` |
| 硬编码维度列表（展示用） | `components/mobile/risk-assessment-start-page.tsx` | `dimensions` 数组，8 个测评维度（含标题和图标） | `risk-assessment-start-page.tsx:35–44` |
| 硬编码价值说明（展示用） | `components/mobile/risk-assessment-start-page.tsx` | `valueItems` 数组，5 条测评价值说明文字 | `risk-assessment-start-page.tsx:27–33` |
| 硬编码报告模块数据 | `app/risk-assessment/report/page.tsx` | `modules` 数组，5 个风险模块（含 name/score/desc/advice） | `report/page.tsx:24–55` |
| 前端计算（评分逻辑） | `components/mobile/risk-assessment-quiz-page.tsx` | `totalScore` 通过 `useMemo` 累加每题所选选项的 `option.score` 值计算得出 | `risk-assessment-quiz-page.tsx:57–60` |
| 前端计算（等级映射） | `app/risk-assessment/report/page.tsx` | `getRiskLevel(score)` 纯函数：≥85→严重风险，≥65→高风险，≥35→中风险，其余→低风险 | `report/page.tsx:57–62` |
| URL 参数传递分数 | `app/risk-assessment/report/page.tsx` | `searchParams.get("score")` 读取 URL 中的 score 参数，整个报告页从 URL 获取分数，无后端 | `report/page.tsx:107–111` |
| `window.setTimeout` 模拟生成 | `components/mobile/risk-assessment-quiz-page.tsx` | `await new Promise(resolve => window.setTimeout(resolve, 1200))` 模拟报告生成延迟 | `risk-assessment-quiz-page.tsx:85` |
| 仅前端状态（解锁） | `app/risk-assessment/report/page.tsx` | `isUnlocked` state，登录弹窗 `onSuccess` 后设为 true，无后端确认 | `report/page.tsx:104, 132–134` |
| 仅前端状态（保存） | `app/risk-assessment/report/page.tsx` | `isSaved` state，点击"保存到我的报告"后设为 true，无 API 调用 | `report/page.tsx:105, 308–311` |
| 写死分页总数 | `app/assessment-reports/page.tsx` | `total: reports.length`（固定为 3） | `assessment-reports/page.tsx:104` |
| 写死线索生成反馈 | `app/assessment-reports/page.tsx` | `MessagePlugin.success('线索已生成')` 直接弹 toast，无 API | `assessment-reports/page.tsx:103` |

---

## 3. 页面数据需求

### 3.1 管理后台测评报告列表页（`assessment-reports/page.tsx`）

**统计概览卡片（4 张）**

| 指标 | 计算逻辑 | 字段依赖 |
|------|----------|----------|
| 累计完成测评 | `reports.length` | 无（count） |
| 高风险报告数 | `risk === '高风险' \|\| risk === '严重风险'` | `risk: RiskLevel` |
| 已查看完整报告数 | `viewed === true` | `viewed: boolean` |
| 已预约顾问数 | `booked === true` | `booked: boolean` |

**待办提示卡片（4 条动态计算）**

| 提示内容 | 过滤条件 | 字段依赖 |
|----------|----------|----------|
| 严重风险未成交 | `risk === '严重风险' && leadStatus !== '已成交'` | `risk`, `leadStatus` |
| 高风险未预约 | `risk === '高风险' && !booked` | `risk`, `booked` |
| 已看未预约 | `viewed && !booked` | `viewed`, `booked` |
| 未查看报告 | `!viewed` | `viewed` |

**筛选条件**

| 筛选项 | 控件 | 字段依赖 | 当前状态 |
|--------|------|----------|----------|
| 用户搜索 | Input | `user` | 无过滤逻辑 |
| 企业名称搜索 | Input | `company` | 无过滤逻辑 |
| 风险等级 | Select（全部/严重/高/中） | `risk` | 无过滤逻辑 |
| 是否查看完整报告 | Select | `viewed` | 无过滤逻辑 |
| 是否预约顾问 | Select | `booked` | 无过滤逻辑 |
| 测评时间区间 | DateRangePicker | `time` | 无过滤逻辑 |

**报告列表表格（9 列）**

| 列 | 字段 | 字段类型 | 证据位置 |
|----|------|----------|----------|
| 用户 | `user` | `string` | `assessment-reports/page.tsx:95` |
| 企业名称 | `company` | `string` | `assessment-reports/page.tsx:96` |
| 风险分数 | `score` | `number` | `assessment-reports/page.tsx:97` |
| 风险等级 | `risk` | `RiskLevel` | `assessment-reports/page.tsx:98` |
| 主要风险模块 | `modules` | `string[]` | `assessment-reports/page.tsx:99` |
| 是否查看完整报告 | `viewed` | `boolean` | `assessment-reports/page.tsx:100` |
| 是否预约顾问 | `booked` | `boolean` | `assessment-reports/page.tsx:101` |
| 测评时间 | `time` | `string` | `assessment-reports/page.tsx:102` |
| 操作列 | — | — | `assessment-reports/page.tsx:103` |

**行操作**：查看报告（打开详情抽屉）、查看答案（打开答案抽屉）、生成线索（toast 占位）。

### 3.2 报告详情抽屉（`assessment-reports/page.tsx` 内 Drawer）

| 字段 | 用途 | 字段类型 | 证据位置 |
|------|------|----------|----------|
| `risk` | 高/严重风险预警横幅条件判断 | `RiskLevel` | `assessment-reports/page.tsx:108` |
| `score` | 英雄区风险分展示 | `number` | `assessment-reports/page.tsx:109` |
| `company` | 英雄区企业名称 | `string` | `assessment-reports/page.tsx:109` |
| `user` | 英雄区用户姓名 | `string` | `assessment-reports/page.tsx:109` |
| `time` | 英雄区测评时间 | `string` | `assessment-reports/page.tsx:109` |
| `leadStatus` | 英雄区线索状态 | `string` | `assessment-reports/page.tsx:109` |
| `modules` | 风险模块标签列表（×2：英雄区 + 独立卡片） | `string[]` | `assessment-reports/page.tsx:109, 112–114` |
| `suggestions` | 整改与顾问解读建议列表 | `string[]` | `assessment-reports/page.tsx:115` |
| `advisor` | 分配顾问姓名 | `string` | `assessment-reports/page.tsx:116` |
| — | 跨实体关联：`currentUser.phone` | 通过 `users.find(u => u.name === current.user)` 拉取 | `assessment-reports/page.tsx:61, 116` |
| — | 跨实体关联：`currentUser.industry` | 同上 | `assessment-reports/page.tsx:116` |

### 3.3 答案明细抽屉（`assessment-reports/page.tsx` 内 Drawer）

| 字段 | 用途 | 字段类型 | 证据位置 |
|------|------|----------|----------|
| `user` | 抽屉标题 `${user} 的测评答案` | `string` | `assessment-reports/page.tsx:120` |
| `answers` | 答案列表，按索引渲染 Q1/Q2/... | `string[]` | `assessment-reports/page.tsx:120` |

### 3.4 落地页测评开始页（`risk-assessment-start-page.tsx`）

该页仅展示静态文案，无动态数据依赖。`dimensions` 和 `valueItems` 均为产品文案，后续可改为 CMS 内容，但当前不涉及用户数据或持久化需求。

**页面数据需求**：无动态字段，全部为静态展示内容。

### 3.5 落地页答题页（`risk-assessment-quiz-page.tsx`）

| 数据项 | 来源 | 字段依赖 | 是否需要持久化 |
|--------|------|----------|----------------|
| 题库（15 道题） | 硬编码 `questions` 数组 | `id`, `module`, `type`, `title`, `description`, `options[]` | 需要（题库实体） |
| 每题选项的评分权重 | `option.score` 硬编码 | `options[].score` | 需要（随题库持久化） |
| 用户当前答案 | `answers: Record<number, number[]>` state | 题目 id → 所选选项索引数组 | 需要（答题提交时） |
| 综合风险分 | `totalScore` useMemo 实时计算 | 计算字段 | 需要（提交报告时快照保存） |
| 答题进度 | `currentIndex` state | 仅前端状态 | 不需要 |
| 提交加载状态 | `isGenerating` state | 仅前端状态 | 不需要 |
| 错误提示文字 | `error` state | 仅前端状态 | 不需要 |

### 3.6 落地页报告展示页（`report/page.tsx`）

| 数据项 | 来源 | 是否需要持久化 |
|--------|------|----------------|
| `score` | URL query param `?score=` | 需要（报告实体的持久化字段） |
| `level`（风险等级） | `getRiskLevel(score)` 纯函数计算 | 可以计算字段，也可冗余存储提高查询效率 |
| `modules` 数组（5 个模块的 name/score/desc/advice） | 硬编码常量 | 需要（模块评分需要从答案计算，desc/advice 可配置化） |
| `isUnlocked` | 登录弹窗回调后的本地 state | 需要（后端记录用户是否已解锁完整报告，即 `viewed` 字段） |
| `isSaved` | 按钮点击后的本地 state | 需要（对应后端的"保存报告"操作，生成 user-report 关联记录） |

---

## 4. 业务实体和字段

### 4.1 测评报告（AssessmentReport）

#### 数据库实体（需持久化）

| 字段 | 类型 | 分类 | 来源 / 证据位置 |
|------|------|------|----------------|
| `id` | `string`（如 `R001`，建议改 uuid） | 持久化（主键） | `mock-data.ts:60` |
| `userId` | `uuid`（外键 → users.id） | 持久化（关联字段） | **当前缺失**，Mock 用 `user: string`（姓名）关联，高风险 |
| `score` | `number`（整数，0–100） | 持久化（计算快照） | `mock-data.ts:60` |
| `risk` | `RiskLevel`（枚举） | 持久化（计算快照） | `mock-data.ts:60`，类型定义在 `mock-data.ts:1` |
| `modules` | `string[]` | 持久化 | `mock-data.ts:60` |
| `viewed` | `boolean` | 持久化 | `mock-data.ts:60` |
| `booked` | `boolean` | 持久化 | `mock-data.ts:60` |
| `time` | `string` / `timestamp` | 持久化（系统自动，完成测评时间） | `mock-data.ts:60` |
| `advisor` | `string`（顾问姓名，建议改外键） | 持久化（关联字段） | `mock-data.ts:60` |
| `leadStatus` | `string`（枚举，LeadStatus） | 持久化 / 冗余展示字段 | `mock-data.ts:60` |
| `answers` | `string[]` | 持久化 | `mock-data.ts:60`（当前 Mock 存的是答案文字摘要，非原始选项索引） |
| `suggestions` | `string[]` | 持久化 | `mock-data.ts:60` |
| `company` | `string` | 持久化 / 冗余展示字段（也在 users 表中） | `mock-data.ts:60` |
| `user` | `string`（姓名，当前关联键） | **应替换为 `userId` 外键** | `mock-data.ts:60` |

**Mock 中存在但页面未使用的字段**：`reports` 数组中所有字段均在 `assessment-reports/page.tsx` 的列表或抽屉中被使用，无冗余字段。

#### 列表 DTO（`GET /api/reports`，用于列表页表格）

`id`, `userId`, `user`（展示用姓名），`company`, `score`, `risk`, `modules`, `viewed`, `booked`, `time`

#### 详情 DTO（`GET /api/reports/:id`，用于详情抽屉）

列表 DTO 全部字段 + `suggestions`, `answers`, `advisor`, `leadStatus`
外加跨实体补充：`userPhone`（从 users 表 join），`userIndustry`（从 users 表 join）

#### 创建 DTO（答题提交时由落地页创建报告）

`userId`, `score`, `risk`, `modules[]`, `answers[]`（原始选项索引或文字摘要，见第 11 节不确定项 #3）

---

### 4.2 测评题库（AssessmentQuestion）

题库当前完全硬编码在落地页组件内，无任何后端存储或 API，需作为独立实体管理。

#### 数据库实体（需持久化）

| 字段 | 类型 | 分类 | 来源 / 证据位置 |
|------|------|------|----------------|
| `id` | `number`（1–15，建议改 uuid） | 持久化（主键） | `risk-assessment-quiz-page.tsx:28–43` |
| `module` | `string`（模块名称） | 持久化 | 同上（8 个模块，见 §4.4） |
| `type` | `"single" \| "multiple" \| "range"` | 持久化 | 同上，TypeScript 类型定义在 `quiz-page.tsx:11` |
| `title` | `string` | 持久化 | 同上 |
| `description` | `string` | 持久化（题目补充说明） | 同上 |
| `sortOrder` | `number` | 持久化（题目顺序，当前隐含在数组下标） | 无，当前靠数组顺序 |
| `isActive` | `boolean` | 持久化（是否启用，当前无此字段） | 无 |

#### 题目选项子实体（QuestionOption）

| 字段 | 类型 | 分类 | 来源 / 证据位置 |
|------|------|------|----------------|
| `questionId` | 外键 | 持久化（关联字段） | — |
| `label` | `string` | 持久化（选项文字） | `risk-assessment-quiz-page.tsx:28–43` |
| `score` | `number` | 持久化（评分权重） | 同上，TypeScript 类型定义在 `quiz-page.tsx:17` |
| `sortOrder` | `number` | 持久化（选项顺序，当前靠数组下标） | 无 |

#### 当前 15 道题的模块分布

| 模块 | 题目 id | 题目数 |
|------|---------|--------|
| 企业基础信息 | 1, 2 | 2 |
| 发票合规风险 | 3, 4 | 2 |
| 公转私风险 | 5, 6 | 2 |
| 所得税风险 | 7, 8 | 2 |
| 增值税风险 | 9, 10 | 2 |
| 个税社保风险 | 11, 12 | 2 |
| 成本费用风险 | 13 | 1 |
| 税务稽查应对 | 14, 15 | 2 |

---

### 4.3 报告风险模块评分（ReportModule）

报告页的 `modules` 数组当前为常量，与 `reports.modules`（string[]）存在结构不一致（详见第 7 节）。

#### 数据库实体（需持久化，或作为 `AssessmentReport` 的 JSON 子字段）

| 字段 | 类型 | 分类 | 来源 / 证据位置 |
|------|------|------|----------------|
| `reportId` | 外键 | 持久化（关联字段） | — |
| `name` | `string`（模块名称） | 持久化 | `report/page.tsx:26, 31, 36, 41, 46` |
| `score` | `number` | 持久化（模块级分数） | `report/page.tsx:27, 32, 37, 42, 47` |
| `desc` | `string`（风险说明） | 持久化 / 可配置 | `report/page.tsx:28, 33, 38, 43, 48` |
| `advice` | `string`（初步建议） | 持久化 / 可配置 | `report/page.tsx:29, 34, 39, 44, 49` |

当前报告页的 5 个模块（发票合规风险、公转私风险、个税社保风险、成本费用风险、税务稽查应对风险）均为硬编码，**与答题题库的模块分类不完全一致**（见第 7 节冲突项 #2）。

---

### 4.4 题库模块（AssessmentModule）

| 模块名（题库中） | 报告页对应模块 | 是否一致 |
|----------------|--------------|----------|
| 企业基础信息 | — | 仅作为答题分类，不直接出现在报告模块 |
| 发票合规风险 | 发票合规风险 | 一致 |
| 公转私风险 | 公转私风险 | 一致 |
| 所得税风险 | 成本费用风险（部分重叠） | 不一致 |
| 增值税风险 | — | 报告页无独立增值税风险模块 |
| 个税社保风险 | 个税社保风险 | 一致 |
| 成本费用风险 | 成本费用风险 | 一致 |
| 税务稽查应对 | 税务稽查应对风险 | 名称略有差异 |

---

### 4.5 RiskLevel 枚举（共用）

| 枚举值 | admin-system 定义 | landing-page 定义 | 是否一致 |
|--------|-------------------|-------------------|----------|
| `低风险` | `mock-data.ts:1` | `report/page.tsx:22`（本地 type） | 一致 |
| `中风险` | `mock-data.ts:1` | `report/page.tsx:22` | 一致 |
| `高风险` | `mock-data.ts:1` | `report/page.tsx:22` | 一致 |
| `严重风险` | `mock-data.ts:1` | `report/page.tsx:22` | 一致 |

两个系统对 `RiskLevel` 分别定义了同名同值的本地类型，未共享，需要在接入阶段统一到共用类型包或 API 契约中。

---

## 5. 页面操作

### 管理后台测评报告页

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 搜索 / 筛选报告 | 查询按钮 | 无过滤逻辑（控件为非受控或无绑定） | `GET /api/reports?user=&company=&risk=&viewed=&booked=&dateFrom=&dateTo=&page=&pageSize=` |
| 重置筛选 | 重置按钮 | 无实现 | — |
| 查看报告详情 | "查看报告"按钮 | 打开 Drawer，展示 `current` 数据 | `GET /api/reports/:id`（含 user join 字段） |
| 查看测评答案 | 更多菜单"查看答案" | 打开 Drawer，展示 `current.answers` | 同上，或 `GET /api/reports/:id/answers` |
| 生成线索 | 更多菜单"生成线索" | `MessagePlugin.success('线索已生成')` 占位 | `POST /api/leads`（来源：report） |
| 批量生成线索 | 列表头部按钮 | 无实现（占位） | `POST /api/leads/batch` |
| 导出报告 | 列表头部按钮 | 无实现（占位） | `GET /api/reports/export` |

### 落地页测评流程

| 操作 | 页面 | 当前实现 | 需要的 API |
|------|------|----------|------------|
| 开始测评 | 测评开始页 | 跳转 `/risk-assessment/quiz` | — |
| 选择答案（单选） | 答题页 | 替换 `answers[questionId]` 为 `[optionIndex]` | — |
| 选择答案（多选） | 答题页 | toggle `answers[questionId]` 中的 optionIndex | — |
| 上一题 / 下一题 | 答题页 | 更新 `currentIndex` | — |
| 提交并生成报告 | 答题页（最后一题） | `setTimeout(1200)` 模拟，跳转 `?score=${totalScore}` | `POST /api/assessment/submit`（提交答案，创建报告，返回 reportId） |
| 查看报告 | 报告展示页 | 从 URL `?score=` 读取分数，完全本地计算 | `GET /api/reports/:id`（已登录时）或结合提交接口返回的 reportId |
| 解锁完整报告 | 报告展示页 | 弹出登录弹窗，登录成功后 `setIsUnlocked(true)`（纯前端状态） | `POST /api/reports/:id/unlock`（记录 viewed=true） |
| 保存到我的报告 | 报告展示页 | `setIsSaved(true)` 纯前端状态 | `POST /api/reports/:id/save`（或在提交时已关联用户） |
| 预约顾问解读 | 报告展示页 | `router.push('/appointment')` | — |

---

## 6. 建议 API

### 测评题库（landing-page + admin-system）

| 方法 | 路径 | 请求/响应 | 备注 |
|------|------|-----------|------|
| `GET` | `/api/assessment/questions` | 响应：`QuestionDTO[]`（含 options，不含 score 权重，防刷分） | 公开接口，无需认证 |
| `GET` | `/api/admin/assessment/questions` | 响应：`QuestionDTO[]`（含 score，管理员查看） | 需管理员 token |
| `PUT` | `/api/admin/assessment/questions/:id` | 请求：题目字段更新，响应：`QuestionDTO` | 管理员编辑题库 |

> 注意：`option.score` 不应暴露给落地页前端，否则用户可以逆向计算高分路径。评分应在服务端完成。

### 测评提交与报告（landing-page）

| 方法 | 路径 | 请求体 | 响应 | 备注 |
|------|------|--------|------|------|
| `POST` | `/api/assessment/submit` | `{ userId?: string, answers: { questionId: number, selectedIndexes: number[] }[] }` | `{ reportId: string, score: number, risk: RiskLevel, modules: ReportModuleDTO[] }` | 服务端计算分数和模块评分，创建报告记录 |
| `GET` | `/api/assessment/report/:id` | — | `AssessmentReportDTO` | 需登录（或凭 reportId token） |
| `POST` | `/api/assessment/report/:id/unlock` | — | `{ viewed: true }` | 需登录，记录用户已解锁完整报告 |
| `POST` | `/api/assessment/report/:id/save` | — | `{ saved: true }` | 需登录，建立用户-报告收藏关联 |

### 测评报告管理（admin-system）

| 方法 | 路径 | 参数 / 请求体 | 响应 | 备注 |
|------|------|--------------|------|------|
| `GET` | `/api/admin/reports` | `user`, `company`, `risk`, `viewed`, `booked`, `dateFrom`, `dateTo`, `page`, `pageSize` | `{ items: ReportListDTO[], total: number }` | 需管理员 token |
| `GET` | `/api/admin/reports/:id` | — | `ReportDetailDTO`（含 user join 字段：phone, industry） | 需管理员 token |
| `GET` | `/api/admin/reports/:id/answers` | — | `{ answers: string[] }` | 需管理员 token |
| `POST` | `/api/admin/reports/:id/generate-lead` | — | `LeadDTO` | 从报告生成线索，需管理员 token |
| `POST` | `/api/admin/reports/batch-generate-leads` | `{ reportIds: string[] }` | `{ created: number }` | 批量生成线索 |
| `GET` | `/api/admin/reports/export` | 同筛选参数 | CSV / XLSX 文件流 | 需管理员 token |

---

## 7. 字段和类型冲突

| # | 冲突描述 | 文件 A | 文件 B | 字段 | 风险等级 |
|---|----------|--------|--------|------|----------|
| 1 | **reports 通过 user 姓名关联用户**：`assessment-reports/page.tsx` 用 `users.find(u => u.name === current.user)` 拉取用户的 phone 和 industry，姓名重复时数据污染，完全无法使用 userId 做隔离 | `mock-data.ts:60` | `assessment-reports/page.tsx:61` | `report.user`（string）vs `user.id` | 高风险 |
| 2 | **题库模块与报告模块分类不一致**：题库有 8 个模块（含企业基础信息、所得税风险、增值税风险），报告页仅展示 5 个模块（无增值税风险、所得税风险改为成本费用风险），模块名称和数量均不对应，无法从答案自动推导出报告的模块评分 | `risk-assessment-quiz-page.tsx:27–43` | `report/page.tsx:24–55` | `module` 字段 / 模块命名 | 高风险 |
| 3 | **answers 字段含义模糊**：`reports.answers` 当前存的是自然语言文字摘要（如"存在大额公转私"），而答题页的 `answers` state 存的是选项索引数组 `Record<number, number[]>`，两者格式完全不同，无法互转 | `mock-data.ts:60` | `risk-assessment-quiz-page.tsx:48` | `answers` | 高风险 |
| 4 | **RiskLevel 类型在两系统重复定义**：admin-system 在 `mock-data.ts:1` 定义，landing-page 在 `report/page.tsx:22` 本地重复定义，值相同但类型不共享，接入 API 后类型校验需要额外处理 | `mock-data.ts:1` | `report/page.tsx:22` | `RiskLevel` | 中风险 |
| 5 | **getRiskLevel 的分数阈值与 admin 理解可能存在偏差**：落地页 `getRiskLevel` 定义 ≥85→严重风险，≥65→高风险，≥35→中风险；但 mock `reports` 中 score=86 为"高风险"、score=91 为"严重风险"、score=64 为"中风险"，与函数阈值基本符合，但 score=64 对应函数结果应为"中风险"（65 阈值，64<65），mock 数据同样标记"中风险"，数值临界处有歧义 | `report/page.tsx:57–62` | `mock-data.ts:60–63` | `score` → `risk` 映射 | 中风险 |
| 6 | **advisor 字段存的是姓名字符串而非 id 关联**：`reports.advisor` 当前存"周顾问"/"刘顾问"/"未分配"，未来顾问管理如引入 adminUser 表，需要改为外键 | `mock-data.ts:60–63` | — | `advisor` | 中风险 |
| 7 | **reports.modules 与报告页 modules 的 score 字段缺失**：admin 侧 `reports.modules` 仅存模块名称 `string[]`，但落地页报告页的 `modules` 数组含 `score/desc/advice` 字段。admin 详情抽屉只渲染 Tag 标签（仅名称），而落地页渲染完整模块卡片。两侧对模块数据的需求深度不同 | `mock-data.ts:60` | `report/page.tsx:24–55` | `modules` 结构 | 中风险 |
| 8 | **company 字段在 reports 和 users 中重复存储**：`reports.company` 与 `users.company` 内容相同，若用户更新企业信息，报告历史快照是否需要保留旧值未明确 | `mock-data.ts:36–41` | `mock-data.ts:59–63` | `company` | 低风险 |
| 9 | **leadStatus 冗余存在 reports 中**：`reports.leadStatus` 与 `users.leadStatus`、`leads.status` 含义相关但来源不同，更新时一致性维护成本高 | `mock-data.ts:60–63` | `mock-data.ts:65–69` | `leadStatus` | 低风险 |

---

## 8. 页面状态缺口

| 缺口描述 | 页面 | 当前状态 | 影响 |
|----------|------|----------|------|
| **评分全在客户端完成，后端无记录**：答题结束后直接跳转 `?score=${totalScore}`，无 API 调用，无报告 id，服务端完全不知道用户做过测评 | 落地页答题页 | `window.setTimeout(resolve, 1200)` 模拟生成 + 路由跳转 | 管理后台无法看到该用户的测评记录，业务漏斗中断 |
| **报告解锁状态仅前端**：`isUnlocked` 设为 true 后仅存在于当前页面内存，刷新即丢失，admin 侧 `viewed` 字段也无法被更新 | 落地页报告展示页 | `setIsUnlocked(true)` 纯 state | admin 侧"查看完整报告"统计数据永远不会被真实触发 |
| **报告保存无后端**：`isSaved` 点击后仅本地 state，无任何 API，用户的"我的报告"功能无法实现 | 落地页报告展示页 | `setIsSaved(true)` 纯 state | "我的报告"入口将始终为空 |
| **筛选条件全部无效**：报告列表页 6 个筛选项（用户/企业/风险/查看/预约/时间）无任何 onChange 绑定和过滤逻辑 | admin 测评报告列表页 | 控件渲染但无逻辑 | 运营无法有效筛选和处理高风险报告 |
| **"生成线索"仅 toast 反馈，无实际操作**：点击生成线索后仅显示 `MessagePlugin.success('线索已生成')`，不调用 API，不写入 leads 数据 | admin 测评报告列表页 | toast 占位 | 线索管理模块不会增加新线索，业务闭环断裂 |
| **报告详情抽屉的"整改建议"硬编码了一条兜底文字**：`<li>顾问解读建议：先解释风险暴露原因，再按紧急程度制定整改计划。</li>` 写死在模板中，非来自数据 | admin 测评报告详情抽屉 | 硬编码字符串 | 对所有报告展示相同的兜底建议，影响个性化 |
| **答题页无保存草稿能力**：用户答到一半离开后，下次回来需要从头开始 | 落地页答题页 | `answers` state 在组件卸载时丢失 | 答题体验差，完成率可能下降 |
| **报告模块分数与答题结果无计算关联**：报告页 `modules` 数组中的 `score`（如 76/82/58）是硬编码常量，与用户实际答案无关 | 落地页报告展示页 | 硬编码常量 | 所有用户看到完全相同的模块评分，报告失去个性化价值 |

---

## 9. 共用模型

以下实体在两个系统中均有涉及，需要统一 API 契约：

| 实体 | landing-page 视角 | admin-system 视角 | 需共享的字段 |
|------|-------------------|-------------------|-------------|
| AssessmentReport | 用户提交答案后创建，查看自己的报告，触发解锁/保存 | 运营查看所有用户的报告，统计风险分布，触发线索生成 | `id`, `score`, `risk`, `modules`, `viewed`, `booked`, `time` |
| AssessmentQuestion | 渲染题目供用户作答（选项 score 不可见） | 管理员维护题库（含 score 权重） | `id`, `module`, `type`, `title`, `description`, `options[].label`, `options[].sortOrder` |
| RiskLevel | 本地 type 定义，用于报告展示样式 | 从 `mock-data.ts` 导出，用于表格 Tag 颜色 | 枚举值完全一致，需提取为共用类型 |
| User（端用户） | 测评报告的创建者，与报告关联 | 报告详情抽屉中展示 phone/industry（join 查询） | `id`, `name`, `phone`, `company`, `industry` |

**建议**：`RiskLevel` 和 `QuestionType` 枚举提取到共用包（monorepo shared 目录或 API 契约文件）中，避免两端维护各自副本。

---

## 10. 推荐迁移顺序

| 优先级 | 模块 | 原因 |
|--------|------|------|
| P0 | **服务端计算评分**：将 `option.score` 权重和评分逻辑移至后端，落地页只提交选项索引，服务端返回 score 和 risk | 当前评分完全在客户端，安全性为零，数据无法入库 |
| P0 | **测评提交 API**（`POST /api/assessment/submit`）| 答题结束后写入报告记录，是整个模块数据流的起点，所有下游（admin 列表、线索生成、漏斗统计）均依赖此接口 |
| P0 | **统一 reports.userId 外键**（替换 `user` 姓名字符串关联） | 与用户管理审计高风险项 #1 相同问题，必须在接入阶段修复，否则所有关联查询不可靠 |
| P1 | **题库接口**（`GET /api/assessment/questions`） | 将 15 道题移出硬编码，支持后续题库管理和 A/B 测试 |
| P1 | **报告模块评分计算**：设计答题模块→报告模块的映射关系，使报告中每个模块的分数来自对应模块的题目答案 | 当前模块分数为硬编码常量，报告无个性化价值 |
| P1 | **解锁接口**（`POST /api/assessment/report/:id/unlock`）| 打通落地页"解锁"行为与 admin 侧 `viewed` 字段 |
| P1 | **admin 报告列表筛选逻辑** | 当前 6 个筛选项全部无效，影响运营核心工作流 |
| P2 | **"生成线索"接口**（`POST /api/admin/reports/:id/generate-lead`） | 打通报告→线索的业务闭环 |
| P2 | **报告模块数据统一**（解决冲突 #2 和 #7）：确定 admin 侧 `reports.modules` 是否需要存完整模块评分结构，还是仅存名称 | 影响数据库表结构设计 |
| P3 | **答题草稿保存**（localStorage 或服务端） | 提升答题完成率 |
| P3 | **题库管理 admin 界面** | 当前无题库管理入口，题目修改需改代码 |

---

## 11. 不确定项

| # | 不确定项 | 文件 | 假设 | 影响范围 |
|---|----------|------|------|----------|
| 1 | `getRiskLevel` 的分数阈值（≥85/≥65/≥35）是否为最终产品标准，还是临时占位？当前题库 15 道题最高总分为 `2+5+5+4+5+5+5+5+5+4+5+5+4+5+4=73`（极端情况），而阈值要求 ≥85 才到严重风险，理论上无法触达严重风险 | `report/page.tsx:57–62`, `risk-assessment-quiz-page.tsx:27–43` | 假设当前阈值为占位，需产品根据实际题库得分分布重新校准 | 影响 RiskLevel 枚举的后端实现和 admin 统计口径 |
| 2 | 报告页展示的 5 个模块（含评分）是否应该从答题结果动态计算，还是始终展示同一套固定模块？ | `report/page.tsx:24–55` | 假设应该动态计算：每个模块的分数 = 该模块下所有题目被选中选项的 score 之和 | 影响提交接口响应结构和报告数据库设计 |
| 3 | `reports.answers` 应该存原始选项索引（`{ questionId: number, selectedIndexes: number[] }[]`）还是存自然语言摘要（`string[]`）？两种方案各有利弊：前者支持重算分数，后者便于 admin 直接阅读 | `mock-data.ts:60–63` | 假设同时存储：原始索引供服务端校验和重算，自然语言摘要供 admin 阅读 | 影响 AssessmentReport 表的 answers 字段类型和提交接口的处理逻辑 |
| 4 | "保存到我的报告"功能的业务含义是什么？是用户-报告的收藏关联，还是报告已经默认属于用户（提交时 userId 已关联），此按钮仅做本地 UI 标记？ | `report/page.tsx:105, 308–311` | 假设报告提交时已关联 userId，此按钮可能是"收藏/标记重要"的额外功能，或者是未登录用户提交报告后补充绑定 userId 的操作 | 影响 reports 表的用户关联设计 |
| 5 | 未登录用户是否可以完成测评？当前流程：答题 → 跳转报告页（无登录校验）→ 点击"解锁完整报告"才弹出登录。服务端是否允许未关联 userId 的匿名报告记录临时存储？ | `risk-assessment-quiz-page.tsx:74–87`, `report/page.tsx:131–134` | 假设允许匿名测评，但报告仅展示基础版；登录后通过 phone 绑定 userId 并解锁完整版，服务端需支持报告记录的匿名→实名迁移 | 影响提交接口的认证要求和报告表的 userId nullable 设计 |
| 6 | 管理后台测评报告详情抽屉中的"顾问分配"（`reports.advisor` 字段）是手动操作还是自动分配？当前 Mock 中已有"周顾问"/"刘顾问"/"未分配"三种值，但抽屉内无分配操作按钮 | `mock-data.ts:60–63`, `assessment-reports/page.tsx:107–117` | 假设需要手动分配，需要在详情抽屉或行操作中增加"分配顾问"按钮 | 影响抽屉操作设计和 `POST /api/admin/reports/:id/assign-advisor` 接口 |

---

**高风险不一致项汇总（需优先处理）**：

1. **评分全在客户端，服务端无数据**：答题提交无 API，报告无法入库，整个测评模块的数据流在业务上等于不存在。这是本模块最高优先级问题，阻塞所有下游。
2. **报告通过 user 姓名关联用户**（`users.find(u => u.name === current.user)`）：与用户管理审计高风险项 #1 相同根因，姓名重复必然导致数据污染，必须改为 `userId` 外键。
3. **answers 字段含义双重**：Mock 存自然语言摘要，答题 state 存选项索引，两者格式不兼容，提交接口设计前必须先明确存储格式。
4. **题库模块与报告模块映射断裂**：题库 8 个模块，报告展示 5 个模块，命名不一致，无法从答题结果自动推导报告模块评分，报告个性化功能的实现前提是先解决此映射问题。
