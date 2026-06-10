# 活动管理模块 Mock 数据审计报告

**审计日期**：2026-06-10
**审计员**：mock-auditor agent
**项目阶段**：MVP 原型阶段，无真实数据库和身份认证
**关联报告**：[用户管理-mock-audit.md](./用户管理-mock-audit.md)

---

## 1. 审计范围

| 系统 | 文件路径 | 页面 / 用途 |
|------|----------|-------------|
| admin-system | `拓客系统-管理后台/app/activities/page.tsx` | 活动列表、新建/编辑活动、二维码弹窗、活动数据抽屉 |
| admin-system | `拓客系统-管理后台/lib/mock-data.ts` | `activities` 数组及类型定义；`funnelData` 全局漏斗数据 |
| admin-system | `拓客系统-管理后台/app/qr-codes/page.tsx` | 二维码管理（通过 `activities` 生成下拉选项，跨实体引用） |
| admin-system | `拓客系统-管理后台/app/materials-admin/page.tsx` | 资料管理（通过 `activities` 生成下拉选项，跨实体引用） |
| admin-system | `拓客系统-管理后台/lib/ui.ts` | `statusTheme()` 工具函数（活动状态驱动展示颜色） |
| landing-page | `拓客系统-落地页/components/mobile/event-landing-page.tsx` | 活动落地页（展示活动信息、关联资料、专属服务入口） |
| landing-page | `拓客系统-落地页/app/page.tsx` | 根路由，直接渲染 `<EventLandingPage />`，无参数传递 |

跨实体关联分析（本报告涉及）：

- `users.sourceActivity` → `activities.name`（用户来源活动，字符串关联）
- `qrCodeItems.activity` → `activities.name`（二维码绑定活动，字符串关联）
- `materialItems.activity` → `activities.name`（资料关联活动，字符串关联）
- `leads.activity` → `activities.name`（线索来源活动，字符串关联）
- `activities.funnelData` → 全局静态数据（活动详情抽屉展示，未按活动 id 过滤）

---

## 2. Mock 来源清单

| 来源类型 | 文件 | 具体内容 | 证据位置 |
|----------|------|----------|----------|
| 硬编码对象数组 | `lib/mock-data.ts` | `activities` 数组，4 条活动记录 | `mock-data.ts:28-33` |
| 硬编码对象数组 | `lib/mock-data.ts` | `funnelData` 数组，8 个漏斗步骤（全局共享，未绑定任何活动 id） | `mock-data.ts:17-26` |
| 硬编码常量对象 | `event-landing-page.tsx` | `defaultEventData` 对象，含 `title`/`speaker`/`speakerTitle`/`date`/`time`/`location`/`description` 7 个字段 | `event-landing-page.tsx:43-51` |
| 硬编码对象数组 | `event-landing-page.tsx` | `materials` 数组，4 条资料记录，含 `id`/`title`/`type`/`size`/`icon`/`downloaded` | `event-landing-page.tsx:53-86` |
| 硬编码下拉选项 | `activities/page.tsx` | `materialOptions` 数组，4 个固定资料选项，值为业务代码（如 `risk-list`） | `activities/page.tsx:11-16` |
| 写死计算逻辑 | `activities/page.tsx` | `Math.round(selectedActivity.register * 0.61)` 固定系数模拟"AI 提问人数"，非真实字段 | `activities/page.tsx:172` |
| 写死分页总数 | `activities/page.tsx` | `total: activities.length`（固定为 4） | `activities/page.tsx:129` |
| 写死邀请码格式 | `activities/page.tsx` | `${selectedActivity.id}-INVITE` 字符串拼接，非数据库字段 | `activities/page.tsx:152` |
| 写死链接格式 | `activities/page.tsx` | `https://m.example.com/event?activity_id=${selectedActivity.id}&invite=${selectedActivity.id}-INVITE` | `activities/page.tsx:155` |
| 写死状态初始值 | `activities/page.tsx` | `useState<Activity>(activities[2])` 默认选中第 3 条（A003） | `activities/page.tsx:22` |
| 仅前端状态 | `event-landing-page.tsx` | `downloadedMaterials` 状态 `useState<number[]>([4])`，模拟已领取第 4 份资料 | `event-landing-page.tsx:96` |
| 全局共享漏斗数据 | `activities/page.tsx` | 活动数据抽屉内渲染 `funnelData`（全局共享，非当前活动的真实漏斗数据） | `activities/page.tsx:180` |

---

## 3. 页面数据需求

### 3.1 活动列表页（`admin-system/app/activities/page.tsx`）

**统计概览卡片（5 张）**

