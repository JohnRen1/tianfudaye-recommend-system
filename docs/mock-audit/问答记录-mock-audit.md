# AI 问答记录模块 Mock 数据审计报告

**审计日期**：2026-06-10
**审计员**：mock-auditor agent
**项目阶段**：MVP 原型阶段，无真实数据库和身份认证
**关联报告**：`docs/mock-audit/用户管理-mock-audit.md`

---

## 1. 审计范围

| 系统 | 文件路径 | 页面 / 用途 |
|------|----------|-------------|
| admin-system | `拓客系统-管理后台/app/qa-records/page.tsx` | 问答记录管理（列表 + 抽屉详情） |
| admin-system | `拓客系统-管理后台/lib/mock-data.ts` | `qaRecords` 数组、`RiskLevel` 类型、`users` 数组、`activities` 数组 |
| admin-system | `拓客系统-管理后台/lib/ui.ts` | `riskTheme()` 工具函数 |
| landing-page | `拓客系统-落地页/app/tax-ai/page.tsx` | AI 问答助手页入口（仅壳） |
| landing-page | `拓客系统-落地页/components/mobile/tax-ai-assistant-page.tsx` | AI 问答助手页核心组件（交互、消息渲染、风险判定） |

审计**不涉及**以下文件（属于其他模块）：
- `app/users/[id]/page.tsx`（用户详情标签页内嵌问答记录，已在用户管理审计中记录）
- `components/mobile/login-modal.tsx`（仅登录触发器，与问答业务无关）

---

## 2. Mock 来源清单

| 来源类型 | 文件 | 系统 | 页面 | 具体内容 | 证据位置 |
|----------|------|------|------|----------|----------|
| 硬编码对象数组 | `lib/mock-data.ts` | admin | 问答记录列表 / 详情 | `qaRecords` 数组，3 条问答记录 | `mock-data.ts:53-57` |
| 硬编码类型定义 | `lib/mock-data.ts` | admin | 全局 | `RiskLevel` 联合类型：`'低风险' \| '中风险' \| '高风险' \| '严重风险'` | `mock-data.ts:1` |
| 跨模块依赖（只读） | `lib/mock-data.ts` | admin | 问答记录筛选下拉 | `activities` 数组，动态填充"来源活动"筛选项 | `mock-data.ts:28-33`，`qa-records/page.tsx:48` |
| 跨模块依赖（字符串匹配） | `lib/mock-data.ts` | admin | 详情抽屉底部操作 | `users` 数组，用 `user.name === current.user` 找 `user.id` 以拼接跳转链接 | `mock-data.ts:35-41`，`qa-records/page.tsx:32` |
| 写死统计逻辑 | `qa-records/page.tsx` | admin | 概览卡片 | `qaRecords.reduce(...)` 遍历全量数组计算 `total`、`highRisk`（`risk === '高风险' \| '严重风险'`）、`manual`（`manual === true`） | `qa-records/page.tsx:16-25` |
| 写死分页总数 | `qa-records/page.tsx` | admin | 表格分页 | `total: qaRecords.length`（固定为 3） | `qa-records/page.tsx:65` |
| 写死免责声明文本 | `qa-records/page.tsx` | admin | 详情抽屉 AI 回答 | `不承诺节税效果，不输出违法避税建议，不替代正式税务意见。` 硬编码字符串 | `qa-records/page.tsx:82` |
| 内联硬编码字符串 | `qa-records/page.tsx` | admin | 详情抽屉人工顾问建议 | `manual` 为 `true` 时展示 `建议转人工，由税务顾问结合企业资料进行专项诊断。`，否则展示 `暂不强制转人工，可继续通过资料和 FAQ 引导。` | `qa-records/page.tsx:77` |
| 写死筛选项枚举 | `qa-records/page.tsx` | admin | 筛选栏 | 风险等级下拉选项 `全部 / 高风险 / 中风险`（不含`严重风险` / `低风险`）；是否转人工下拉 `all / yes / no` | `qa-records/page.tsx:46-47` |
| 纯客户端关键词匹配 | `tax-ai-assistant-page.tsx` | landing | AI 问答助手 | `buildAiAnswer()` 函数通过关键词数组判断风险等级，完全在前端运行，无 API 调用 | `tax-ai-assistant-page.tsx:28-62` |
| 模拟异步延迟 | `tax-ai-assistant-page.tsx` | landing | AI 问答助手 | `window.setTimeout(resolve, 1100)` 模拟 AI 思考时间 | `tax-ai-assistant-page.tsx:110` |
| 客户端状态（无持久化） | `tax-ai-assistant-page.tsx` | landing | AI 问答助手 | `messages` 状态仅存在于当前页面 React state，刷新或离开即丢失，无任何存储 | `tax-ai-assistant-page.tsx:101` |
| 硬编码快捷问题 | `tax-ai-assistant-page.tsx` | landing | AI 问答助手 | `quickQuestions` 数组：4 条固定问题 | `tax-ai-assistant-page.tsx:25` |
| 硬编码免责声明文本 | `tax-ai-assistant-page.tsx` | landing | AI 问答助手 | `disclaimer` 常量 | `tax-ai-assistant-page.tsx:26` |
| 硬编码高风险关键词 | `tax-ai-assistant-page.tsx` | landing | AI 问答助手 | `['稽查', '虚开发票', '虚开', '公转私', '大额', '检查通知', '税务检查']` | `tax-ai-assistant-page.tsx:29` |
| 硬编码中风险关键词 | `tax-ai-assistant-page.tsx` | landing | AI 问答助手 | `['零申报', '发票', '扣除', '补税']` | `tax-ai-assistant-page.tsx:30` |
| 临时登录状态 | `tax-ai-assistant-page.tsx` | landing | AI 问答助手 | `isLoggedIn` 本地 state，登录弹窗 `onSuccess` 后置为 `true`，刷新后归零 | `tax-ai-assistant-page.tsx:97` |

