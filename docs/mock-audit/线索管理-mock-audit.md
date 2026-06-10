# 线索管理（含预约）模块 Mock 数据审计报告

**审计日期**：2026-06-10
**审计员**：mock-auditor agent
**项目阶段**：MVP 原型阶段，无真实数据库和身份认证
**关联报告**：`docs/mock-audit/用户管理-mock-audit.md`（用户字段已审计，本报告聚焦线索与预约，关联处引用）

---

## 1. 审计范围

| 系统 | 文件路径 | 页面 / 用途 |
|------|----------|-------------|
| admin-system | `拓客系统-管理后台/app/leads/page.tsx` | 线索列表 + 线索详情抽屉 |
| admin-system | `拓客系统-管理后台/lib/mock-data.ts` | `leads` 数组、`LeadStatus` 类型定义，以及线索抽屉中跨实体引用的 `users`、`reports`、`qaRecords`、`userTimeline` |
| admin-system | `拓客系统-管理后台/lib/ui.ts` | `statusTheme`（线索状态颜色映射）、`riskTheme` |
| landing-page | `拓客系统-落地页/app/appointment/page.tsx` | 预约顾问表单（预约即线索转化终点） |
| landing-page | `拓客系统-落地页/app/risk-assessment/report/page.tsx` | 风险报告页（触发预约的主要入口） |
| landing-page | `拓客系统-落地页/components/mobile/event-landing-page.tsx` | 落地页主页（预约入口之一） |

**不在本次审计范围内**：用户注册/登录、管理员认证、活动管理、二维码管理、资料管理（均已在用户管理审计或其他模块涵盖）。

---

## 2. Mock 来源清单

| 来源类型 | 文件 | 具体内容 | 证据位置 |
|----------|------|----------|----------|
| 硬编码类型定义 | `lib/mock-data.ts` | `LeadStatus` 联合类型，7 个枚举值 | `mock-data.ts:2` |
| 硬编码对象数组 | `lib/mock-data.ts` | `leads` 数组，3 条线索记录 | `mock-data.ts:65-69` |
| 跨实体字符串关联 | `app/leads/page.tsx` | `users.find(u => u.name === current.name)`，用姓名匹配用户 | `leads/page.tsx:32` |
| 跨实体字符串关联 | `app/leads/page.tsx` | `reports.find(r => r.user === current.name)`，用姓名匹配报告 | `leads/page.tsx:33` |
| 跨实体字符串关联 | `app/leads/page.tsx` | `qaRecords.find(q => q.user === current.name)`，用姓名匹配问答 | `leads/page.tsx:34` |
| 全局共享 Mock 数据 | `app/leads/page.tsx` | `userTimeline` 无 userId，线索详情"行为路径"卡片对所有线索展示同一条时间线 | `leads/page.tsx:86` |
| 硬编码意向分构成 | `app/leads/page.tsx` | 详情抽屉"意向分构成"中 4 项得分和进度条宽度全为写死值 | `leads/page.tsx:88` |
| 硬编码下一步话术 | `app/leads/page.tsx` | `下一步动作：24 小时内电话联系…` 对所有线索展示相同文本 | `leads/page.tsx:87` |
| 硬编码顾问选项 | `app/leads/page.tsx` | 筛选器"分配顾问"下拉写死 `周顾问`、`刘顾问`、`未分配` | `leads/page.tsx:53` |
| 硬编码标签选项 | `app/leads/page.tsx` | 筛选器"需求标签"下拉写死 4 个标签值 | `leads/page.tsx:50` |
| 写死分页总数 | `app/leads/page.tsx` | `total: leads.length`（当前固定为 3） | `leads/page.tsx:78` |
| 无状态提交（表单 Mock） | `app/appointment/page.tsx` | `handleSubmit` 仅调用 `setSubmitted(true)`，无任何 API 调用 | `appointment/page.tsx:72-75` |
| 硬编码选项列表 | `app/appointment/page.tsx` | `topics`、`industries`、`contactTimes`、`uploadOptions` 均为组件内硬编码数组 | `appointment/page.tsx:14-17` |
| 前端状态模拟业务 | `app/appointment/page.tsx` | `submitted` state 模拟提交成功，无持久化 | `appointment/page.tsx:54` |
| 硬编码报告数据 | `app/risk-assessment/report/page.tsx` | `modules` 数组（5 个风险模块，含 name/score/desc/advice）全为写死值 | `report/page.tsx:24-55` |
| URL 参数注入分数 | `app/risk-assessment/report/page.tsx` | `score` 从 `searchParams.get("score")` 读取，无登录验证，任意值可注入 | `report/page.tsx:107-110` |
| 前端状态模拟解锁 | `app/risk-assessment/report/page.tsx` | `isUnlocked` state 在登录成功回调时设为 true，服务端不感知 | `report/page.tsx:104,132-134` |
| 前端状态模拟保存 | `app/risk-assessment/report/page.tsx` | `isSaved` state 设为 true 仅改按钮文字，无 API 调用 | `report/page.tsx:105,309-313` |

---

## 3. 页面数据需求

### 3.1 线索列表页（`admin-system/app/leads/page.tsx`）

**概览统计卡片（5 张，全部为计算字段）**