| 指标 | 计算方式 | 字段依赖 | 证据位置 |
|------|----------|----------|----------|
| 活动总数 | `activities.length` | 无（count） | `page.tsx:27` |
| 已上架活动数 | `item.status === '已上架'` 计数 | `status` | `page.tsx:28` |
| 累计扫码人数 | `sum(activities.scan)` | `scan` | `page.tsx:29` |
| 累计注册人数 | `sum(activities.register)` | `register` | `page.tsx:30` |
| 高意向线索总数 | `sum(activities.highIntentLeads)` | `highIntentLeads` | `page.tsx:31` |

注册转化率（`registers/scans * 100%`）在卡片副文字中实时计算展示，不是独立字段。

**筛选条件**

| 筛选项 | 数据来源 | 字段依赖 | 证据位置 |
|--------|----------|----------|----------|
| 活动名称/主题/老师搜索 | 用户输入（文本搜索） | `name`、`theme`、`teacher` | `page.tsx:63` |
| 活动状态 | 硬编码选项：已上架/草稿/已下架 | `status` | `page.tsx:64` |
| 活动时间区间 | DateRangePicker | `time` | `page.tsx:65` |

注：筛选条件目前无过滤逻辑实现，均为占位控件。

**活动列表表格（10 列实际使用）**

| 列 | 字段 | 类型 | 证据位置 |
|----|------|------|----------|
| 活动名称（主） | `name` | `string` | `page.tsx:89` |
| 活动 ID + 创建人（副） | `id`、`creator` | `string` | `page.tsx:90` |
| 活动主题 | `theme` | `string` | `page.tsx:94` |
| 活动时间 | `time` | `string` | `page.tsx:95` |
| 活动地点 | `place` | `string` | `page.tsx:96` |
| 主讲老师 | `teacher` | `string` | `page.tsx:97` |
| 关联资料数 | `materials` | `number` | `page.tsx:98` |
| 活动状态 | `status` | `string`（枚举） | `page.tsx:99` |
| 扫码人数 | `scan` | `number` | `page.tsx:100` |
| 注册人数 | `register` | `number` | `page.tsx:101` |
| 线索数（即高意向线索） | `highIntentLeads` | `number` | `page.tsx:102` |

注：`materialClaims`（资料领取人数）、`assessments`（测评人数）、`appointments`（预约人数）在表格中**未展示**，仅出现在活动数据抽屉。

**新建/编辑活动表单（Dialog）**

| 表单字段 | 数据来源 | 类型 | 证据位置 |
|----------|----------|------|----------|
| 活动名称 | `selectedActivity.name` 填入 defaultValue | `string` | `page.tsx:135` |
| 活动主题 | `selectedActivity.theme` | `string` | `page.tsx:136` |
| 活动时间 | `selectedActivity.time` | `string`（datetime） | `page.tsx:137` |
| 活动地点 | `selectedActivity.place` | `string` | `page.tsx:138` |
| 主讲老师 | `selectedActivity.teacher` | `string` | `page.tsx:139` |
| 活动状态 | `selectedActivity.status`（枚举选择） | `string` | `page.tsx:140` |
| 活动简介 | 无 defaultValue，纯 placeholder | `string` | `page.tsx:141` |
| 活动封面 | Upload 组件，无 defaultValue | `string`（文件 URL） | `page.tsx:142` |
| 关联资料 | 硬编码 `materialOptions`，多选，defaultValue `['risk-list', 'income-tax-check']` | `string[]` | `page.tsx:143` |

注：`description`（活动简介）和 `coverImage`（封面图）在表单中有对应控件，但 mock `activities` 数组中这两个字段**不存在**。这是表单 DTO 比数据实体多出来的字段（当前为纯占位）。

**活动二维码弹窗（Dialog）**

| 展示项 | 数据来源 | 字段 | 证据位置 |
|--------|----------|------|----------|
| 活动名称 | `selectedActivity.name` | `name` | `page.tsx:152` |
| 邀请码 | `${selectedActivity.id}-INVITE`（拼接字符串，非真实字段） | — | `page.tsx:152` |
| 活动状态 | `selectedActivity.status` | `status` | `page.tsx:153` |
| 落地页链接 | `https://m.example.com/event?activity_id=${selectedActivity.id}&invite=${selectedActivity.id}-INVITE` | `id` | `page.tsx:155` |

**活动数据抽屉（Drawer）**