---

## 3. 页面数据需求

### 3.1 管理后台 — 问答记录列表页（`qa-records/page.tsx`）

**概览统计卡片（3 张）**

| 指标 | 计算方式 | 字段依赖 | 证据 |
|------|----------|----------|------|
| 问答总数 | `qaRecords.length` | 无（count） | `page.tsx:19` |
| 高风险问答数 | `risk === '高风险' \| '严重风险'` | `risk: RiskLevel` | `page.tsx:20` |
| 建议转人工数 | `manual === true` | `manual: boolean` | `page.tsx:21` |

**筛选条件**

| 筛选项 | 控件类型 | 数据来源 | 字段依赖 | 证据 |
|--------|----------|----------|----------|------|
| 用户搜索 | Input | 用户输入 | `user` / `phone` | `page.tsx:44` |
| 问题关键词搜索 | Input | 用户输入 | `summary` / `originalQuestion` | `page.tsx:45` |
| 风险等级筛选 | Select | 页面硬编码 | `risk` | `page.tsx:46` |
| 是否转人工 | Select | 页面硬编码 | `manual` | `page.tsx:47` |
| 来源活动 | Select | `activities` 数组动态生成 | `activity` / `activities.name` | `page.tsx:48` |
| 提问时间区间 | DateRangePicker | 用户输入 | `time` | `page.tsx:49` |

**列表表格（8 列实际渲染）**

| 列 | 字段 | 类型 | 证据 |
|----|------|------|------|
| 用户姓名 | `user` | `string` | `page.tsx:56` |
| 手机号 | `phone` | `string` | `page.tsx:57` |
| 问题摘要 | `summary` | `string` | `page.tsx:58` |
| 问题标签 | `tags` | `string[]` | `page.tsx:58`（摘要列副文本） |
| 问题类型 | `type` | `string` | `page.tsx:59` |
| 风险等级 | `risk` | `RiskLevel` | `page.tsx:60` |
| 是否建议转人工 | `manual` | `boolean` | `page.tsx:61` |
| 来源活动 | `activity` | `string` | `page.tsx:62` |
| 提问时间 | `time` | `string` | `page.tsx:63` |
| 行 key | `id` | `string` | `page.tsx:55` |

**行操作**：查看详情（打开 Drawer）、生成线索（`MessagePlugin.success` 占位）、分配顾问（`MessagePlugin.success` 占位）。

### 3.2 管理后台 — 问答详情抽屉（`qa-records/page.tsx` Drawer）

**高风险提醒 Banner**

| 渲染条件 | 字段依赖 | 证据 |
|----------|----------|------|
| `risk === '高风险' \| '严重风险'` | `risk`, `type` | `page.tsx:69` |

**用户问题原文**

| 数据项 | 字段 | 证据 |
|--------|------|------|
| 问题原文 | `originalQuestion` | `page.tsx:70` |

**AI 回答全文（5 个固定 section）**

| section 标题 | 字段 | 渲染方式 | 证据 |
|-------------|------|----------|------|
| 问题理解 | `understanding` | 直接文本 | `page.tsx:73` |
| 初步判断 | `judgment` | 直接文本 | `page.tsx:74` |
| 涉及风险 | `risks` | 直接文本 | `page.tsx:75` |
| 处理建议 | `suggestion` | 直接文本 | `page.tsx:76` |
| 人工顾问建议 | `manual`（boolean） | 条件渲染硬编码文案 | `page.tsx:77` |
| 免责声明 | 无字段（硬编码） | 固定字符串 | `page.tsx:78` |

**记录信息（Descriptions）**

| 标签 | 字段 | 类型 | 证据 |
|------|------|------|------|
| 风险等级 | `risk` | `RiskLevel` | `page.tsx:82` |
| 标签 | `tags` | `string[]` | `page.tsx:82` |
| 是否建议转人工 | `manual` | `boolean` | `page.tsx:82` |
| 来源活动 | `activity` | `string` | `page.tsx:82` |
| 免责声明 | 无字段（硬编码） | — | `page.tsx:82` |

**底部操作**

| 操作 | 实现方式 | 所需数据 | 证据 |
|------|----------|----------|------|
| 生成线索 | 占位（无 API） | `id` | `page.tsx:84` |
| 分配顾问 | 占位（无 API） | `id` | `page.tsx:84` |
| 查看用户详情 | `Link href="/users/${user.id}"` | `current.user` → `users.find(name 匹配)` → `user.id` | `page.tsx:32, 84` |