| 指标 | 计算逻辑 | 字段依赖 | 证据位置 |
|------|----------|----------|----------|
| 新增线索数 | `leads.length` | count | `leads/page.tsx:24` |
| 高意向线索数 | `lead.level.includes('高意向')` | `level: string` | `leads/page.tsx:25` |
| 强意向线索数 | `lead.level.includes('强意向')` | `level: string` | `leads/page.tsx:26` |
| 待跟进线索数 | `status` 在 `['新线索','待跟进','已分配']` 中 | `status: LeadStatus` | `leads/page.tsx:27` |
| 已成交线索数 | `status === '已成交'` | `status: LeadStatus` | `leads/page.tsx:28` |

**筛选条件**

| 筛选项 | 字段依赖 | 数据来源 | 证据位置 |
|--------|----------|----------|----------|
| 姓名 / 手机号搜索 | `name`, `phone` | 用户输入 | `leads/page.tsx:47` |
| 来源活动 | `activity` | `activities` 数组动态生成 | `leads/page.tsx:48` |
| 来源二维码 | `qr` | `qrCodeItems` 数组动态生成 | `leads/page.tsx:49` |
| 需求标签 | `tags` | 页面硬编码选项 | `leads/page.tsx:50` |
| 意向等级 | `level` | 页面硬编码选项 | `leads/page.tsx:51` |
| 风险等级 | `risk` | 页面硬编码选项 | `leads/page.tsx:52` |
| 分配顾问 | `advisor` | 页面硬编码选项 | `leads/page.tsx:53` |
| 创建时间区间 | `created` | DateRangePicker | `leads/page.tsx:54` |

注：所有筛选控件为受控组件，但无任何过滤逻辑绑定（同用户列表页的问题），功能完全无效。

**线索列表表格（14 列实际使用）**

| 列 | 字段 | 类型 | 证据位置 |
|----|------|------|----------|
| 线索 ID | `id` | `string` | `leads/page.tsx:63` |
| 姓名 | `name` | `string` | `leads/page.tsx:64` |
| 手机号 | `phone` | `string` | `leads/page.tsx:65` |
| 企业名称 | `company` | `string` | `leads/page.tsx:66` |
| 来源活动 | `activity` | `string` | `leads/page.tsx:67` |
| 来源二维码 | `qr` | `string` | `leads/page.tsx:68` |
| 需求标签 | `tags` | `string[]` | `leads/page.tsx:69` |
| 意向分 | `score` | `number` | `leads/page.tsx:70` |
| 线索等级 | `level` | `string` | `leads/page.tsx:71` |
| 风险等级 | `risk` | `RiskLevel` | `leads/page.tsx:72` |
| 分配顾问 | `advisor` | `string` | `leads/page.tsx:73` |
| 跟进状态 | `status` | `LeadStatus` | `leads/page.tsx:74` |
| 最近跟进记录 | `last` | `string` | `leads/page.tsx:75` |
| 创建时间 | `created` | `string` | `leads/page.tsx:76` |

**行操作**：查看详情（打开 820px 右侧抽屉）、分配顾问（`MessagePlugin.success` 占位）、添加跟进（打开抽屉）、更新状态（占位）。

---

### 3.2 线索详情抽屉（`admin-system/app/leads/page.tsx`，Drawer）

抽屉在同一文件中实现，打开后展示 6 张卡片。

**抽屉顶部 Hero 区**

| 数据项 | 来源字段 | 分类 |
|--------|----------|------|
| 线索等级 badge | `current.level` | 展示字段 |
| 姓名 | `current.name` | 持久化 |
| 企业名称 | `current.company` | 持久化 |
| 手机号 | `current.phone` | 持久化 |
| 分配顾问 | `current.advisor` | 关联字段 |
| 跟进状态 | `current.status` | 持久化（状态机） |
| 意向分 | `current.score` | 计算字段（持久化缓存） |

**卡片 1：用户基础信息**（`Descriptions`）

| 字段 | 来源 | 分类 | 证据位置 |
|------|------|------|----------|
| 姓名 | `current.name` | 持久化（Lead 自身） | `leads/page.tsx:84` |
| 手机号 | `current.phone` | 持久化（Lead 自身） | `leads/page.tsx:84` |
| 企业名称 | `current.company` | 持久化（Lead 自身） | `leads/page.tsx:84` |
| 行业 | `currentUser.industry` | 跨实体关联（User.industry） | `leads/page.tsx:84` |
| 企业规模 | `currentUser.size` | 跨实体关联（User.size） | `leads/page.tsx:84` |

**卡片 2：来源信息**（`Descriptions`）

| 字段 | 来源 | 分类 | 证据位置 |
|------|------|------|----------|
| 来源活动 | `current.activity` | 持久化（Lead 自身） | `leads/page.tsx:85` |
| 来源二维码 | `current.qr` | 持久化（Lead 自身） | `leads/page.tsx:85` |
| 需求标签 | `current.tags` | 持久化（Lead 自身） | `leads/page.tsx:85` |
| 创建时间 | `current.created` | 持久化（Lead 自身） | `leads/page.tsx:85` |

**卡片 3：行为路径**（`Timeline`）

数据来源：`userTimeline`（全局静态，无 userId 关联），所有线索详情显示同一组行为时间线，证据位置 `leads/page.tsx:86`。

**卡片 4：为什么值得跟进**（`ul` 列表）