| 展示项 | 数据来源 | 字段 | 证据位置 |
|--------|----------|------|----------|
| 活动名称 | `selectedActivity.name` | `name` | `page.tsx:162` |
| 活动主题 | `selectedActivity.theme` | `theme` | `page.tsx:163` |
| 活动时间 | `selectedActivity.time` | `time` | `page.tsx:163` |
| 活动地点 | `selectedActivity.place` | `place` | `page.tsx:163` |
| 活动状态 | `selectedActivity.status` | `status` | `page.tsx:166` |
| 扫码人数 | `selectedActivity.scan` | `scan` | `page.tsx:169` |
| 注册人数 | `selectedActivity.register` | `register` | `page.tsx:170` |
| 资料领取 | `selectedActivity.materialClaims` | `materialClaims` | `page.tsx:171` |
| AI 提问（计算值） | `Math.round(selectedActivity.register * 0.61)` | 无真实字段，写死系数 | `page.tsx:172` |
| 测评人数 | `selectedActivity.assessments` | `assessments` | `page.tsx:173` |
| 预约人数 | `selectedActivity.appointments` | `appointments` | `page.tsx:174` |
| 高意向线索 | `selectedActivity.highIntentLeads` | `highIntentLeads` | `page.tsx:175` |
| 注册转化率 | `register / scan * 100`（前端计算） | 展示字段 | `page.tsx:48` |
| 转化漏斗图 | `funnelData`（全局共享，非当前活动） | — | `page.tsx:180` |
| 运营洞察 | `conversionRate`、`leadRate`、`selectedActivity.materials` | 展示字段 | `page.tsx:185-187` |

### 3.2 落地页活动展示（`landing-page/components/mobile/event-landing-page.tsx`）

**活动封面区（顶部渐变区域）**

| 展示项 | 数据来源 | 字段 | 证据位置 |
|--------|----------|------|----------|
| 活动标题 | `eventData.title` | `title` | `event-landing-page.tsx:138` |
| 主讲人姓名 | `eventData.speaker` | `speaker` | `event-landing-page.tsx:145` |
| 主讲人职称 | `eventData.speakerTitle` | `speakerTitle` | `event-landing-page.tsx:146` |
| 活动日期 | `eventData.date` | `date` | `event-landing-page.tsx:150` |
| 活动时间段 | `eventData.time` | `time` | `event-landing-page.tsx:154` |
| 活动地点 | `eventData.location` | `location` | `event-landing-page.tsx:158` |

注：活动类型标签（"线下沙龙"）和"免费参加"为硬编码字符串，不来自数据。

**活动简介区**

| 展示项 | 数据来源 | 字段 | 证据位置 |
|--------|----------|------|----------|
| 活动简介正文 | `eventData.description` | `description` | `event-landing-page.tsx:173` |

**沙龙资料区**

| 展示项 | 数据来源 | 字段 | 证据位置 |
|--------|----------|------|----------|
| 资料总数 | `materials.length`（硬编码数组长度） | — | `event-landing-page.tsx:189` |
| 资料标题 | `material.title` | `title` | `event-landing-page.tsx:209` |
| 资料格式 + 大小 | `material.type`、`material.size` | `type`、`size` | `event-landing-page.tsx:212` |
| 领取状态 | `downloadedMaterials.includes(material.id)` | 仅前端状态 | `event-landing-page.tsx:196` |

**底部固定操作栏**

| 操作项 | 跳转目标 | 字段依赖 |
|--------|----------|----------|
| 咨询客服 | `/support` | 无 |
| 立即预约 | `/appointment` | 无 |

**专属服务入口（硬编码，无动态数据）**

AI 税务助手（`/tax-ai`）、财税风险测评（`/risk-assessment`）、预约顾问（`/appointment`）三个入口均为静态跳转，无动态数据依赖。

---

## 4. 业务实体和字段

### 4.1 Activity（活动）

#### 数据库实体（需持久化的字段）

| 字段 | 类型 | 分类 | 使用页面 | 证据位置 |
|------|------|------|----------|----------|
| `id` | `string`（如 `A001`） | 持久化（主键，业务编号） | 活动列表、二维码弹窗、链接生成 | `mock-data.ts:29` |
| `name` | `string` | 持久化 | 活动列表、抽屉、表单、落地页标题 | `mock-data.ts:29` |
| `theme` | `string` | 持久化 | 活动列表 Tag、抽屉头部 | `mock-data.ts:29` |
| `time` | `string`（datetime，如 `2026-06-18 14:00`） | 持久化 | 活动列表、抽屉头部、表单 | `mock-data.ts:29` |
| `place` | `string` | 持久化 | 活动列表、抽屉头部、表单 | `mock-data.ts:29` |
| `teacher` | `string` | 持久化 | 活动列表、表单 | `mock-data.ts:29` |
| `status` | `string`（枚举：已上架/草稿/已下架） | 持久化 | 活动列表 Tag、二维码弹窗、抽屉、表单 | `mock-data.ts:29` |
| `creator` | `string` | 持久化（创建人姓名） | 活动列表副标题 | `mock-data.ts:29` |
| `description` | `string` | 持久化 | 表单（占位控件）、落地页简介区 | `page.tsx:141`，`event-landing-page.tsx:173` |
| `coverImage` | `string`（URL） | 持久化 | 表单上传控件（占位）、落地页封面 | `page.tsx:142` |
| `speakerTitle` | `string` | 持久化 | 落地页主讲人职称 | `event-landing-page.tsx:146` |

