# 用户管理模块 Mock 数据审计报告

**审计日期**：2026-06-10  
**审计员**：mock-auditor agent  
**项目阶段**：MVP 原型阶段，无真实数据库和身份认证

---

## 1. 审计范围

| 系统 | 文件路径 | 页面 / 用途 |
|------|----------|-------------|
| admin-system | `拓客系统-管理后台/app/users/page.tsx` | 用户列表页 |
| admin-system | `拓客系统-管理后台/app/users/[id]/page.tsx` | 用户详情页 |
| admin-system | `拓客系统-管理后台/app/login/page.tsx` | 管理员登录页 |
| admin-system | `拓客系统-管理后台/components/admin-shell.tsx` | 全局 Shell（认证守卫） |
| admin-system | `拓客系统-管理后台/lib/mock-data.ts` | 所有 Mock 数据和类型定义 |
| admin-system | `拓客系统-管理后台/lib/ui.ts` | statusTheme / riskTheme 工具函数 |
| landing-page | `拓客系统-落地页/app/login/page.tsx` | 落地页入口（仅壳） |
| landing-page | `拓客系统-落地页/components/mobile/login-page.tsx` | 登录页面组件 |
| landing-page | `拓客系统-落地页/components/mobile/login-modal.tsx` | 登录弹窗组件 |
| landing-page | `拓客系统-落地页/components/mobile/login-register-form.tsx` | 登录/注册表单（核心） |

---

## 2. Mock 来源清单

| 来源类型 | 文件 | 具体内容 | 证据位置 |
|----------|------|----------|----------|
| 硬编码对象数组 | `lib/mock-data.ts` | `users` 数组，5 条用户记录 | `mock-data.ts:35-41` |
| 硬编码对象数组 | `lib/mock-data.ts` | `userTimeline` 数组，7 条行为事件（全局共享，非按用户 id 过滤） | `mock-data.ts:43-51` |
| 硬编码对象数组 | `lib/mock-data.ts` | `reports` 数组，3 条测评报告（按 user.name 关联） | `mock-data.ts:59-63` |
| 硬编码对象数组 | `lib/mock-data.ts` | `leads` 数组，3 条线索记录（按 name 关联） | `mock-data.ts:65-69` |
| 硬编码对象数组 | `lib/mock-data.ts` | `qaRecords` 数组（按 name 关联，详情页 qa 标签页渲染全量） | `mock-data.ts:53-57` |
| 硬编码对象数组 | `lib/mock-data.ts` | `materialItems` 数组（详情页资料标签页取前 3 条，未按用户过滤） | `mock-data.ts:79-85` |
| 硬编码对象数组 | `lib/mock-data.ts` | `activities` 数组（用户列表来源活动下拉选项） | `mock-data.ts:28-33` |
| 模拟异步 + 硬编码认证 | `admin-system/app/login/page.tsx` | `setTimeout(resolve, 450)` 模拟登录请求；硬编码 `admin / admin123` 校验 | `login/page.tsx:15-17` |
| 模拟异步 | `landing-page/components/mobile/login-register-form.tsx` | `window.setTimeout(resolve, 900)` 模拟微信授权和手机验证码请求；验证码发送无真实 API 调用 | `login-register-form.tsx:55,65` |
| localStorage 模拟业务状态 | `admin-system/components/admin-shell.tsx` | `admin-login-token` 和 `admin-username` 存入 localStorage 模拟会话 | `admin-shell.tsx:63-70` |
| 临时权限判断 | `admin-system/components/admin-shell.tsx` | `username === 'admin'` 判断角色为"超级管理员"或"运营管理员" | `admin-shell.tsx:80` |
| 写死分页总数 | `admin-system/app/users/page.tsx` | `total: users.length`（当前固定为 5） | `users/page.tsx:100` |
| 写死预约文本 | `admin-system/app/users/[id]/page.tsx` | `已预约 2026-06-06 14:00，与周顾问进行电话沟通。` 硬编码字符串 | `users/[id]/page.tsx:61` |
| 写死来源标签 | `admin-system/app/users/[id]/page.tsx` | `沙龙扫码 / 活动落地页` 硬编码展示，未来自数据 | `users/[id]/page.tsx:57` |