| 数据项 | 来源字段 | 分类 | 证据位置 |
|--------|----------|------|----------|
| AI 问答摘要 | `currentQa.summary` | 跨实体关联（QaRecord） | `leads/page.tsx:87` |
| 问答风险等级 | `currentQa.risk` | 跨实体关联（QaRecord） | `leads/page.tsx:87` |
| 测评风险分 | `currentReport.score` | 跨实体关联（Report） | `leads/page.tsx:87` |
| 测评风险模块 | `currentReport.modules` | 跨实体关联（Report） | `leads/page.tsx:87` |
| 最近跟进记录 | `current.last` | 持久化（Lead 自身） | `leads/page.tsx:87` |
| 下一步动作 | 硬编码字符串 | 无（仅前端展示文本） | `leads/page.tsx:87` |

**卡片 5：意向分构成**（进度条列表）

4 项得分和宽度均为硬编码（`测评高风险:40`、`查看完整报告:25`、`预约顾问:35`、`高风险问答:18`），对所有线索展示相同数值，证据位置 `leads/page.tsx:88`。

**卡片 6：添加跟进记录**（`Form`）

| 表单字段 | 类型 | 分类 | 证据位置 |
|----------|------|------|----------|
| 跟进内容（Textarea） | `string` | 持久化（FollowUpRecord） | `leads/page.tsx:89` |
| 更新状态（Select） | `LeadStatus` | 持久化（Lead.status） | `leads/page.tsx:89` |

注：表单中"保存跟进"和"更新状态"按钮无 API 调用（onClick 无处理），当前为纯占位。

---

### 3.3 预约表单页（`landing-page/app/appointment/page.tsx`）

**FormState 类型（组件内定义，`appointment/page.tsx:19-29`）**

| 字段 | 类型 | 必填 | 用途分类 | 证据位置 |
|------|------|------|----------|----------|
| `name` | `string` | 必填（validate） | 持久化（Appointment） | `appointment/page.tsx:19,62` |
| `phone` | `string` | 必填，11 位正则 | 持久化（Appointment） | `appointment/page.tsx:20,65` |
| `topic` | `string` | 必填 | 持久化（Appointment） | `appointment/page.tsx:21,67` |
| `description` | `string` | 必填 | 持久化（Appointment） | `appointment/page.tsx:22,68` |
| `company` | `string` | 选填 | 持久化（Appointment） | `appointment/page.tsx:23` |
| `industry` | `string` | 选填 | 持久化（Appointment） | `appointment/page.tsx:24` |
| `contactTime` | `string` | 选填 | 持久化（Appointment） | `appointment/page.tsx:25` |
| `wechat` | `string` | 选填 | 持久化（Appointment） | `appointment/page.tsx:26` |
| `uploadIntent` | `string` | 选填 | 持久化（Appointment，意向信号） | `appointment/page.tsx:27` |

**硬编码枚举选项**（组件顶部，`appointment/page.tsx:14-17`）

| 变量 | 类型 | 值 | 证据位置 |
|------|------|-----|----------|
| `topics` | `string[]` | 8 个咨询主题 | `appointment/page.tsx:14` |
| `industries` | `string[]` | 8 个行业选项 | `appointment/page.tsx:15` |
| `contactTimes` | `string[]` | 5 个时段选项 | `appointment/page.tsx:16` |
| `uploadOptions` | `string[]` | 3 个意向选项 | `appointment/page.tsx:17` |

注：这 4 组枚举选项将来可以是数据库枚举（配置化），也可以保留为前端常量，取决于业务是否需要动态修改。

---

### 3.4 风险报告页（`landing-page/app/risk-assessment/report/page.tsx`）

风险报告页是预约的核心触发入口（高风险时显示"预约顾问解读"按钮）。

**页面使用的数据**

| 数据项 | 来源 | 分类 | 证据位置 |
|--------|------|------|----------|
| `score` | `searchParams.get("score")` URL 参数 | 前端状态（无服务端验证） | `report/page.tsx:107-110` |
| `level` | `getRiskLevel(score)` 计算 | 展示字段（计算字段） | `report/page.tsx:111` |
| `modules[]` | 组件内硬编码数组（5 项） | Mock（应来自真实测评结果） | `report/page.tsx:24-55` |
| `isUnlocked` | React state（登录回调设置） | 仅前端状态 | `report/page.tsx:104` |
| `isSaved` | React state（按钮点击设置） | 仅前端状态 | `report/page.tsx:105` |

---

## 4. 业务实体和字段

### 4.1 线索（Lead）

#### 数据库实体（需持久化）