注：`description`、`coverImage`、`speakerTitle` 在 admin-system `activities` 数组中**缺失**，但落地页已使用这三个字段。

#### 统计/计算字段（只读，由后端聚合）

| 字段 | 类型 | 计算方式 | 使用页面 | 证据位置 |
|------|------|----------|----------|----------|
| `scan` | `number` | 累计扫码事件数 | 活动列表、抽屉 | `mock-data.ts:29` |
| `register` | `number` | 累计注册用户数 | 活动列表、抽屉、运营洞察 | `mock-data.ts:29` |
| `materialClaims` | `number` | 累计资料领取数 | 活动数据抽屉 | `mock-data.ts:29` |
| `assessments` | `number` | 累计测评完成数 | 活动数据抽屉 | `mock-data.ts:29` |
| `appointments` | `number` | 累计预约顾问数 | 活动数据抽屉 | `mock-data.ts:29` |
| `highIntentLeads` | `number` | 累计高意向线索数 | 活动列表、抽屉 | `mock-data.ts:29` |

#### 关联字段（通过外键或聚合查询获取）

| 字段 | 类型 | 关联方式 | 使用页面 | 证据位置 |
|------|------|----------|----------|----------|
| `materials` | `number`（关联资料数） | `materialItems WHERE activity = activity.name` count | 活动列表、运营洞察 | `mock-data.ts:29` |

注：表单中关联资料的多选控件（`materialOptions`）使用的是硬编码 value（如 `risk-list`），与 `materialItems.id`（如 `MAT-001`）不一致，属于类型冲突。

#### Mock 中存在但页面未使用的字段

当前 activities 数组所有字段均在页面中被使用。无冗余字段。

#### 仅前端状态字段（不应持久化）

| 字段 | 类型 | 用途 | 证据位置 |
|------|------|------|----------|
| `formVisible` | `boolean` | 控制新建/编辑 Dialog 显示 | `page.tsx:19` |
| `qrVisible` | `boolean` | 控制二维码弹窗显示 | `page.tsx:20` |
| `drawerVisible` | `boolean` | 控制数据抽屉显示 | `page.tsx:21` |
| `selectedActivity` | `Activity` | 当前操作的活动对象 | `page.tsx:22` |
| `conversionRate` | `number` | `register/scan*100`，前端计算 | `page.tsx:48` |
| `leadRate` | `number` | `highIntentLeads/register*100`，前端计算 | `page.tsx:49` |

### 4.2 EventData（落地页活动展示对象）

落地页组件 `EventLandingPage` 接收 `eventData` prop，目前为 `defaultEventData` 硬编码，且字段结构与 admin-system `Activity` 实体不完全对齐。

| 落地页字段 | 类型 | admin-system 对应字段 | 对齐状态 |
|------------|------|----------------------|----------|
| `title` | `string` | `activity.name` | 字段名不同，语义对齐 |
| `speaker` | `string` | `activity.teacher` | 字段名不同，语义对齐 |
| `speakerTitle` | `string` | 无对应字段 | **admin-system 缺失** |
| `date` | `string` | `activity.time`（包含日期） | admin-system time 含日期+时间，落地页拆为 date+time 两字段 |
| `time` | `string` | `activity.time`（包含时间段） | 同上，存储格式不一致 |
| `location` | `string` | `activity.place` | 字段名不同，语义对齐 |
| `description` | `string` | 无对应字段 | **admin-system 缺失** |
| `coverImage` | `string`（可选） | 无对应字段 | **admin-system 缺失** |

### 4.3 落地页 Material（沙龙资料展示对象）

落地页内 `materials` 数组为组件内硬编码，与 admin-system `materialItems` 实体字段差异如下：

| 落地页字段 | 类型 | admin-system 对应字段 | 差异说明 |
|------------|------|----------------------|----------|
| `id` | `number` | `materialItems.id`（如 `MAT-001`） | 类型不同：落地页 number，后端 string |
| `title` | `string` | `materialItems.name` | 字段名不同 |
| `type` | `string`（如 `PDF`） | `materialItems.format` | 落地页 `type` 对应 admin 的 `format` |
| `size` | `string`（如 `2.4 MB`） | 无对应字段 | admin-system 无文件大小字段 |
| `icon` | `LucideIcon` | 无对应字段 | 仅前端展示逻辑 |
| `downloaded` | `boolean` | 无对应字段 | 仅前端状态 |

---

## 5. 页面操作

### 活动管理页（admin-system）