---

## 3. 页面数据需求

### 3.1 用户列表页（`admin-system/app/users/page.tsx`）

**统计概览卡片（4 张）**

| 指标 | 计算来源 | 字段依赖 |
|------|----------|----------|
| 注册用户总数 | `users.length` | 无（count） |
| 高意向用户数 | `user.tags` 包含"意向"关键字 | `tags: string[]` |
| 高风险用户数 | `user.tags` 包含"风险"关键字 | `tags: string[]` |
| 已生成线索数 | `user.leadStatus !== '未生成'` | `leadStatus: string` |

**筛选条件**

| 筛选项 | 数据来源 | 字段依赖 |
|--------|----------|----------|
| 手机号搜索 | 用户输入 | `phone` |
| 姓名搜索 | 用户输入 | `name` |
| 来源活动 | `activities` 列表动态生成 | `activities.name` → `user.sourceActivity` |
| 身份 | 页面硬编码选项（企业老板/财务负责人/创业者） | `identity` |
| 用户标签 | 页面硬编码选项 | `tags` |
| 注册时间区间 | DateRangePicker | `registeredAt` |

**用户列表表格（13 列实际使用）**

| 列 | 字段 | 备注 |
|----|------|------|
| 用户 ID | `id` | 前端格式化为 `U0001` |
| 姓名 | `name` | |
| 手机号 | `phone` | 当前 Mock 为脱敏格式，如 `138****5628` |
| 身份 | `identity` | |
| 企业名称 | `company` | |
| 行业 | `industry` | |
| 企业规模 | `size` | |
| 来源活动 | `sourceActivity` | |
| 来源二维码 | `sourceQr` | |
| 用户标签 | `tags` | `string[]` |
| 注册时间 | `registeredAt` | |
| 最近活跃时间 | `activeAt` | |
| 线索状态 | `leadStatus` | 枚举驱动展示颜色 |

**行操作**：查看详情（跳转 `/users/:id`）、编辑标签、生成线索。

### 3.2 用户详情页（`admin-system/app/users/[id]/page.tsx`）

**基础信息卡片（Descriptions）**

| 字段 | Mock 字段 | 是否持久化 |
|------|-----------|------------|
| 手机号 | `phone` | 持久化 |
| 微信 openid | `openid` | 持久化 |
| 身份 | `identity` | 持久化 |
| 企业名称 | `company` | 持久化 |
| 行业 | `industry` | 持久化 |
| 企业规模 | `size` | 持久化 |
| 注册时间 | `registeredAt` | 持久化 |
| 最近活跃 | `activeAt` | 持久化（系统更新） |

**用户标签卡片（按语义分类展示）**

| 标签分类 | 来源字段 | 过滤规则 |
|----------|----------|----------|
| 来源标签 | `sourceActivity`, `sourceQr` | 直接展示 |
| 身份标签 | `identity`, `industry` | 直接展示 |
| 需求标签 | `tags` | 包含"关注"/"发票"/"零申报" |
| 意向标签 | `tags` | 包含"意向"/"潜在" |
| 风险标签 | `tags` | 包含"风险"/"零申报" |

**顾问摘要卡片**

| 数据项 | 来源 | 字段 |
|--------|------|------|
| 风险等级 | `reports.risk` | 跨实体关联 `report.user === user.name` |
| 风险分 | `reports.score` | 同上 |
| 线索状态 | `users.leadStatus` | |
| 风险模块 | `reports.modules` | |
| 来源活动 | `users.sourceActivity` | |
| 来源二维码 | `users.sourceQr` | |
| 用户标签汇总 | `users.tags` | |

**用户行为时间线**

当前展示 `userTimeline` 全局静态数据，**未按 user.id 过滤**，所有用户详情页显示同一组时间线。

**标签页（6 个）**