| 字段 | 类型 | 分类 | 证据位置 |
|------|------|------|----------|
| `id` | `string`（如 `L20260605001`） | 持久化（主键，含日期） | `mock-data.ts:66` |
| `name` | `string` | 持久化（冗余，应改为 userId 外键） | `mock-data.ts:66` |
| `phone` | `string` | 持久化（冗余，脱敏展示） | `mock-data.ts:66` |
| `company` | `string` | 持久化（冗余，应从 User 关联） | `mock-data.ts:66` |
| `activity` | `string` | 持久化（来源活动名称，应改为 activityId） | `mock-data.ts:66` |
| `qr` | `string` | 持久化（来源二维码标识，应改为 qrCodeId） | `mock-data.ts:66` |
| `tags` | `string[]` | 持久化（需求标签） | `mock-data.ts:66` |
| `score` | `number` | 持久化（意向分，计算后缓存） | `mock-data.ts:66` |
| `level` | `string` | 持久化（线索等级，意向分区间映射） | `mock-data.ts:66` |
| `risk` | `RiskLevel` | 持久化（来自 Report，冗余缓存） | `mock-data.ts:66` |
| `advisor` | `string` | 持久化（分配顾问名称，应改为 advisorId） | `mock-data.ts:66` |
| `status` | `LeadStatus` | 持久化（状态机核心字段） | `mock-data.ts:66` |
| `last` | `string` | 持久化（最近一条跟进记录摘要，冗余缓存） | `mock-data.ts:66` |
| `created` | `string` / `timestamp` | 持久化（系统自动） | `mock-data.ts:66` |
| `userId`（缺失） | 外键 | 关联字段（当前通过 `name` 字符串关联 User） | — |
| `reportId`（缺失） | 外键 | 关联字段（当前通过 `name` 字符串关联 Report） | — |

#### 列表 DTO（用于线索列表表格）

`id`, `name`, `phone`, `company`, `activity`, `qr`, `tags`, `score`, `level`, `risk`, `advisor`, `status`, `last`, `created`

#### 详情 DTO（用于线索详情抽屉）

列表 DTO 全部字段 + 跨实体关联字段（通过 `userId` 联查）：
- `user.industry`（用户行业）
- `user.size`（企业规模）
- `user.timeline[]`（行为时间线，需按 userId 过滤）
- `report.score`（测评风险分）
- `report.modules`（主要风险模块）
- `qaRecord.summary`（AI 问答摘要）
- `qaRecord.risk`（问答风险等级）
- `followUpRecords[]`（跟进记录列表，当前 Mock 无此字段）

#### Mock 中存在但页面**未使用**的字段

Lead 实体字段当前全部在页面中使用，无冗余字段。

---

### 4.2 LeadStatus 枚举

`lib/mock-data.ts:2` 定义：

```
'新线索' | '待跟进' | '已分配' | '跟进中' | '已预约' | '已成交' | '无效线索'
```

`lib/ui.ts:10-14` 的 `statusTheme` 函数覆盖这 7 个值，映射一致。

但参见用户管理审计（`docs/mock-audit/用户管理-mock-audit.md` 第 7 节）：`users.leadStatus` 字段使用了"未生成"这个**不在 `LeadStatus` 枚举内**的值（`mock-data.ts:40`），并且用户列表页的统计逻辑直接依赖 `!== '未生成'`（`users/page.tsx:23`）。

**本模块视角**：`LeadStatus` 只管理已生成线索的流转状态；"未生成"是用户未进入线索池的状态，属于 `User.leadStatus` 字段的扩展，不应加入 `LeadStatus` 枚举，而应在 `User` 的线索状态字段上单独处理。

---

### 4.3 线索跟进记录（FollowUpRecord）

**当前 Mock 状态**：无独立实体。`leads.last` 字段仅存储最近一条跟进摘要字符串；抽屉中有"添加跟进记录"表单（`leads/page.tsx:89`），但提交无 API 调用，跟进历史无处存储。

**页面使用的字段**（从 UI 推断）：

| 字段 | 类型 | 分类 | 证据位置 |
|------|------|------|----------|
| `leadId`（缺失） | 外键 | 关联字段（归属哪条线索） | `leads/page.tsx:89` |
| `content` | `string` | 持久化（跟进内容，Textarea） | `leads/page.tsx:89` |
| `newStatus` | `LeadStatus` | 持久化（更新后的跟进状态） | `leads/page.tsx:89` |
| `createdAt`（缺失） | `timestamp` | 持久化（系统自动） | — |
| `advisorId`（缺失） | 外键 | 持久化（操作人） | — |

---

### 4.4 预约（Appointment）

**当前 Mock 状态**：预约表单存在完整的 `FormState` 类型定义（`appointment/page.tsx:19-29`），但提交仅触发前端状态变化，无 API 调用，无持久化。

**与线索的关系**：从业务流程看（CLAUDE.md 核心流程），用户提交预约后应触发线索状态变为"已预约"或生成新线索，但当前两端均无此联动逻辑。

**数据库实体（需持久化）**

| 字段 | 类型 | 必填 | 分类 | 证据位置 |
|------|------|------|------|----------|
| `id`（缺失） | `uuid` | — | 持久化（主键） | — |
| `name` | `string` | 必填 | 持久化 | `appointment/page.tsx:19` |
| `phone` | `string` | 必填（11 位手机号） | 持久化 | `appointment/page.tsx:20` |
| `topic` | `string` | 必填（枚举之一） | 持久化 | `appointment/page.tsx:21` |
| `description` | `string` | 必填 | 持久化 | `appointment/page.tsx:22` |
| `company` | `string` | 选填 | 持久化（可 nullable） | `appointment/page.tsx:23` |
| `industry` | `string` | 选填 | 持久化（可 nullable） | `appointment/page.tsx:24` |
| `contactTime` | `string` | 选填 | 持久化（可 nullable） | `appointment/page.tsx:25` |
| `wechat` | `string` | 选填 | 持久化（可 nullable） | `appointment/page.tsx:26` |
| `uploadIntent` | `string` | 选填 | 持久化（意向信号） | `appointment/page.tsx:27` |
| `userId`（缺失） | 外键 | — | 关联字段（若用户已登录） | — |
| `leadId`（缺失） | 外键 | — | 关联字段（预约对应的线索） | — |
| `status`（缺失） | `string`（枚举） | — | 持久化（预约状态：待联系/已联系/已完成） | — |
| `createdAt`（缺失） | `timestamp` | — | 持久化（系统自动） | — |