| 操作 | 触发元素 | 当前实现 | 所需 API | 证据位置 |
|------|----------|----------|----------|----------|
| 搜索/筛选活动 | 查询按钮 | 无过滤逻辑（占位控件） | `GET /api/activities?q=&status=&dateFrom=&dateTo=&page=&pageSize=` | `page.tsx:63-70` |
| 重置筛选 | 重置按钮 | 无实现 | — | `page.tsx:68` |
| 新建活动 | "新建活动"按钮 | 打开 Dialog，提交无 API | `POST /api/activities` | `page.tsx:77` |
| 编辑活动 | 行操作"编辑" | 打开 Dialog，提交无 API | `PATCH /api/activities/:id` | `page.tsx:119-121` |
| 生成二维码 | 行操作"生成二维码" | 打开二维码弹窗（占位 QR 图） | `POST /api/qr-codes`（关联活动 id） | `page.tsx:122` |
| 上架/下架 | 行操作动态文字 | `MessagePlugin.success('操作已提交')` 占位 | `PATCH /api/activities/:id/status` | `page.tsx:123` |
| 查看活动数据 | "查看数据"主操作 | 打开 Drawer，展示 Mock 数据 | `GET /api/activities/:id/stats` | `page.tsx:43-45` |
| 下载二维码 | 二维码弹窗确认按钮 | 无实现 | — | `page.tsx:147` |
| 复制链接 | 二维码弹窗取消按钮 | 无实现 | — | `page.tsx:147` |
| 批量上架 | 表格上方按钮 | 无实现（占位按钮） | `PATCH /api/activities/bulk-status` | `page.tsx:77` |
| 批量下架 | 表格上方按钮 | 无实现（占位按钮） | `PATCH /api/activities/bulk-status` | `page.tsx:77` |
| 导出活动数据 | 表格上方按钮 | 无实现（占位按钮） | `GET /api/activities/export` | `page.tsx:77` |

### 落地页活动展示（landing-page）

| 操作 | 触发元素 | 当前实现 | 所需 API | 证据位置 |
|------|----------|----------|----------|----------|
| 加载活动信息 | 页面初始化 | 使用 `defaultEventData` 硬编码 | `GET /api/activities/:id`（通过 URL query 参数 `activity_id` 获取） | `event-landing-page.tsx:43-51` |
| 领取资料（未登录） | 点击"领取"按钮 | 触发 LoginModal | 登录后 `POST /api/material-claims` | `event-landing-page.tsx:98-106` |
| 领取资料（已登录） | 点击"领取"按钮 | 更新前端状态 `downloadedMaterials`，无 API | `POST /api/material-claims` | `event-landing-page.tsx:103-105` |
| 立即领取全部资料 | 未登录时全量领取按钮 | 触发 LoginModal | 同上 | `event-landing-page.tsx:244-252` |
| 跳转 AI 税务助手 | 卡片点击 | `router.push("/tax-ai")` | — | `event-landing-page.tsx:268` |
| 跳转财税风险测评 | 卡片点击 | `router.push("/risk-assessment")` | — | `event-landing-page.tsx:285` |
| 跳转预约顾问 | 卡片点击/底部按钮 | `router.push("/appointment")` | — | `event-landing-page.tsx:302` |
| 咨询客服 | 底部固定按钮 | `router.push("/support")` | — | `event-landing-page.tsx:362` |

---

## 6. 建议 API

### 活动 CRUD（admin-system）

| 方法 | 路径 | 请求体 / 参数 | 响应 |
|------|------|---------------|------|
| `GET` | `/api/activities` | `q`, `status`, `dateFrom`, `dateTo`, `page`, `pageSize` | `{ items: ActivityListDTO[], total: number }` |
| `GET` | `/api/activities/:id` | — | `ActivityDetailDTO` |
| `POST` | `/api/activities` | `ActivityFormDTO` | `ActivityDetailDTO` |
| `PATCH` | `/api/activities/:id` | `Partial<ActivityFormDTO>` | `ActivityDetailDTO` |
| `PATCH` | `/api/activities/:id/status` | `{ status: '已上架' \| '已下架' }` | `{ id: string, status: string }` |
| `PATCH` | `/api/activities/bulk-status` | `{ ids: string[], status: '已上架' \| '已下架' }` | `{ updated: number }` |
| `GET` | `/api/activities/export` | 同列表筛选参数 | CSV / XLSX 文件流 |

### 活动统计数据（admin-system 数据抽屉）

| 方法 | 路径 | 响应 |
|------|------|------|
| `GET` | `/api/activities/:id/stats` | `ActivityStatsDTO`（含 scan/register/materialClaims/assessments/appointments/highIntentLeads 及各阶段漏斗数据） |

注：漏斗数据应从活动维度聚合，不应使用全局共享的 `funnelData`。

### 活动落地页（landing-page）

| 方法 | 路径 | 参数 | 响应 |
|------|------|------|------|
| `GET` | `/api/activities/:id/landing` | URL query: `activity_id`，可附带 `qr_id`/`invite` 参数 | `ActivityLandingDTO`（含 name/speakerTitle/date/time/location/description/coverImage） |
| `GET` | `/api/activities/:id/materials` | — | `MaterialDTO[]`（仅展示已上架且关联该活动的资料，含 id/name/format/fileSize/needLogin/needCompanyInfo） |
| `POST` | `/api/material-claims` | `{ materialId: string, activityId: string, qrId?: string }` | `{ success: boolean, claimId: string }` |