### 3.3 落地页 — AI 问答助手页（`tax-ai-assistant-page.tsx`）

**聊天消息列表**

| 消息类型 | 渲染内容 | 字段来源 | 证据 |
|----------|----------|----------|------|
| 用户消息（`role: "user"`） | `content: string` | 用户输入 | `page.tsx:106-107` |
| AI 回答（`role: "ai"`） | `AiAnswer` 对象 | `buildAiAnswer()` 客户端生成 | `page.tsx:111` |

**AiAnswer 对象（客户端本地类型，当前无持久化）**

| 字段 | 类型 | 用途 | 证据 |
|------|------|------|------|
| `questionUnderstanding` | `string` | 渲染"问题理解" section | `tax-ai-assistant-page.tsx:81` |
| `initialJudgment` | `string` | 渲染"初步判断" section | `tax-ai-assistant-page.tsx:82` |
| `involvedRisks` | `string[]` | 渲染"涉及风险"列表 | `tax-ai-assistant-page.tsx:83` |
| `suggestions` | `string[]` | 渲染"处理建议"列表 | `tax-ai-assistant-page.tsx:84` |
| `riskLevel` | `"medium" \| "high" \| "uncertain"` | 渲染风险等级 Badge；条件显示"预约顾问"按钮 | `tax-ai-assistant-page.tsx:71,78,87` |
| `advisorRecommended` | `boolean` | 渲染"是否建议人工顾问介入"文本 | `tax-ai-assistant-page.tsx:85` |
| `uncertain` | `boolean` | 渲染黄色"建议结合实际确认"提示 | `tax-ai-assistant-page.tsx:86` |

**页面其他前端状态（均不持久化）**

| 状态 | 类型 | 用途 | 证据 |
|------|------|------|------|
| `isLoggedIn` | `boolean` | 控制是否弹出登录框 | `tax-ai-assistant-page.tsx:97` |
| `showLoginModal` | `boolean` | 控制 LoginModal 显示 | `tax-ai-assistant-page.tsx:98` |
| `inputValue` | `string` | 输入框受控值 | `tax-ai-assistant-page.tsx:99` |
| `isThinking` | `boolean` | 控制 loading 态和按钮禁用 | `tax-ai-assistant-page.tsx:100` |
| `messages` | `ChatMessage[]` | 当前会话消息列表 | `tax-ai-assistant-page.tsx:101` |

---

## 4. 业务实体和字段

### 4.1 问答记录（QaRecord）— 核心实体

#### 数据库实体（需持久化）

| 字段 | Mock 字段名 | 类型 | 分类 | 是否页面使用 | 证据位置 |
|------|-------------|------|------|-------------|----------|
| 主键 | `id` | `string`（`Q001` 格式，应改 uuid） | 持久化（主键） | 是（`rowKey="id"`） | `mock-data.ts:54`，`page.tsx:55` |
| 用户外键 | `user`（字符串姓名） | `string`（应为 `userId: uuid`） | 关联字段 | 是（列表显示，详情跳转） | `mock-data.ts:54`，`page.tsx:32,56` |
| 用户手机号冗余 | `phone` | `string` | 持久化（冗余/展示） | 是（列表列） | `mock-data.ts:54`，`page.tsx:57` |
| 问题摘要 | `summary` | `string` | 持久化 | 是（列表列主文本） | `mock-data.ts:54`，`page.tsx:58` |
| 问题原文 | `originalQuestion` | `string` | 持久化 | 是（详情抽屉） | `mock-data.ts:54`，`page.tsx:70` |
| 问题类型 | `type` | `string` | 持久化 | 是（列表列 Tag，详情高风险 Banner） | `mock-data.ts:54`，`page.tsx:59,69` |
| 风险等级 | `risk` | `RiskLevel` 枚举 | 持久化（AI 或人工判定） | 是（列表 Tag，详情 Banner/Descriptions） | `mock-data.ts:54`，`page.tsx:60,69,82` |
| 是否建议转人工 | `manual` | `boolean` | 持久化（AI 判定） | 是（统计卡片，列表列，详情 section） | `mock-data.ts:54`，`page.tsx:21,61,77,82` |
| 来源活动 | `activity` | `string`（活动名称，应为 `activityId`） | 关联字段 | 是（列表列，详情 Descriptions） | `mock-data.ts:54`，`page.tsx:62,82` |
| 提问时间 | `time` | `string`（应为 `timestamp`） | 持久化（系统自动） | 是（列表列） | `mock-data.ts:54`，`page.tsx:63` |
| 标签 | `tags` | `string[]` | 持久化（AI 自动打标） | 是（列表摘要副文本，详情 Descriptions） | `mock-data.ts:54`，`page.tsx:58,82` |
| AI 问题理解 | `understanding` | `string` | 持久化（AI 生成） | 是（详情抽屉） | `mock-data.ts:54`，`page.tsx:73` |
| AI 初步判断 | `judgment` | `string` | 持久化（AI 生成） | 是（详情抽屉） | `mock-data.ts:54`，`page.tsx:74` |
| AI 涉及风险描述 | `risks` | `string` | 持久化（AI 生成） | 是（详情抽屉） | `mock-data.ts:54`，`page.tsx:75` |
| AI 处理建议 | `suggestion` | `string` | 持久化（AI 生成） | 是（详情抽屉） | `mock-data.ts:54`，`page.tsx:76` |