| 标签页 | 所用数据 | 字段 |
|--------|----------|------|
| 来源记录 | `user.sourceActivity`, `user.sourceQr` | 硬编码补充文字"沙龙扫码 / 活动落地页" |
| 资料领取记录 | `materialItems.slice(0, 3)` | `name`, `type`, `createdAt`（未按 user.id 过滤） |
| AI 问答记录 | `qaRecords`（全量） | `summary`, `risk`, `time`（未按 user.id 过滤） |
| 测评报告 | `reports`（按 user.name 匹配） | `score`, `risk`, `modules` |
| 预约记录 | 硬编码字符串 | 无动态数据 |
| 线索记录 | `leads`（按 name 匹配） | `id`, `level`, `status`, `last` |

### 3.3 管理后台登录页（`admin-system/app/login/page.tsx`）

| 表单字段 | 类型 | 页面实际使用 |
|----------|------|-------------|
| username | `string` | 是 |
| password | `string` | 是 |
| 记住登录状态 | `boolean`（Checkbox，defaultChecked） | 展示但未持久化处理 |

### 3.4 落地页登录/注册表单（`landing-page/components/mobile/login-register-form.tsx`）

| 表单字段 | 类型 | 页面实际使用 |
|----------|------|-------------|
| phone | `string`（11位，数字） | 是 |
| code | `string`（6位，数字） | 是 |
| agreed | `boolean` | 是（控制提交按钮可用状态） |
| loginType | `"wechat" \| "phone" \| null` | 仅前端状态（控制 loading 图标） |

登录方式支持两种路径：微信授权登录、手机号验证码登录。两种路径均通过 `setTimeout` 模拟，无真实 API 调用。

---

## 4. 业务实体和字段

### 4.1 端用户（User）— 落地页注册的外部用户

#### 数据库实体（需持久化）

| 字段 | 类型 | 分类 | 证据位置 |
|------|------|------|----------|
| `id` | `number` / `uuid` | 持久化（主键） | `mock-data.ts:36` |
| `name` | `string` | 持久化 | `mock-data.ts:36` |
| `phone` | `string` | 持久化（脱敏展示） | `mock-data.ts:36` |
| `openid` | `string` | 持久化（微信 openid） | `mock-data.ts:36` |
| `identity` | `string` | 持久化（用户自填） | `mock-data.ts:36` |
| `company` | `string` | 持久化（用户自填） | `mock-data.ts:36` |
| `industry` | `string` | 持久化（用户自填） | `mock-data.ts:36` |
| `size` | `string` | 持久化（用户自填） | `mock-data.ts:36` |
| `sourceActivity` | `string` | 持久化（来源活动名称） | `mock-data.ts:36` |
| `sourceQr` | `string` | 持久化（来源二维码 ID / inviteCode） | `mock-data.ts:36` |
| `tags` | `string[]` | 持久化（运营人工打标） | `mock-data.ts:36` |
| `registeredAt` | `string` / `timestamp` | 持久化（系统自动） | `mock-data.ts:36` |
| `activeAt` | `string` / `timestamp` | 持久化（系统更新） | `mock-data.ts:36` |
| `leadStatus` | `string`（枚举） | 持久化 / 关联字段 | `mock-data.ts:36` |

#### Mock 中存在但页面**未使用**的字段

当前 `users` 数组内字段均已在页面中使用，无冗余字段。

#### 列表 DTO（用于 `users/page.tsx`）

`id`, `name`, `phone`, `identity`, `company`, `industry`, `size`, `sourceActivity`, `sourceQr`, `tags`, `registeredAt`, `activeAt`, `leadStatus`

#### 详情 DTO（用于 `users/[id]/page.tsx`）

列表 DTO 全部字段 + `openid`

#### 表单 DTO（落地页注册，`login-register-form.tsx`）

`phone`, `code`（验证码，服务端校验后不持久化），以及后续补充企业信息的步骤（`userTimeline` 中提到"补充企业信息"，但当前落地页表单中未实现此步骤，是一个缺口）。

---

### 4.2 管理员（AdminUser）— 管理后台登录用户

#### 数据库实体（需持久化）

| 字段 | 类型 | 分类 | 证据位置 |
|------|------|------|----------|
| `username` | `string` | 持久化（主键/唯一） | `admin/login/page.tsx:17` |
| `password` | `string`（加密） | 持久化 | `admin/login/page.tsx:17` |
| `role` | `string`（枚举） | 持久化 | `admin-shell.tsx:80` |
| `displayName` | `string` | 持久化 | `admin-shell.tsx:81` |