---

## 7. 字段和类型冲突

| 冲突描述 | 文件 A | 文件 B | 字段 | 风险等级 |
|----------|--------|--------|------|----------|
| **activity.time 格式与落地页拆分不一致**：admin-system 的 `activities.time` 格式为 `2026-06-18 14:00`（单字符串，含日期和时间），落地页 `eventData` 拆为 `date`（`2026年6月15日`）和 `time`（`14:00 - 17:00`）两个字段，格式、时区和语言都不同 | `mock-data.ts:29` | `event-landing-page.tsx:44-46` | `time` vs `date`+`time` | **高风险** |
| **teacher vs speaker 字段名不一致且缺少 speakerTitle**：admin-system 存 `teacher`（仅姓名，如"王老师"），落地页需要 `speaker`（姓名）和 `speakerTitle`（职称，如"注册税务师 / 高级合伙人"），后者在 admin-system `activities` 数组中完全缺失 | `mock-data.ts:29` | `event-landing-page.tsx:46-47` | `teacher` vs `speaker`+`speakerTitle` | **高风险** |
| **description 和 coverImage 在 admin-system 缺失**：落地页已消费 `eventData.description` 和 `eventData.coverImage`，但 admin-system `activities` 数组无这两个字段，表单中两个控件均为占位，提交无效 | `mock-data.ts:28-33` | `event-landing-page.tsx:49-51`，`page.tsx:141-142` | `description`、`coverImage` | **高风险** |
| **materialOptions 的 value 与 materialItems.id 格式不一致**：活动表单关联资料使用硬编码选项（value 为 `risk-list`），而资料管理页 `materialItems.id` 格式为 `MAT-001`；两者无法直接关联，后端无法据此查询 | `activities/page.tsx:11-16` | `mock-data.ts:79-85` | `materialOptions.value` vs `materialItems.id` | **高风险** |
| **落地页 materials.id 为 number，admin materialItems.id 为 string**：落地页 `materials` 数组使用 `number` 类型 id（1/2/3/4），`materialItems` 使用 `MAT-001` 格式字符串 id，无法直接对应 | `event-landing-page.tsx:54-86` | `mock-data.ts:79-85` | `material.id` | **高风险** |
| **funnelData 为全局共享数据，活动数据抽屉用于展示特定活动漏斗，数据不归因**：所有活动的数据抽屉展示同一套漏斗数据（全平台汇总），不是对应活动的真实漏斗 | `mock-data.ts:17-26` | `activities/page.tsx:180` | `funnelData`（无 activityId） | **高风险** |
| **place vs location 字段名不一致**：admin-system 使用 `place`，落地页 `eventData` 使用 `location`，语义完全相同但命名不同 | `mock-data.ts:29` | `event-landing-page.tsx:46` | `place` vs `location` | 中风险 |
| **activity 与 qrCodeItems/materialItems 通过活动名称字符串关联，而非 id 外键**：`qrCodeItems.activity`、`materialItems.activity`、`users.sourceActivity`、`leads.activity` 均存活动名称字符串，活动改名将导致所有关联记录断裂 | `mock-data.ts:29` | `mock-data.ts:72-76`、`mock-data.ts:79-85`、`mock-data.ts:36` | `activity`（字符串）vs `activities.id` | 中风险 |
| **AI 提问人数为写死系数计算，非真实字段**：`Math.round(selectedActivity.register * 0.61)` 在活动数据抽屉展示"AI 提问"人数，不是存储字段 `qaCount`，接入真实数据后该系数将失效且无法解释 | `activities/page.tsx:172` | `mock-data.ts:28-33` | `aiQuestions`（缺失） | 中风险 |
| **status 枚举未在 TypeScript 中定义**：`LeadStatus`、`RiskLevel` 类型已在 `mock-data.ts` 导出，但 Activity 的 `status`（已上架/草稿/已下架）未定义为具体类型，直接用 `string`，`statusTheme()` 函数也是字符串 includes 判断 | `mock-data.ts:1-2` | `ui.ts:10-15` | `Activity.status` | 低风险 |

---

## 8. 页面状态缺口