#### Mock 中存在但页面未使用的字段

当前 `qaRecords` 数组中所有字段均在 `qa-records/page.tsx` 中被实际使用，无冗余字段。

#### 列表 DTO（用于问答记录列表表格）

`id`, `user`, `phone`, `summary`, `tags`, `type`, `risk`, `manual`, `activity`, `time`

#### 详情 DTO（用于抽屉详情）

列表 DTO 全部字段 + `originalQuestion`, `understanding`, `judgment`, `risks`, `suggestion`

#### 数据库实体（最终持久化，与列表/详情 DTO 的差异）

- `id` 应改为 `uuid`，`Q001` 格式仅供 Mock
- `user` 字段应替换为 `user_id uuid REFERENCES users(id)`，`user`（姓名）和 `phone` 应作为展示时的 JOIN 字段，不直接持久化在问答记录表
- `activity` 字段应替换为 `activity_id uuid REFERENCES activities(id)`
- `risks` 在 admin Mock 中是 `string`（单段文本），但落地页 `AiAnswer.involvedRisks` 是 `string[]`（数组），存储格式需统一（见第 7 节）
- `suggestion` 在 admin Mock 中是 `string`，但落地页 `AiAnswer.suggestions` 是 `string[]`，同上

---

### 4.2 落地页 AI 回答（AiAnswer）— 当前纯前端类型，未持久化

此类型定义在 `tax-ai-assistant-page.tsx:15-23`，与 admin `qaRecords` 中的 AI 回答字段存在结构性差异，是本次审计最关键的不一致项。

| 落地页字段 | 类型 | admin 对应字段 | 类型 | 差异 |
|------------|------|---------------|------|------|
| `questionUnderstanding` | `string` | `understanding` | `string` | 字段名不同，内容语义相同 |
| `initialJudgment` | `string` | `judgment` | `string` | 字段名不同，内容语义相同 |
| `involvedRisks` | `string[]` | `risks` | `string` | 类型不同：数组 vs 单字符串 |
| `suggestions` | `string[]` | `suggestion` | `string` | 类型不同：数组 vs 单字符串，字段名也不同 |
| `riskLevel` | `"medium" \| "high" \| "uncertain"` | `risk` | `RiskLevel`（`'低风险' \| '中风险' \| '高风险' \| '严重风险'`） | 枚举体系完全不同（英文 vs 中文，`uncertain` 在 admin 枚举中不存在） |
| `advisorRecommended` | `boolean` | `manual` | `boolean` | 字段名不同，语义基本相同（建议转人工 ≈ 建议顾问介入） |
| `uncertain` | `boolean` | 无对应字段 | — | admin 无此字段，落地页用于显示黄色提示 |

---

### 4.3 知识库（KnowledgeItem）— 间接关联

落地页 AI 问答页头部 Badge 显示"知识库"标识，页面文案为"基于财税知识库"，但当前 `buildAiAnswer()` 完全是本地关键词匹配，**未实际调用知识库**。`knowledgeItems` 数组存在于 `mock-data.ts:87-92`，但在 `qa-records/page.tsx` 中未被引用。知识库关联是未来 AI 接入时的核心依赖，记录为不确定项（见第 11 节）。

---

## 5. 页面操作

### 5.1 管理后台 — 问答记录页

| 操作 | 触发元素 | 当前实现方式 | 需要的 API | 证据 |
|------|----------|-------------|------------|------|
| 搜索用户 | 用户搜索 Input | 无过滤逻辑（组件未受控绑定） | `GET /api/qa-records?user=&phone=` | `page.tsx:44` |
| 关键词搜索 | 问题关键词 Input | 无过滤逻辑 | `GET /api/qa-records?keyword=` | `page.tsx:45` |
| 风险等级筛选 | Select | `value="all"` 写死，无 onChange | `GET /api/qa-records?risk=` | `page.tsx:46` |
| 是否转人工筛选 | Select | `value="all"` 写死，无 onChange | `GET /api/qa-records?manual=` | `page.tsx:47` |
| 来源活动筛选 | Select | `value="all"` 写死，无 onChange | `GET /api/qa-records?activity=` | `page.tsx:48` |
| 时间区间筛选 | DateRangePicker | 无受控绑定 | `GET /api/qa-records?from=&to=` | `page.tsx:49` |
| 查询 | 查询按钮 | 无 onClick | 同上组合查询 | `page.tsx:51` |
| 重置 | 重置按钮 | 无 onClick | — | `page.tsx:51` |
| 查看详情 | 行操作"查看详情" | 打开 Drawer，渲染 `current` 记录 | 可用客户端状态，但生产应加载完整 DTO | `page.tsx:27-29,64` |
| 生成线索 | 行"更多"操作 | `MessagePlugin.success('线索已生成')` 占位 | `POST /api/leads`（关联 `qaRecord.id`） | `page.tsx:64` |
| 分配顾问 | 行"更多"操作 | `MessagePlugin.success('已分配顾问')` 占位 | `POST /api/leads/:id/assign` 或 `PATCH /api/qa-records/:id/advisor` | `page.tsx:64` |
| 批量生成线索 | 卡片头部按钮 | 无 onClick | `POST /api/leads/batch` | `page.tsx:54` |
| 导出记录 | 卡片头部按钮 | 无 onClick | `GET /api/qa-records/export` | `page.tsx:54` |
| 查看用户详情 | 详情抽屉底部按钮 | `Link href="/users/${user.id}"` | `GET /api/users/:id`（已在用户管理审计中） | `page.tsx:84` |