**假设**：`userId` 为可 nullable（允许未登录用户通过手机号提交预约；已登录用户提交时关联 userId）。

---

### 4.5 意向分（LeadScore）构成

当前"意向分构成"卡片（`leads/page.tsx:88`）展示 4 个维度，但数值全为硬编码，实际使用的维度如下：

| 维度 | 硬编码值 | 应来自 | 证据位置 |
|------|----------|--------|----------|
| 测评高风险 | 40 | `report.score` 区间映射 | `leads/page.tsx:88` |
| 查看完整报告 | 25 | `report.viewed` 布尔值 | `leads/page.tsx:88` |
| 预约顾问 | 35 | `Appointment` 存在与否 | `leads/page.tsx:88` |
| 高风险问答 | 18 | `qaRecord.risk === '高风险'` | `leads/page.tsx:88` |

`leads.score` 字段存储总意向分（如 `118`、`132`、`58`），应为上述 4 个子维度之和。目前 Mock 中总分与子维度相加值不一致（118 ≠ 40+25+35+18=118，恰好一致；132 和 58 无法从子维度推导，因为子维度对所有线索均为写死相同值），说明总分是独立设置的 Mock 数据，子维度构成不来自总分计算。

---

## 5. 页面操作

### 线索列表页

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 搜索 / 筛选 | 查询按钮 | 无效（筛选无 onChange 绑定过滤逻辑） | `GET /api/leads?name=&phone=&activity=&qr=&tags=&level=&risk=&advisor=&dateFrom=&dateTo=&page=&pageSize=` |
| 重置筛选 | 重置按钮 | 无效 | — |
| 查看详情 | 操作列"查看详情" | `openDetail(row)` 打开 Drawer | 需 `GET /api/leads/:id` 获取完整详情 |
| 分配顾问 | 更多菜单"分配顾问" | `MessagePlugin.success('已分配顾问')` 占位 | `PATCH /api/leads/:id/advisor` |
| 添加跟进 | 更多菜单"添加跟进" | `openDetail(row)` 打开 Drawer | `POST /api/leads/:id/follow-ups` |
| 更新状态 | 更多菜单"更新状态" | 无实现（onMoreClick 无对应处理） | `PATCH /api/leads/:id/status` |
| 批量分配顾问 | 头部按钮 | 无实现（无 onClick） | `PATCH /api/leads/bulk-assign` |
| 导出线索 | 头部按钮 | 无实现（无 onClick） | `GET /api/leads/export` |
| Tab 状态切换 | `Tabs` 组件 | 切换无过滤逻辑 | 在 `GET /api/leads` 中加 `status=` 参数 |

### 线索详情抽屉

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 保存跟进 | "保存跟进"按钮 | 无 onClick 处理 | `POST /api/leads/:id/follow-ups` |
| 更新状态 | "更新状态"按钮 | 无 onClick 处理 | `PATCH /api/leads/:id/status` |

### 预约表单页（落地页）

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 提交预约 | "提交预约"按钮 | 仅前端 validate → `setSubmitted(true)`，无 API 调用 | `POST /api/appointments` |
| 提交成功后"查看我的预约" | 按钮 | `router.push("/appointment")`（路由回自身） | `GET /api/appointments/me`（需登录） |

注：提交成功页"查看我的预约"按钮跳回 `/appointment` 路由（`appointment/page.tsx:91`），这实际上是重置了表单页而非跳到预约详情页。属于路由逻辑缺口。

---

## 6. 建议 API

### 线索管理（admin-system）

| 方法 | 路径 | 参数 / 请求体 | 响应 |
|------|------|---------------|------|
| `GET` | `/api/leads` | `name`, `phone`, `activity`, `qr`, `tags`, `level`, `risk`, `advisor`, `status`, `dateFrom`, `dateTo`, `page`, `pageSize` | `{ items: LeadListDTO[], total: number }` |
| `GET` | `/api/leads/:id` | — | `LeadDetailDTO`（含跨实体关联字段） |
| `PATCH` | `/api/leads/:id/advisor` | `{ advisorId: string }` | `LeadListDTO` |
| `PATCH` | `/api/leads/:id/status` | `{ status: LeadStatus }` | `LeadListDTO` |
| `POST` | `/api/leads/:id/follow-ups` | `{ content: string, newStatus: LeadStatus }` | `FollowUpRecord` |
| `GET` | `/api/leads/:id/follow-ups` | — | `FollowUpRecord[]` |
| `PATCH` | `/api/leads/bulk-assign` | `{ ids: string[], advisorId: string }` | `{ updated: number }` |
| `GET` | `/api/leads/export` | 同筛选参数 | CSV / XLSX 文件流 |

### 预约（landing-page）

| 方法 | 路径 | 请求体 | 响应 |
|------|------|--------|------|
| `POST` | `/api/appointments` | `AppointmentCreateDTO` | `{ id: string, createdAt: string }` |
| `GET` | `/api/appointments/me` | Header: Bearer token（可选） | `AppointmentDTO[]` |