#### 角色枚举（当前 Mock）

`username === 'admin'` → 超级管理员；其他 → 运营管理员。

实际业务应有至少三种角色（CLAUDE.md 中提及）：市场运营、税务顾问、管理者。

#### 会话字段（不持久化，仅前端状态）

| 字段 | 存储位置 | 内容 |
|------|----------|------|
| `admin-login-token` | `localStorage` | `"mock-admin-token"`（固定字符串） |
| `admin-username` | `localStorage` | 登录的 username |

---

### 4.3 用户行为时间线（UserTimelineEvent）

| 字段 | 类型 | 分类 | 证据位置 |
|------|------|------|----------|
| `title` | `string` | 持久化 | `mock-data.ts:44` |
| `desc` | `string` | 持久化 | `mock-data.ts:44` |
| `time` | `string` / `timestamp` | 持久化 | `mock-data.ts:44` |
| `userId`（缺失） | 外键 | 关联字段（当前 Mock 无此字段） | — |

---

## 5. 页面操作

### 用户列表页

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 搜索/筛选用户 | 查询按钮 | 无效（无过滤逻辑） | `GET /api/users?phone=&name=&activity=&identity=&tags=&dateFrom=&dateTo=` |
| 重置筛选 | 重置按钮 | 无效 | — |
| 查看详情 | 操作列"查看详情" | `window.location.href = /users/${row.id}` | 已有路由，需后端支持 `GET /api/users/:id` |
| 编辑标签 | 更多菜单"编辑标签" | 无实现（占位） | `PATCH /api/users/:id/tags` |
| 生成线索 | 更多菜单"生成线索" | 无实现（占位） | `POST /api/leads` |
| 批量打标签 | 头部按钮 | 无实现（占位） | `PATCH /api/users/bulk-tags` |
| 导出用户 | 头部按钮 | 无实现（占位） | `GET /api/users/export` |

### 用户详情页

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 返回列表 | 返回按钮 | `Link href="/users"` | — |
| 添加标签 | 按钮 | 无实现（占位） | `PATCH /api/users/:id/tags` |
| 分配/联系顾问 | 按钮 | 无实现（占位） | `POST /api/leads/:id/assign` |
| 查看各标签页内容 | Tabs | 静态 Mock 数据渲染 | 各子模块 API（见第 6 节） |

### 落地页登录/注册

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 获取验证码 | 获取验证码按钮 | 仅倒计时，无 API | `POST /api/auth/send-code` |
| 手机号验证码登录 | 登录按钮 | `setTimeout` 模拟 | `POST /api/auth/login-phone` |
| 微信授权登录 | 微信授权按钮 | `setTimeout` 模拟 | `GET /api/auth/wechat-oauth` |
| 同意协议 | Checkbox | 控制按钮状态（仅前端） | — |

### 管理后台登录

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 登录 | 登录按钮 | `setTimeout` + 硬编码校验 `admin/admin123` | `POST /api/admin/login` |
| 退出登录 | 顶栏下拉"退出登录" | 清除 localStorage，跳转 `/login` | `POST /api/admin/logout`（可选，JWT 无状态时不需要） |
| 记住登录状态 | Checkbox | 展示但未实现持久化逻辑 | — |

---

## 6. 建议 API

### 端用户认证（landing-page）

| 方法 | 路径 | 请求体 | 响应 |
|------|------|--------|------|
| `POST` | `/api/auth/send-code` | `{ phone: string }` | `{ success: boolean }` |
| `POST` | `/api/auth/login-phone` | `{ phone: string, code: string }` | `{ token: string, user: UserDTO }` |
| `GET` | `/api/auth/wechat-oauth` | query: `code` (微信授权码) | `{ token: string, user: UserDTO, isNew: boolean }` |
| `GET` | `/api/auth/me` | Header: Bearer token | `{ user: UserDTO }` |

### 管理员认证（admin-system）