### 5.2 落地页 — AI 问答助手页

| 操作 | 触发元素 | 当前实现方式 | 需要的 API | 证据 |
|------|----------|-------------|------------|------|
| 提交问题 | 发送按钮 / Enter 键 | `window.setTimeout(1100)` 后客户端生成答案 | `POST /api/ai/chat` | `tax-ai-assistant-page.tsx:103-112` |
| 快捷问题 | 快捷问题按钮 | 复用 `submitQuestion()` | 同上 | `tax-ai-assistant-page.tsx:119` |
| 输入框聚焦 | Input `onFocus` | 触发 `requireLogin()` 检查登录状态 | — | `tax-ai-assistant-page.tsx:121` |
| 预约顾问（高风险） | 高风险回答内"预约顾问解读"按钮 | `requireLogin()` 检查后跳转（当前仅触发登录弹窗） | 跳转预约页 / `POST /api/appointments` | `tax-ai-assistant-page.tsx:87` |
| 查看相关资料（高风险） | 高风险回答内"查看相关资料"按钮 | `requireLogin()` 检查后跳转（当前仅触发登录弹窗） | 跳转资料页 / `GET /api/materials?topic=` | `tax-ai-assistant-page.tsx:87` |
| 登录 | LoginModal | 登录成功后 `setIsLoggedIn(true)` | `POST /api/auth/login-phone`（见用户管理审计） | `tax-ai-assistant-page.tsx:102,123` |
| 返回首页 | 返回按钮 | `router.push("/")` | — | `tax-ai-assistant-page.tsx:116` |

---

## 6. 建议 API

### 6.1 落地页 — AI 问答（landing-page）

| 方法 | 路径 | 请求体 | 响应 | 备注 |
|------|------|--------|------|------|
| `POST` | `/api/ai/chat` | `{ question: string, userId?: string, sessionId?: string }` | `{ answer: AiAnswerDTO, recordId: string }` | 需要身份校验；`sessionId` 用于多轮上下文（如接入真实 LLM） |
| `GET` | `/api/ai/history` | Header: Bearer token | `{ records: QaRecordListDTO[] }` | 获取当前用户历史问答，落地页可选展示 |

`AiAnswerDTO`（建议统一结构，解决第 7 节冲突）：

```typescript
interface AiAnswerDTO {
  questionUnderstanding: string;   // 对应 admin: understanding
  initialJudgment: string;         // 对应 admin: judgment
  involvedRisks: string[];         // 对应 admin: risks（改为数组）
  suggestions: string[];           // 对应 admin: suggestion（改为数组）
  riskLevel: 'low' | 'medium' | 'high' | 'critical';  // 统一英文枚举，前端各自映射展示文案
  advisorRecommended: boolean;     // 对应 admin: manual
  uncertain: boolean;              // admin 新增字段
}
```

### 6.2 管理后台 — 问答记录（admin-system）

| 方法 | 路径 | 参数 | 响应 | 备注 |
|------|------|------|------|------|
| `GET` | `/api/qa-records` | `user`, `phone`, `keyword`, `risk`, `manual`, `activity`, `from`, `to`, `page`, `pageSize` | `{ items: QaRecordListDTO[], total: number, summary: { total, highRisk, manual } }` | summary 由后端计算，不依赖前端遍历全量 |
| `GET` | `/api/qa-records/:id` | — | `QaRecordDetailDTO` | 返回完整 AI 回答字段 |
| `POST` | `/api/leads` | `{ qaRecordId: string, userId: string }` | `LeadDTO` | 从问答记录生成线索 |
| `PATCH` | `/api/qa-records/:id/advisor` | `{ advisorId: string }` | `{ success: boolean }` | 分配顾问（或复用 leads assign 接口） |
| `GET` | `/api/qa-records/export` | 同筛选参数 | CSV / XLSX 文件流 | 需角色权限校验 |
| `POST` | `/api/leads/batch` | `{ qaRecordIds: string[] }` | `{ created: number, leads: LeadDTO[] }` | 批量生成线索 |

---

## 7. 字段和类型冲突