**AppointmentCreateDTO**（对应表单 FormState）：

```typescript
{
  name: string;           // 必填
  phone: string;          // 必填，11 位
  topic: string;          // 必填，枚举之一
  description: string;    // 必填
  company?: string;
  industry?: string;
  contactTime?: string;
  wechat?: string;
  uploadIntent?: string;
  userId?: string;        // 若已登录则由服务端从 token 注入
  sourceLeadId?: string;  // 若从报告页跳转则由 URL 参数传入
}
```

### 线索自动生成（admin-system 或内部 Server Action）

| 方法 | 路径 | 触发时机 | 说明 |
|------|------|----------|------|
| `POST` | `/api/leads` | 用户完成测评 / 提交预约 / 人工从用户列表触发 | 创建新线索，初始状态为"新线索" |

---

## 7. 字段和类型冲突

| # | 冲突描述 | 文件 A | 文件 B | 字段 | 风险等级 |
|---|----------|--------|--------|------|----------|
| 1 | **Lead 通过 `name` 字符串关联 User / Report / QaRecord**：`leads/page.tsx` 用 `users.find(u => u.name === current.name)`、`reports.find(r => r.user === current.name)`、`qaRecords.find(q => q.user === current.name)` 三处均用姓名匹配，同名用户会导致数据混乱 | `leads/page.tsx:32-34` | `mock-data.ts:35-69` | `name`（应为 `userId` 外键） | 高风险 |
| 2 | **`leads.id` 格式含日期但非规范主键**：`L20260605001` 将日期编码进 ID，后端如果用 UUID 或自增 ID 会与前端格式不一致；且 ID 中的日期与 `created` 字段冗余 | `mock-data.ts:66-69` | — | `id` | 中风险 |
| 3 | **`leads.activity` 和 `leads.qr` 存名称 / 标识字符串而非外键**：`activity` 存活动名称字符串（如"金税四期风险识别专题课"），`qr` 存二维码标识（如"CHANNEL-SZ-002"），活动改名后将断裂；二维码 ID（`QR-CH-SZ-002`）与 `qr` 字段值（`CHANNEL-SZ-002`）不一致，且与 `qrCodeItems.inviteCode`（`CHANNEL-SZ-002`）才匹配，混用了 ID 和 inviteCode | `mock-data.ts:66-69` | `mock-data.ts:71-77` | `activity`（应为 `activityId`）、`qr`（应为 `qrCodeId`） | 高风险 |
| 4 | **`leads.advisor` 存顾问名称字符串**：`advisor` 字段值为"周顾问"、"刘顾问"等名称字符串，筛选器也用名称硬编码匹配，无独立的 Advisor 实体或 AdminUser 外键 | `mock-data.ts:66-69` | `leads/page.tsx:53` | `advisor`（应为 `advisorId`） | 中风险 |
| 5 | **`leads.risk` 与 `reports.risk` 的来源不统一**：`leads.risk` 应冗余自对应用户的 `report.risk`，但 Mock 中两者均独立设置，赵瑞的 `lead.risk` 为"严重风险"与 `report.risk` 一致，但李明的 `lead.risk` 为"高风险"与 `report.risk`"高风险"一致，属于巧合一致而非计算得到 | `mock-data.ts:66-69` | `mock-data.ts:59-63` | `risk` | 中风险 |
| 6 | **`leads.score`（总意向分）与意向分构成维度的计算关系不明**：列表页显示总分 `leads.score`，抽屉展示 4 个硬编码子维度且对所有线索相同，无法从子维度计算出与总分一致的结果 | `mock-data.ts:66` | `leads/page.tsx:88` | `score` | 中风险 |
| 7 | **预约表单 `topic` 枚举与 `qaRecords.type` 字段值不一致**：`appointment/page.tsx:14` 的 `topics` 有"税务风险排查"、"发票合规"等 8 项，但 `qaRecords.type`（`mock-data.ts:54-57`）的值为"公转私风险"、"政策咨询"、"申报异常"等，两者映射关系未定义 | `appointment/page.tsx:14` | `mock-data.ts:53-57` | `topic` / `type` | 中风险 |
| 8 | **`LeadStatus` 枚举与 `users.leadStatus` 使用"未生成"的冲突**（继承自用户管理审计）：`LeadStatus` 定义 7 个值但不含"未生成"，`users` 数组用"未生成"，且 `statusTheme` 函数对"未生成"返回 `'primary'`（通过 `return 'primary'` 兜底），接入真实数据后如果按类型约束会直接报错 | `mock-data.ts:2` | `mock-data.ts:40` / `users/page.tsx:23` | `leadStatus` | 高风险 |
| 9 | **预约表单手机号字段与用户手机号关联方式缺失**：表单收集 `phone` 字段，但无逻辑将预约与已注册用户关联（通过手机号匹配？通过登录 token？），导致后端无法判断预约是否来自已知用户 | `appointment/page.tsx:20` | `mock-data.ts:35-41` | `phone` | 高风险 |

---

## 8. 页面状态缺口