| 方法 | 路径 | 请求体 | 响应 |
|------|------|--------|------|
| `POST` | `/api/admin/login` | `{ username: string, password: string }` | `{ token: string, role: string, displayName: string }` |
| `POST` | `/api/admin/logout` | — | `{ success: boolean }` |

### 用户管理（admin-system）

| 方法 | 路径 | 参数 | 响应 |
|------|------|------|------|
| `GET` | `/api/users` | `phone`, `name`, `activity`, `identity`, `tags`, `dateFrom`, `dateTo`, `page`, `pageSize` | `{ items: UserListDTO[], total: number }` |
| `GET` | `/api/users/:id` | — | `UserDetailDTO` |
| `PATCH` | `/api/users/:id/tags` | `{ tags: string[] }` | `UserDetailDTO` |
| `GET` | `/api/users/export` | 同筛选参数 | CSV / XLSX 文件流 |
| `PATCH` | `/api/users/bulk-tags` | `{ ids: number[], tags: string[] }` | `{ updated: number }` |

### 用户关联数据（admin-system，详情页标签页）

| 方法 | 路径 | 响应 |
|------|------|------|
| `GET` | `/api/users/:id/timeline` | `UserTimelineEvent[]` |
| `GET` | `/api/users/:id/materials` | 该用户领取的 `MaterialClaimDTO[]` |
| `GET` | `/api/users/:id/qa-records` | 该用户的 `QaRecordDTO[]` |
| `GET` | `/api/users/:id/report` | 该用户的 `AssessmentReportDTO` |
| `GET` | `/api/users/:id/appointments` | 该用户的预约记录 `AppointmentDTO[]` |
| `GET` | `/api/users/:id/lead` | 该用户的线索 `LeadDTO` |

---

## 7. 字段和类型冲突

| 冲突描述 | 文件 A | 文件 B | 字段 | 风险等级 |
|----------|--------|--------|------|----------|
| **用户与报告关联方式不一致**：`users/[id]/page.tsx` 用 `report.user === user.name`（字符串匹配），`leads` 同样用 `lead.name === user.name`，均未使用 `user.id` 关联 | `mock-data.ts:60-63` | `users/[id]/page.tsx:19-20` | `user.name` vs `user.id` | 高风险 |
| **phone 字段脱敏不一致**：Mock 中用户手机号格式为 `138****5628`（脱敏），而 `qaRecords` 和 `leads` 中也有相同脱敏格式的 phone 字段，但落地页表单验证要求 11 位完整手机号，后端存储与前端展示格式需要明确约定 | `mock-data.ts:36-41` | `login-register-form.tsx:29` | `phone` | 高风险 |
| **leadStatus 枚举范围不一致**：`lib/mock-data.ts` 第 2 行定义 `LeadStatus` 类型包含 7 个枚举值（含"新线索"/"无效线索"），但 `users.leadStatus` 字段使用了"未生成"这个不在枚举内的值（`users/page.tsx:23` 用 `!== '未生成'` 判断） | `mock-data.ts:2` | `mock-data.ts:40` | `leadStatus` | 高风险 |
| **用户行为时间线未绑定用户**：`userTimeline` 是全局静态数组，无 `userId` 字段，详情页所有用户显示同一条时间线 | `mock-data.ts:43-51` | `users/[id]/page.tsx:50-53` | `userId`（缺失） | 中风险 |
| **资料领取记录未绑定用户**：详情页资料标签页使用 `materialItems.slice(0, 3)` 展示，不是该用户的真实领取记录 | `mock-data.ts:79-85` | `users/[id]/page.tsx:58` | `userId`（缺失） | 中风险 |
| **问答记录未绑定用户**：`qaRecords` 全量展示，虽有 `user` 和 `phone` 字段，但详情页未按 `user.id` 或 `user.name` 过滤，全量渲染了所有人的问答 | `mock-data.ts:53-57` | `users/[id]/page.tsx:59` | `userId`（外键缺失） | 中风险 |
| **管理员角色模型过于简单**：当前仅用 `username === 'admin'` 区分角色，CLAUDE.md 规定应有市场运营/税务顾问/管理者三种角色，但 mock-data.ts 中无 AdminUser 类型定义 | `admin-shell.tsx:80` | `CLAUDE.md` | `role` | 中风险 |
| **管理后台 token 为固定字符串**：`localStorage.setItem('admin-login-token', 'mock-admin-token')` 无过期、无用户信息，无法支持真实的权限校验逻辑 | `admin/login/page.tsx:18` | `admin-shell.tsx:63` | `token` | 高风险 |
| **sourceActivity 为字符串而非 id 关联**：`user.sourceActivity` 存活动名称字符串，`activities` 也存名称字段，但活动有唯一 `id`（如 `A001`），未来改名将导致数据断裂 | `mock-data.ts:36` | `mock-data.ts:28-33` | `sourceActivity` vs `activities.id` | 中风险 |