| # | 冲突描述 | 文件 A | 文件 B | 字段 | 风险等级 |
|---|----------|--------|--------|------|----------|
| 1 | **风险等级枚举体系完全不同**：落地页 `RiskLevel = "medium" \| "high" \| "uncertain"` 为英文三值枚举；admin `RiskLevel = '低风险' \| '中风险' \| '高风险' \| '严重风险'` 为中文四值枚举；`"uncertain"`（结合实际确认）在 admin 枚举中**完全不存在** | `tax-ai-assistant-page.tsx:13` | `mock-data.ts:1` | `riskLevel` vs `risk` | **高风险** |
| 2 | **涉及风险字段类型不同**：落地页 `involvedRisks: string[]`（数组，用于列表渲染）；admin `risks: string`（单段文本，用于直接展示）；存储时无法互通，后端必须选定一种格式 | `tax-ai-assistant-page.tsx:18` | `mock-data.ts:54` | `involvedRisks` vs `risks` | **高风险** |
| 3 | **处理建议字段类型和名称均不同**：落地页 `suggestions: string[]`（数组）；admin `suggestion: string`（字符串，单数）；字段名称也不一致（`suggestions` vs `suggestion`） | `tax-ai-assistant-page.tsx:19` | `mock-data.ts:54` | `suggestions` vs `suggestion` | **高风险** |
| 4 | **字段命名风格不一致**：落地页使用 camelCase 全称（`questionUnderstanding`, `initialJudgment`, `advisorRecommended`）；admin Mock 使用缩写（`understanding`, `judgment`, `manual`）；语义相同但名称不同，若共用 API 响应则需要统一 | `tax-ai-assistant-page.tsx:15-22` | `mock-data.ts:54` | 多字段 | 中风险 |
| 5 | **`uncertain` 字段仅存在于落地页**：`AiAnswer.uncertain: boolean` 用于显示"建议结合实际确认"的黄色提示；admin `qaRecords` 中无此字段；若需在 admin 侧展示或过滤"不确定"类回答，当前无数据支撑 | `tax-ai-assistant-page.tsx:22,86` | `mock-data.ts:53-57` | `uncertain` | 中风险 |
| 6 | **`manual` 字段语义在两端略有偏移**：落地页渲染文案为"是否建议人工顾问介入"（`advisorRecommended`）；admin 渲染文案为"是否建议转人工"（`manual`），列表列标题为"是否建议转人工"，详情 section 标题为"人工顾问建议"；语义基本相同但措辞不一致，需统一 API 字段名 | `tax-ai-assistant-page.tsx:85` | `qa-records/page.tsx:61,77` | `advisorRecommended` vs `manual` | 中风险 |
| 7 | **来源活动关联方式不一致**：`qaRecords.activity` 存的是活动名称字符串（如 `'金税四期风险识别专题课'`），筛选下拉也以名称作为 `value`（`page.tsx:48`）；`activities` 有唯一 `id`（如 `A001`），活动改名将导致关联断裂 | `mock-data.ts:54` | `mock-data.ts:28-33`，`page.tsx:48` | `activity` vs `activities.name` / `activities.id` | 中风险（与用户管理审计第 9 项一致） |
| 8 | **用户关联方式沿用字符串姓名**：`current.user`（字符串姓名）通过 `users.find(item => item.name === current.user)` 查找 `user.id` 以生成跳转链接；与用户管理审计高风险项 1 相同，问答记录中同样存在此问题 | `qa-records/page.tsx:32` | `mock-data.ts:35-41,53-57` | `user`（字符串）vs `user.id` | **高风险**（继承用户管理审计高风险项 1） |
| 9 | **admin 筛选 Select 风险等级选项不完整**：筛选下拉仅有 `全部风险 / 高风险 / 中风险` 三个选项，但 `RiskLevel` 枚举有四个值（含 `低风险` 和 `严重风险`）；`严重风险`在统计卡片中被计入高风险，但在筛选中无法单独过滤 | `qa-records/page.tsx:46` | `mock-data.ts:1` | `risk` 筛选项 vs `RiskLevel` 枚举 | 中风险 |

---

## 8. 页面状态缺口