| # | 缺口描述 | 页面 | 当前状态 | 影响 |
|---|----------|------|----------|------|
| 1 | **线索列表筛选和 Tab 无任何过滤逻辑** | 线索列表页 | 所有筛选控件（Input、Select、DateRangePicker）无 onChange 绑定，Tab 组件切换无关联过滤；"查询"和"重置"按钮无 onClick | 核心运营功能完全无效，无法按状态/意向/顾问查看线索 |
| 2 | **线索详情抽屉"添加跟进记录"表单无提交逻辑** | 线索详情抽屉 | "保存跟进"和"更新状态"按钮无 onClick 事件 | 跟进记录无法保存，状态无法从详情页更新 |
| 3 | **意向分构成对所有线索展示相同写死数据** | 线索详情抽屉 | 4 项得分和进度条宽度硬编码，无法反映单条线索的真实行为构成 | 运营人员看到的意向分构成无参考价值 |
| 4 | **行为路径时间线对所有线索展示同一条全局数据** | 线索详情抽屉 | `userTimeline` 无 userId，所有线索详情展示相同时间线 | 无法判断该线索用户的真实行为路径 |
| 5 | **预约表单提交无 API 调用，数据不落库** | 落地页预约页 | `handleSubmit` 仅 `setSubmitted(true)` | 预约数据完全丢失，管理后台永远看不到新预约 |
| 6 | **预约成功页"查看我的预约"按钮路由错误** | 落地页预约页（提交成功态） | `router.push("/appointment")` 跳回预约表单页，而非预约详情页 | 用户点击后看到的是空表单，无法查看刚才提交的预约 |
| 7 | **预约表单不感知用户登录状态** | 落地页预约页 | `FormState` 有完整的 9 个字段，但 `name`/`phone`/`company` 不会从已登录用户数据预填，用户需重复填写 | 已注册用户体验差；后端无法自动关联预约与用户 |
| 8 | **风险报告 `score` 参数无服务端验证** | 落地页报告页 | `score = Number(searchParams.get("score") ?? 72)`，任意人可在 URL 中传入任意分数绕过测评 | 测评结果可被篡改，"高风险"触发预约引导的策略失效 |
| 9 | **报告解锁和保存状态仅存 React state，刷新即丢失** | 落地页报告页 | `isUnlocked`、`isSaved` 仅为组件状态 | 用户刷新后需重新登录解锁，已保存报告无从查找 |
| 10 | **线索"批量分配顾问"和"导出线索"按钮无实现** | 线索列表页 | 按钮渲染但无 onClick | 运营批量操作功能缺失 |
| 11 | **预约提交后未触发线索状态变更** | 落地页 → admin-system | 落地页提交预约后，admin-system 中对应线索的 `status` 应变为"已预约"，但两端均无此联动 | 线索状态与预约事件脱节 |

---

## 9. 共用模型

| 实体 | landing-page 视角 | admin-system 视角 | 共同字段 | 注意事项 |
|------|-------------------|-------------------|----------|----------|
| Lead（线索） | 不直接感知；用户提交预约/测评后系统自动生成 | 线索池核心对象，运营人员管理和跟进 | `status`（用于预约时更新）、`userId`（外键） | 落地页不应直接操作 Lead，应通过 Appointment 间接触发 |
| Appointment（预约） | 用户主动提交，9 个字段，无登录强制要求 | 用户详情页"预约记录"标签页展示（当前为硬编码字符串） | `name`, `phone`, `topic`, `description`, `company`, `industry`, `contactTime`, `wechat`, `uploadIntent`, `createdAt` | 需明确 Appointment 与 Lead 的关系：是同一实体的不同状态，还是独立实体？ |
| LeadStatus（枚举） | 不直接使用（仅触发状态变更的动作入口） | `statusTheme` 颜色映射，Tab 过滤，表单更新状态 | 共同枚举值 | "未生成"在枚举外，需单独处理 |
| User（端用户） | 预约表单中 `name`/`phone`/`company` 可从用户数据预填 | 线索详情中跨查 `user.industry`、`user.size` | `name`, `phone`, `company`, `industry`, `size` | 参见用户管理审计报告第 9 节 |

**Appointment 与 Lead 关系假设**（不确定项，见第 11 节第 1 条）：

推荐将 Appointment 作为独立实体，与 Lead 通过 `leadId` 关联。Lead 在用户达到意向阈值时由系统自动创建；Appointment 在用户主动提交后创建并将对应 Lead 状态更新为"已预约"。

---

## 10. 推荐迁移顺序

| 优先级 | 模块 | 原因 |
|--------|------|------|
| P0 | 预约表单接入真实 API（`POST /api/appointments`） | 当前提交数据完全丢失，是整个转化漏斗的最终环节，无数据落库则业务价值为零 |
| P0 | 修复 `LeadStatus` 枚举缺少"未生成"问题 | 高风险类型冲突，影响用户列表和线索列表统计逻辑（继承自用户管理审计 P0） |
| P1 | 修复 Lead 关联方式（从 `name` 字符串改为 `userId` 外键） | 高风险数据污染，姓名重名即导致线索详情数据错乱（继承自用户管理审计 P1） |
| P1 | 修复 `leads.activity` 和 `leads.qr` 的关联方式（改为 `activityId`/`qrCodeId` 外键） | 高风险，名称变更会导致数据断裂 |
| P1 | 线索列表筛选和 Tab 过滤逻辑 | 核心运营功能完全无效，接入真实 API 后同步实现 |
| P2 | `FollowUpRecord` 实体 + 抽屉"添加跟进记录"提交逻辑 | 线索跟进是销售 CRM 的核心动作，当前无法保存任何跟进历史 |
| P2 | 意向分构成从真实数据计算 | 替换硬编码进度条，接入 report/qa/appointment 行为数据 |
| P2 | 行为路径时间线按 userId 过滤（继承自用户管理审计 P2） | 当前所有线索展示同一条时间线 |
| P2 | 预约表单从已登录用户数据预填（`name`/`phone`/`company`） | 减少用户重复填写，提升转化率 |
| P3 | 预约成功页路由修复（"查看我的预约"跳到预约详情） | 路由逻辑错误，影响用户体验 |
| P3 | 风险报告 `score` 参数服务端验证（与测评提交记录绑定） | 防止分数篡改，保证触发预约引导的策略准确性 |
| P3 | 线索批量分配顾问和导出功能 | 运营效率功能，优先级低于核心流程 |
| P3 | `advisor` 字段从名称字符串改为 `advisorId` 外键 | 中风险，需 Advisor/AdminUser 实体稳定后再处理 |