---

## 8. 页面状态缺口

| 缺口描述 | 页面 | 当前状态 | 影响 |
|----------|------|----------|------|
| 筛选条件无任何过滤逻辑 | 用户列表页 | Input / Select / DateRangePicker 均为受控组件但无 `onChange` 绑定过滤逻辑，查询和重置按钮无事件处理 | 筛选功能完全无效 |
| 落地页注册后无 session 状态 | 落地页登录 | `onSuccess?.()` 回调后无任何本地状态保存（无 cookie、无 localStorage、无 context），用户刷新后无法识别已登录状态 | 后续页面无法判断是否已登录 |
| 落地页登录后无企业信息补录步骤 | 落地页登录 | `userTimeline` 中有"手机号授权登录并补充企业信息"事件，但当前登录表单无 `company`/`industry`/`size`/`identity` 字段 | 用户注册数据不完整，admin 详情页对应字段将为空 |
| 预约记录为硬编码字符串 | 用户详情页"预约记录"标签页 | `已预约 2026-06-06 14:00，与周顾问进行电话沟通。` 硬编码，无动态数据 | 所有用户显示相同预约内容 |
| 管理后台"记住登录状态"无实际效果 | 管理后台登录页 | `Checkbox defaultChecked` 展示但未绑定任何逻辑，token 始终写入 localStorage（不区分是否选中） | 用户体验欺骗，关闭浏览器后 token 仍然存在 |
| 编辑标签/生成线索操作无实现 | 用户列表页行操作 | `moreItems` 配置了"编辑标签"和"生成线索"，但 `onMoreClick` 未传入 `TableRowActions` 组件 | 点击无响应 |
| 批量打标签/导出用户操作无实现 | 用户列表页头部 | 按钮渲染但无 `onClick` 事件 | 点击无响应 |

---

## 9. 共用模型

以下模型在两个系统中都涉及，需要共同约定接口契约：

| 实体 | landing-page 视角 | admin-system 视角 | 共同字段 |
|------|-------------------|-------------------|----------|
| User（端用户） | 注册者本人，读写自己的 phone/company 等 | 运营管理被管理对象，读取全量字段，写 tags/leadStatus | `phone`, `company`, `identity`, `industry`, `size`, `registeredAt` |
| Auth Token | Supabase Auth JWT，标识端用户身份 | 独立的 admin token（Supabase Auth 可用另一套，或同一套加 role 区分） | — |
| Activity（活动） | 来源活动名称（只读） | 活动 CRUD | `id`, `name` |
| QR Code（二维码） | 扫码入口（只读，inviteCode 参数） | 二维码 CRUD | `inviteCode`, `id` |

**建议**：`sourceActivity` 字段改为存活动 `id`（如 `A001`），展示时 join 活动名称；`sourceQr` 改为存二维码 `id`（如 `QR-ACT-001`）。

---

## 10. 推荐迁移顺序