| # | 缺口描述 | 页面 / 系统 | 当前状态 | 接入真实 API 后的影响 |
|---|----------|-------------|----------|----------------------|
| 1 | **所有筛选条件均无效**：风险/是否转人工/来源活动 Select 的 `value` 均写死为 `"all"`，无 `onChange`；两个 Input 无 `onChange`；DateRangePicker 无受控绑定；查询和重置按钮无 `onClick` | admin 问答记录列表 | 筛选完全无效，始终展示全量 3 条 | 需绑定所有筛选项状态并实现查询逻辑 |
| 2 | **AI 问答无持久化**：落地页 `messages` 仅存在于 React state，刷新、切页、重新打开全部丢失；`qaRecords` 中的数据与落地页实际问答完全脱节，没有任何写入路径 | landing AI 问答 | 落地页发生的问答不会产生任何 admin 侧可见的记录 | 需要 `POST /api/ai/chat` 接口在服务端落库，admin 才能看到真实记录 |
| 3 | **生成线索 / 分配顾问操作为占位**：`MessagePlugin.success()` 仅给出成功提示，无实际 API 调用，线索数据不会产生，操作结果无法回显 | admin 问答记录行操作 | 点击后假装成功，无数据变化 | 需实现 `POST /api/leads` 和顾问分配接口 |
| 4 | **批量生成线索 / 导出记录按钮无实现**：按钮渲染但无 `onClick` | admin 问答记录卡片头部 | 点击无响应 | 需实现批量操作和导出接口 |
| 5 | **概览统计卡片依赖全量前端遍历**：`summary` 由 `useMemo` 对 `qaRecords` 做 `reduce` 计算，真实接入后必须改为后端聚合查询返回；否则前端需要加载所有记录才能渲染统计 | admin 问答记录概览 | 当前固定为 3 条数据，无感知 | 建议后端在列表 API 响应中附带 `summary` 字段 |
| 6 | **落地页登录状态无持久化**：`isLoggedIn` 是本地 state，刷新归零；用户提问后刷新页面，需重新登录才能继续提问 | landing AI 问答 | 体验缺口，关闭页面后登录状态丢失 | 依赖用户管理审计中的 session 持久化方案（P0 优先级） |
| 7 | **高风险回答的"预约顾问"和"查看相关资料"按钮均触发登录弹窗而非实际跳转**：`onProtectedClick` 调用 `requireLogin()`，登录成功后并没有后续跳转逻辑 | landing AI 问答（高风险回答 Card） | 登录成功后无任何跳转，用户体验断裂 | 需在登录成功回调中补充跳转目标逻辑 |
| 8 | **落地页风险等级 `"uncertain"` 无法映射到 admin `RiskLevel` 枚举**：如果落地页生成的回答风险级别为 `"uncertain"`，存入数据库时无对应值，除非新增枚举值或映射规则 | 两端 | Mock 阶段不暴露，真实接入后会报类型错误 | 需在 API 设计阶段统一枚举（见第 6 节 `AiAnswerDTO` 建议） |
| 9 | **知识库引用未实现**：落地页头部 Badge 显示"知识库"标识，文案提到"基于财税知识库"，但 `buildAiAnswer()` 是纯关键词匹配，与 `knowledgeItems` 完全无关，无任何知识库检索 | landing AI 问答 | UI 声称有知识库但实际无，存在用户预期与实际不符 | 接入真实 AI 时需实现 RAG 检索，`qa_records` 表中应记录引用的知识库条目 ID |

---

## 9. 共用模型

以下模型在两个系统中均涉及，需在 API 设计阶段统一：

| 实体 | landing-page 视角 | admin-system 视角 | 共同字段（建议） | 冲突字段 |
|------|-------------------|-------------------|-----------------|----------|
| QaRecord | 写入方（用户提问 → AI 回答 → 调用 API 存储） | 只读方（展示、筛选、生成线索） | `id`, `userId`, `originalQuestion`, `riskLevel`, `advisorRecommended`, `time` | `involvedRisks`（数组 vs 字符串）、`suggestions`（数组 vs 字符串）、`riskLevel` 枚举值 |
| RiskLevel | 英文三值：`medium / high / uncertain` | 中文四值：`低风险 / 中风险 / 高风险 / 严重风险` | 建议统一为英文四值：`low / medium / high / critical`，展示层各自映射文案 | 枚举体系完全不同，`uncertain` 无对应 |
| Activity | 仅在落地页来源追踪中隐式引用（通过 QR Code 的 `inviteCode` 参数关联） | CRUD 主体，`qaRecords.activity` 存活动名称 | `id`, `name` | `qaRecords.activity` 应改为 `activity_id` |
| KnowledgeItem | 未来 AI 回答引用（当前无实现） | 知识库管理页（`knowledge-base/page.tsx`，未在本次审计范围内但间接关联） | `id`, `title`, `version`, `status` | — |

---

## 10. 推荐迁移顺序

| 优先级 | 项目 | 内容 | 原因 |
|--------|------|------|------|
| P0 | 两端 | **统一 `RiskLevel` 枚举**：从两套枚举迁移到统一英文四值枚举 `low / medium / high / critical` | 是所有下游字段（筛选、统计、Badge 颜色）的基础，不统一则 API 无法对接 |
| P0 | 两端 | **统一 `involvedRisks` / `suggestions` 字段为 `string[]`** | 直接影响 AI 回答存储结构，必须在 API 设计前确定 |
| P0 | landing | **实现 `POST /api/ai/chat` 接口**：服务端处理问答并写入 `qa_records` 表 | 落地页当前完全无持久化，admin 看不到任何真实问答数据 |
| P1 | admin | **问答记录列表 API**：实现 `GET /api/qa-records` 含筛选和分页，后端返回 `summary` 聚合数据 | 筛选功能完全无效，统计依赖全量前端遍历 |
| P1 | 两端 | **将 `qaRecords.user` 改为 `user_id` 外键关联**，并修复详情页抽屉的用户跳转逻辑 | 当前字符串姓名匹配存在数据污染风险 |
| P1 | 两端 | **将 `qaRecords.activity` 改为 `activity_id` 外键关联** | 活动改名后关联断裂 |
| P2 | admin | **实现生成线索 / 分配顾问操作**：`POST /api/leads`，`PATCH /api/qa-records/:id/advisor` | 当前为占位，运营核心动作 |
| P2 | landing | **修复高风险回答"预约顾问"按钮的登录后跳转逻辑** | 当前登录成功后无跳转，用户体验断裂 |
| P2 | admin | **在 `RiskLevel` 筛选下拉中补充 `严重风险` 和 `低风险` 选项** | 当前筛选与枚举不一致 |
| P3 | landing | **实现知识库检索（RAG）**，替换 `buildAiAnswer()` 关键词匹配 | UI 已声称"基于知识库"，需要真实 AI 对接 |
| P3 | admin | **实现批量生成线索 / 导出记录** | 运营效率功能，可最后实现 |