| 缺口描述 | 页面 | 当前状态 | 影响 |
|----------|------|----------|------|
| 落地页无 `activity_id` 参数读取逻辑，`app/page.tsx` 直接渲染 `<EventLandingPage />`，URL 中的 `activity_id` 和 `invite` 参数被完全忽略 | 落地页根路由 | `app/page.tsx` 无任何 `useSearchParams` 或 props 传递 | 所有用户无论从哪个活动二维码扫码进入，落地页展示的始终是同一份 `defaultEventData`，活动归因无法实现 |
| 落地页资料领取后无持久化，仅更新本地 state `downloadedMaterials`，刷新后领取记录消失 | 落地页资料领取 | `useState<number[]>([4])`，无 API 调用，无 localStorage | 用户领取记录无法传递到 admin-system，materialItems 的 `claims` 统计数永远不更新 |
| 活动数据抽屉的漏斗图展示全局 `funnelData`，不是当前活动的真实数据 | 活动数据抽屉 | `funnelData` 直接导入并渲染，与 `selectedActivity` 无关联 | 运营人员查看任意活动数据抽屉，看到的漏斗数据都相同 |
| 活动编辑表单 `description` 和 `coverImage` 控件存在但数据模型缺失，提交后无法携带这两个字段 | 新建/编辑活动 Dialog | 两个控件均为占位，无 defaultValue，无字段绑定 | 活动简介和封面图永远为空，落地页依赖这两个字段的区域无数据 |
| 二维码弹窗中邀请码为 `${id}-INVITE` 拼接，落地页链接中使用相同拼接方式，与 `qrCodeItems.inviteCode`（如 `ACT20260702`）格式不一致 | 活动二维码弹窗 | `selectedActivity.id + '-INVITE'` | 活动页生成的二维码链接参数与二维码管理模块的 inviteCode 无法对应，扫码归因断裂 |
| 活动筛选条件（搜索框/状态/日期区间）无任何过滤逻辑 | 活动列表页 | 三个控件均为非受控或固定 value，查询/重置按钮无 onClick | 筛选功能完全无效 |
| 行操作"上架/下架"仅显示 MessagePlugin.success，无实际状态更新 | 活动列表行操作 | `MessagePlugin.success('操作已提交')` | 点击后状态不变，表格数据不刷新 |

---

## 9. 共用模型

以下模型在两个系统中均有消费，需在接口契约阶段统一对齐：

| 实体 | admin-system 视角 | landing-page 视角 | 需对齐字段 |
|------|-------------------|-------------------|------------|
| Activity | CRUD 完整实体，含 id/name/theme/time/place/teacher/status/creator/scan/register/... 等 16+ 字段 | 只读展示，需要 title/speaker/speakerTitle/date/time/location/description/coverImage 8 个字段 | `name→title`, `teacher→speaker`, `place→location`, `time` 需拆分为 `date`+`time` 两字段，缺 `speakerTitle`/`description`/`coverImage` |
| Material | 完整资料实体（id/name/type/format/activity/needLogin/needCompanyInfo/status/downloads/claims/createdAt） | 展示用（title/type/size/icon），领取状态为前端 state | `name→title`, `format→type`，缺 `size`，落地页 `id` 为 number 需改为 string |
| ActivityStats | admin-system 存储 scan/register/materialClaims/assessments/appointments/highIntentLeads，`aiQuestions` 字段缺失 | 不消费统计数据 | 需新增 `aiQuestions` 持久化字段替代写死系数 |

**建议**：

1. 定义 `ActivityLandingDTO` 作为落地页专用响应体，字段名与落地页组件 props 对齐（`title`, `speaker`, `speakerTitle`, `date`, `time`, `location`, `description`, `coverImage`），由 admin-system 的 Activity 实体转换生成，避免两套代码各自维护字段映射。
2. `activities.time` 存为 ISO 8601 datetime 字符串，由前端分别格式化为日期、时间段展示，消除当前 `2026-06-18 14:00` 与 `2026年6月15日 / 14:00 - 17:00` 的格式分叉。

---

## 10. 推荐迁移顺序

| 优先级 | 任务 | 原因 |
|--------|------|------|
| P0 | 补全 Activity 实体缺失字段：`description`、`coverImage`、`speakerTitle` | 落地页已消费这三个字段，admin-system 数据模型不完整，落地页无法从后端获取数据 |
| P0 | 落地页接收并使用 `activity_id` URL 参数，调用 `GET /api/activities/:id/landing` | 当前所有用户看到同一活动，扫码归因完全失效，是整个业务漏斗的入口问题 |
| P0 | 统一 `activities.time` 为标准 datetime 格式，并在落地页拆分展示 | 高风险字段类型冲突，影响活动时间的准确展示 |
| P1 | 新增 `aiQuestions` 统计字段替换 `register * 0.61` 写死系数 | 写死系数无业务依据，接入真实数据后活动数据抽屉将展示错误数据 |
| P1 | 活动数据抽屉改为调用 `GET /api/activities/:id/stats`，漏斗数据按活动 id 隔离 | 当前全局共享 funnelData，所有活动展示相同漏斗，运营决策依据失真 |
| P1 | 活动表单关联资料的 `materialOptions` 改为从 `GET /api/materials?activityId=` 动态加载，统一 id 格式（`MAT-001`） | 硬编码选项与 materialItems.id 不一致，高风险类型冲突 |
| P1 | 活动编辑表单字段完善（description/coverImage 绑定数据），保存时调用 API | 当前提交无效 |
| P1 | 所有跨实体关联（qrCodeItems/materialItems/users/leads）从 `activity.name` 字符串关联改为 `activity.id` 外键关联 | 活动改名将导致全量关联记录断裂，中风险 |
| P2 | 落地页资料领取调用 `POST /api/material-claims`，将领取记录持久化 | 当前仅更新本地 state，领取统计永远不更新 |
| P2 | 活动列表筛选、上架/下架操作接入真实 API | 当前功能完全占位 |
| P2 | 活动二维码生成接入 `POST /api/qr-codes`，邀请码格式与 qrCodeItems.inviteCode 统一 | 当前邀请码为拼接字符串，与二维码管理模块格式不一致 |
| P3 | 定义 `ActivityStatus` TypeScript 枚举类型，对齐 `statusTheme()` 函数的字符串判断 | 低风险类型安全问题 |
| P3 | 批量上架/下架、导出活动数据 | 运营效率功能，可最后实现 |