| 优先级 | 模块 | 原因 |
|--------|------|------|
| P0 | 端用户注册/登录（landing-page） | 是整个业务漏斗的起点，`phone + code` 为最简路径，先跑通 Supabase Auth 手机号登录 |
| P0 | 修复 `leadStatus` 枚举（补充"未生成"值） | 高风险类型冲突，影响用户列表统计卡片逻辑正确性 |
| P1 | 管理后台登录（真实 JWT） | 替换 localStorage mock token，支持真实角色权限 |
| P1 | 用户注册时补录企业信息（landing-page） | 补全 `company`, `industry`, `size`, `identity` 字段，admin 详情页才能展示完整 |
| P1 | 用户列表 API + 筛选逻辑 | 当前筛选完全无效，影响运营基本使用 |
| P1 | 修复关联方式（按 userId 而非 name 关联报告/线索/问答/时间线） | 高风险数据隔离问题 |
| P2 | 用户详情各标签页 API（timeline / qa / materials / report / lead） | 各个子模块数据按 userId 隔离 |
| P2 | 编辑标签 / 生成线索操作 | 运营核心动作，当前完全占位 |
| P3 | 管理员角色体系（market_ops / tax_advisor / admin） | CLAUDE.md 已规定，需在接入认证时一并设计 |
| P3 | 导出用户、批量打标签 | 运营效率功能，可最后实现 |

---

## 11. 不确定项

| # | 不确定项 | 文件 | 假设 | 影响范围 |
|---|----------|------|------|----------|
| 1 | `phone` 字段在数据库中是否存完整手机号还是脱敏格式？落地页注册时提交的是完整手机号，但 Mock 展示的是脱敏格式 | `mock-data.ts:36-41`, `login-register-form.tsx:29` | 假设数据库存完整手机号，展示层做脱敏处理 | 影响 User 表设计和 API 响应 DTO |
| 2 | 微信 `openid` 与手机号是否对应同一 Supabase Auth 账号？当前 Mock 中两者并存在同一 User 记录，但实际 Supabase 手机号登录和微信 OAuth 是两个 provider | `mock-data.ts:36` | 假设两种登录方式最终合并为同一用户账号（phone 为主 key，openid 为补充绑定） | 影响 Supabase Auth 配置和用户合并逻辑 |
| 3 | `tags` 字段是运营人工标注还是系统自动计算？当前 Mock 中混有"高意向"（运营判断）和"关注公转私"（内容偏好）两类 | `mock-data.ts:36-41` | 假设两类标签共存，但需要区分来源（`tag.source: 'manual' \| 'system'`） | 影响标签数据模型设计 |
| 4 | `userTimeline` 中"手机号授权登录并补充企业信息"是同一步完成还是两步完成？当前落地页登录表单仅有手机号+验证码，无企业信息字段 | `mock-data.ts:44-45`, `login-register-form.tsx` | 假设是两步：先手机号登录，再弹出补充信息表单 | 影响落地页注册流程设计和 User 表的 nullable 字段 |
| 5 | 管理后台的三种角色（市场运营/税务顾问/管理者）权限边界如何划分？当前代码仅有 `admin` vs 非 `admin` 两级 | `admin-shell.tsx:80`, `CLAUDE.md` | 假设管理者=超级管理员，市场运营和税务顾问为普通角色，按页面粒度做路由级权限控制 | 影响 AdminUser 表设计、登录接口响应、路由守卫逻辑 |
| 6 | `sourceQr` 存的是 `qrCodeItems.id`（如 `QR-ACT-001`）还是 `inviteCode`（如 `ACT20260702`）？Mock 数据两者不完全一致（用户 1 的 sourceQr 为 `ACT-20260702-001`，但二维码表中对应 inviteCode 为 `ACT20260702`） | `mock-data.ts:36`, `mock-data.ts:72` | 假设应该存二维码 `id`，展示时 join 二维码名称 | 影响 User 表 `source_qr_id` 外键设计 |

---

**高风险不一致项汇总（需优先处理）**：

1. `leadStatus` 枚举缺少"未生成"值，用户列表统计逻辑直接依赖该值，真实接入后统计结果将错误。
2. 关联方式用 `user.name` 字符串匹配报告、线索、问答，存在姓名重复时数据污染风险，必须改为 `userId` 外键关联。
3. 管理后台 token 为固定字符串，admin-shell 的认证守卫形同虚设，接入 Supabase 后需同步替换整个会话机制。
4. 落地页注册后无任何会话状态持久化，整个登录流程的"已登录"状态在客户端完全缺失。