---

## 11. 不确定项

| # | 不确定项 | 文件 | 假设 | 影响范围 |
|---|----------|------|------|----------|
| 1 | **落地页 `uncertain` 风险级别是否需要持久化？** `buildAiAnswer()` 的 `uncertain` 分支表示"无法明确判断风险，需结合实际"，在 admin 侧无对应枚举值。若持久化，需新增 `unknown` 枚举值；若不持久化，则问答记录的风险等级可能丢失信息 | `tax-ai-assistant-page.tsx:22`，`mock-data.ts:1` | 假设新增 `unknown` / `uncertain` 枚举值，在 admin 展示为"待确认"，并在统计卡片中单独计数 | 影响 `RiskLevel` 枚举定义、统计卡片计算逻辑、admin 筛选选项 |
| 2 | **AI 回答字段（`understanding`, `judgment`, `risks`, `suggestion`）是否需要支持后续人工修改？** 当前 admin 详情抽屉只读展示，无编辑能力，但顾问可能需要在系统中添加自己的补充意见 | `qa-records/page.tsx:70-79` | 假设先实现只读，后续可在详情抽屉新增"顾问备注"字段（与 AI 生成内容分开存储） | 影响 `qa_records` 表是否需要 `advisor_note` 字段 |
| 3 | **一次用户会话（多轮对话）是否需要关联为同一条 `qa_record`，还是每个问题独立一条记录？** 落地页 `messages` 是多轮对话 state，但 admin `qaRecords` 每条是独立记录（含完整 AI 回答），当前不体现多轮上下文 | `tax-ai-assistant-page.tsx:101-112`，`mock-data.ts:53-57` | 假设每次提问独立一条记录，`sessionId` 字段可选，用于将同一会话的多条记录关联 | 影响 `qa_records` 表是否需要 `session_id` 字段和会话管理逻辑 |
| 4 | **知识库引用关系如何设计？** AI 回答引用了哪些知识库条目（`knowledgeItems`），当前完全无数据；`knowledgeItems.refs` 字段（引用次数，`mock-data.ts:88-92`）暗示知识库记录被引用，但无任何关联表 | `tax-ai-assistant-page.tsx:116`，`mock-data.ts:87-92` | 假设需要 `qa_record_knowledge_refs` 关联表（`qa_record_id`, `knowledge_item_id`），接入 RAG 时填充 | 影响知识库统计（`refs` 字段的真实来源）和 AI 接入架构 |
| 5 | **`tags` 字段在问答记录中是 AI 自动生成还是人工标注，还是两者都有？** `Q001` 的 tags 包含 `['公转私', '资金流水异常', '建议顾问介入']`，前两个看起来是 AI 识别的主题标签，第三个是业务动作建议。admin 页面仅只读展示，无编辑 | `mock-data.ts:54-56` | 假设是 AI 生成，`建议顾问介入` 类标签是基于 `manual === true` 自动追加，不需要单独字段 | 影响 `tags` 字段的生成逻辑设计 |
| 6 | **`summary`（问题摘要）是用户问题原文的截断，还是 AI 生成的摘要？** `Q001` 的 `summary` 与 `originalQuestion` 的前半段完全一致（截断），但 `Q002` 的 `summary` 是重新归纳的语言。两种方式对应不同的处理逻辑 | `mock-data.ts:54-56` | 假设是 AI 生成的摘要（更精炼），`originalQuestion` 始终保留用户完整原文，两者均持久化 | 影响 API 处理逻辑：`summary` 是否需要 AI 额外生成调用 |

---

**高风险不一致项汇总（需优先处理）：**

1. **枚举体系完全不兼容**：落地页 `RiskLevel`（英文三值含 `uncertain`）与 admin `RiskLevel`（中文四值）无法直接映射，`uncertain` 在 admin 无对应值。真实接入后 AI 生成的 `uncertain` 记录将无法存储。
2. **`involvedRisks` / `suggestions` 类型冲突**：落地页为 `string[]`，admin Mock 为 `string`，同一业务字段两种存储结构，必须在 API 设计前统一。
3. **问答记录与用户关联仍使用字符串姓名**：`qa-records/page.tsx:32` 中 `users.find(item => item.name === current.user)` 是与用户管理审计高风险项 1 相同的问题，同名用户将导致跳转到错误的用户详情页。
4. **落地页问答完全无持久化路径**：AI 回答由纯客户端关键词匹配生成，无任何 API 调用，admin 侧的 `qaRecords` 与落地页实际发生的问答在数据上完全断开。