---

## 11. 不确定项

| # | 不确定项 | 文件 | 假设 | 影响范围 |
|---|----------|------|------|----------|
| 1 | **Appointment 和 Lead 是同一实体的不同阶段，还是两个独立实体？** 业务上"已预约"是线索的一个状态，但预约表单包含大量独立字段（topic/description/contactTime 等），若合并到 Lead 则 Lead 表字段过多 | `appointment/page.tsx:19-29`, `mock-data.ts:65-69` | 假设是独立实体，Appointment 通过 `leadId` 与 Lead 关联，提交预约后自动将 Lead 状态更新为"已预约" | 影响 Appointment 表设计和 Lead 状态流转逻辑 |
| 2 | **预约提交是否要求用户已登录？** 当前表单无登录验证，允许匿名用户提交（只要有姓名+手机号），但提交成功页有"查看我的预约"入口暗示需要用户身份 | `appointment/page.tsx:50-75` | 假设允许未登录提交（门槛低，有利于转化），但提交后通过手机号关联已有用户；若无对应用户则作为匿名线索 | 影响 `POST /api/appointments` 的认证逻辑和 Lead 自动生成规则 |
| 3 | **`leads.level` 是系统自动计算还是人工设置？** Mock 中有"强意向线索"、"潜在线索"两个值，对应 `score >= 100` 的颜色高亮逻辑，但没有明确的分级规则定义 | `mock-data.ts:66-69`, `leads/page.tsx:11-15` | 假设由系统根据 `score` 自动计算（如 `score >= 100` → 强意向，`score >= 70` → 高意向，`score >= 40` → 潜在线索，其余 → 普通用户），且人工可覆写 | 影响 Lead 生成时的分级逻辑和 `level` 字段是否持久化 |
| 4 | **`leads.score` 意向分的计算规则和上限是多少？** Mock 中出现 `118`、`132`、`58` 三个值，均超过 100，`score >= 100` 触发"hot-score"样式，但无明确说明分值区间和维度权重 | `mock-data.ts:66-69`, `leads/page.tsx:70` | 假设意向分无上限（各维度独立加分），`100` 为视觉高亮阈值而非满分；具体维度和权重需产品定义 | 影响 Lead 生成时的评分算法设计 |
| 5 | **预约的 `topic` 枚举是否需要与后台线索标签体系对齐？** 落地页预约表单有 8 个 topic，后台线索有 `tags` 字段（如"公转私"、"发票风险"），两者含义有重叠但取值不一致 | `appointment/page.tsx:14`, `mock-data.ts:66-69` | 假设 topic 是预约层面的分类（用于顾问初步判断），tags 是运营层面的细粒度标签，两者独立存在但提交预约时可据 topic 自动预填 tags | 影响 Appointment 和 Lead 的标签体系设计 |
| 6 | **后台管理系统是否需要独立的"预约管理"页面，还是在线索详情页内展示？** 当前 CLAUDE.md 中无"预约管理"路由，用户详情页的"预约记录"标签页为硬编码字符串 | `app/users/[id]/page.tsx:61`（用户管理审计）, `CLAUDE.md` | 假设不需要独立预约管理页，预约信息在对应线索详情抽屉（`卡片 2 来源信息` 或新增卡片）和用户详情页"预约记录"标签页内展示 | 影响 admin-system 路由规划和 Appointment 查询 API 设计 |

---

**高风险不一致项汇总（需优先处理）**：

1. 预约表单提交无 API 调用，数据完全不落库——转化漏斗的最终环节断路，当前任何预约操作均无效。
2. Lead 通过 `name` 字符串关联 User / Report / QaRecord（3 处）——同名用户必然导致数据混乱，必须改为 `userId` 外键。
3. `leads.activity` 存活动名称字符串、`leads.qr` 混用 inviteCode 和 ID——活动改名或二维码 ID 重构后数据断裂，且当前 ID 与 inviteCode 不一致已导致关联逻辑模糊。
4. `LeadStatus` 枚举缺少"未生成"值——影响用户列表统计和线索列表过滤逻辑，接入真实数据后必然报错（此项与用户管理审计 P0 重叠，两个模块联动修复）。
5. 预约表单与用户身份完全解耦——提交预约无法自动关联已有用户，管理后台永远无法将预约与线索关联，两端数据孤立。