---

## 11. 不确定项

| # | 不确定项 | 文件 | 假设 | 影响范围 |
|---|----------|------|------|----------|
| 1 | 落地页展示的是单个活动还是活动列表？当前 `app/page.tsx` 无参数路由（非 `app/activities/[id]/page.tsx`），无法通过路由直接区分不同活动 | `拓客系统-落地页/app/page.tsx:1-9` | 假设落地页通过 URL query 参数 `?activity_id=A001&invite=xxx` 区分活动，组件内通过 `useSearchParams` 读取 | 影响落地页路由设计：使用 dynamic route 还是 query params，两种方案的 SEO 和缓存策略不同 |
| 2 | 落地页资料列表是否应与活动绑定动态加载，还是所有落地页展示统一资料？当前 `materials` 数组为组件内硬编码 4 条，与 admin-system `materialItems.activity` 字段的绑定关系未在落地页体现 | `event-landing-page.tsx:53-86` | 假设资料列表应按活动 id 过滤，调用 `GET /api/activities/:id/materials` | 影响落地页资料区的加载逻辑设计 |
| 3 | `activities.creator` 字段存创建人姓名字符串（如"市场运营-林琳"），还是应存 adminUser.id 外键？当前为姓名字符串 | `mock-data.ts:29` | 假设应存 adminUser.id，展示时 join 用户显示名 | 影响 Activity 表的 `creator_id` 外键设计 |
| 4 | 活动地点（`place`）中"线上直播"与"城市+会场"是同一字段还是应拆分为 `isOnline: boolean` + `location: string`？落地页和 admin-system 均用单一字符串，但业务上存在线上/线下两种形态 | `mock-data.ts:29`，`event-landing-page.tsx:158` | 假设保持单字符串，由创建人手动填写，暂不拆分 | 影响活动表单控件设计和筛选条件（线上/线下过滤） |
| 5 | 活动数据抽屉的运营洞察（`Math.round(selectedActivity.register * 0.61)` 模拟 AI 提问人数）中 `0.61` 系数的来源是什么？是产品设定的预期转化率，还是某次真实数据的经验值？ | `activities/page.tsx:172` | 假设是临时占位系数，接入真实数据后需要替换为 `activities.aiQuestions` 统计字段 | 影响 ActivityStats 表是否需要新增 `ai_questions` 字段 |
| 6 | `activities.materials` 字段（关联资料数，number）是维护在活动记录中的冗余计数，还是每次从 `materialItems WHERE activity = name` 实时聚合？当前 Mock 是直接存的数字 | `mock-data.ts:29`，`activities/page.tsx:98` | 假设为冗余计数字段，由后端在关联/取消关联资料时同步维护，避免频繁聚合查询 | 影响 Activity 表设计和资料关联接口的触发逻辑 |

---

**高风险不一致项汇总（需优先处理）**：

1. 落地页 `app/page.tsx` 无 `activity_id` 参数读取，所有扫码用户看到同一硬编码活动，整个业务漏斗的活动归因入口失效。
2. `activities.time` 单字符串格式与落地页 `date`+`time` 双字段分裂，字符串格式也不一致（`2026-06-18 14:00` vs `2026年6月15日`/`14:00 - 17:00`），两端无法共用同一数据源。
3. `teacher` vs `speaker`+`speakerTitle` 字段分裂：admin-system 缺失 `speakerTitle` 字段，落地页展示的主讲人职称无真实数据来源。
4. `description` 和 `coverImage` 在 admin-system `activities` 数组中缺失，表单控件为占位，活动简介和封面图无法通过后台维护。
5. 活动表单关联资料 `materialOptions.value`（`risk-list`）与 `materialItems.id`（`MAT-001`）格式完全不同，后端无法据此建立关联关系。
