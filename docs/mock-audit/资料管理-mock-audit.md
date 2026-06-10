# 资料管理模块 Mock 数据审计报告

**审计日期**：2026-06-10
**审计员**：mock-auditor agent
**项目阶段**：MVP 原型阶段，无真实数据库和身份认证
**关联报告**：`docs/mock-audit/用户管理-mock-audit.md`

---

## 1. 审计范围

| 系统 | 文件路径 | 页面 / 用途 |
|------|----------|-------------|
| admin-system | `拓客系统-管理后台/app/materials-admin/page.tsx` | 资料管理后台（列表、上传、预览、领取数据） |
| admin-system | `拓客系统-管理后台/lib/mock-data.ts` | `materialItems` 数组及相关类型（第 79–85 行） |
| admin-system | `拓客系统-管理后台/app/users/[id]/page.tsx` | 用户详情页"资料领取记录"标签页（关联使用） |
| landing-page | `拓客系统-落地页/app/materials/page.tsx` | 资料领取页路由入口 |
| landing-page | `拓客系统-落地页/components/mobile/materials-page.tsx` | 资料领取页核心组件 |
| landing-page | `拓客系统-落地页/components/mobile/event-landing-page.tsx` | 活动落地页内嵌资料领取入口（补充来源） |

---

## 2. Mock 来源清单

| 来源类型 | 文件 | 具体内容 | 证据位置 |
|----------|------|----------|----------|
| 硬编码对象数组 | `lib/mock-data.ts` | `materialItems` 数组，5 条资料目录记录 | `mock-data.ts:79-85` |
| 组件内硬编码数组 | `components/mobile/materials-page.tsx` | `initialMaterials` 数组，6 条资料，带 `status` 字段 | `materials-page.tsx:52-119` |
| 组件内硬编码数组 | `components/mobile/event-landing-page.tsx` | `materials` 数组，4 条资料，带 `downloaded` 字段 | `event-landing-page.tsx:53-86` |
| 硬编码前端状态 | `components/mobile/materials-page.tsx` | `isLoggedIn = true`，MVP 阶段绕过登录校验 | `materials-page.tsx:137` |
| 硬编码前端状态 | `app/materials/page.tsx` | 注释说明"MVP 阶段默认已登录，跳过登录界面" | `app/materials/page.tsx:3-5` |
| 硬编码前端状态 | `components/mobile/event-landing-page.tsx` | `isLoggedIn: initialLoggedIn = false`，默认未登录但可通过弹窗切换 | `event-landing-page.tsx:90` |
| 计算字段写死 | `app/materials-admin/page.tsx` | `claimRate = Math.round((current.claims / current.downloads) * 100)`，从 Mock 数据计算 | `materials-admin/page.tsx:60` |
| 写死统计数据 | `app/materials-admin/page.tsx` | `summary` 由 `materialItems` 聚合得出（total/online/downloads/claims/locked），总数固定为 5 | `materials-admin/page.tsx:32-43` |
| 写死图表数据 | `app/materials-admin/page.tsx` | 领取趋势 `[42, 68, 51, 92, 120, 109, 162]`，硬编码 7 天数据 | `materials-admin/page.tsx:179` |
| 写死用户画像文字 | `app/materials-admin/page.tsx` | "企业老板占比 46%，财务负责人占比 38%" 等 3 条硬编码文字 | `materials-admin/page.tsx:184-186` |
| 前端状态模拟领取操作 | `components/mobile/materials-page.tsx` | `handleClaim` 函数仅修改本地 state（`downloads + 1`，`status: 'claimed'`），无 API 调用 | `materials-page.tsx:146-164` |
| 前端状态模拟下载操作 | `components/mobile/event-landing-page.tsx` | `downloadedMaterials` 数组仅存 state，无 API 调用 | `event-landing-page.tsx:96,103-105` |
| 误用资料目录当领取记录 | `app/users/[id]/page.tsx` | `materialItems.slice(0, 3)` 展示为用户"资料领取记录"，未按 userId 过滤 | `users/[id]/page.tsx:58` |
| `materialTypeOptions` 硬编码 | `app/materials-admin/page.tsx` | 类型枚举选项（沙龙课件/政策资料/工具表/案例资料）写死在组件内 | `materials-admin/page.tsx:11-17` |

---

## 3. 页面数据需求

### 3.1 资料管理后台（`admin-system/app/materials-admin/page.tsx`）

**概览统计卡片（5 张）**

| 指标 | 计算方式 | 字段依赖 |
|------|----------|----------|
| 资料总数 | `materialItems.length` | count |
| 已上架数 | `item.status === '已上架'` | `status` |
| 领取次数（累计） | `sum(item.claims)` | `claims` |
| 下载次数（累计） | `sum(item.downloads)` | `downloads` |
| 需留资资料数 | `item.needLogin \|\| item.needCompanyInfo` | `needLogin`, `needCompanyInfo` |

**筛选条件**

| 筛选项 | 数据来源 | 字段依赖 |
|--------|----------|----------|
| 名称 / 格式搜索 | 用户输入 | `name`, `format` |
| 资料类型 | 硬编码枚举（沙龙课件/政策资料/工具表/案例资料） | `type` |
| 关联活动 | `activities` 列表动态生成 | `activities.name` → `materialItem.activity` |
| 状态 | 硬编码枚举（已上架/草稿/已下架） | `status` |

**资料列表表格（9 列实际使用）**

| 列 | 字段 | 备注 |
|----|------|------|
| 资料名称 | `name` | 同行展示 `id` 和 `createdAt` |
| 资料 ID | `id` | 副文本展示 |
| 资料类型 | `type` | Tag 展示 |
| 文件格式 | `format` | Tag + 颜色映射 |
| 关联活动 | `activity` | 纯文本 |
| 需要登录 | `needLogin` | boolean → Tag |
| 补充企业信息 | `needCompanyInfo` | boolean → Tag |
| 状态 | `status` | Tag + statusTheme |
| 下载次数 | `downloads` | 数字 |
| 创建时间 | `createdAt` | 文本 |

注意：`claims` 字段在列表表格中**未展示**，仅在概览卡片聚合和领取数据 Drawer 中使用。

**上传 / 编辑表单（Dialog）**

| 表单字段 | 类型 | 来源 | 证据位置 |
|----------|------|------|----------|
| 资料名称 | `string` | `current.name` | `materials-admin/page.tsx:143` |
| 资料类型 | `string`（枚举） | `current.type` | `materials-admin/page.tsx:144` |
| 文件上传 | 文件 | Upload 组件（无真实上传） | `materials-admin/page.tsx:145` |
| 关联活动 | `string` | `current.activity` | `materials-admin/page.tsx:146` |
| 是否需要登录 | `boolean` | `current.needLogin` | `materials-admin/page.tsx:147` |
| 是否需要补充企业信息 | `boolean` | `current.needCompanyInfo` | `materials-admin/page.tsx:148` |
| 状态 | `string`（枚举） | `current.status` | `materials-admin/page.tsx:149` |
| 上传进度 | `number` | 硬编码 `68`，Progress 组件展示 | `materials-admin/page.tsx:150` |

**预览 Dialog**

| 展示字段 | 来源字段 | 证据位置 |
|----------|----------|----------|
| 文件格式 | `format` | `materials-admin/page.tsx:156` |
| 资料名称 | `name` | `materials-admin/page.tsx:156` |
| 资料类型 | `type` | `materials-admin/page.tsx:158` |
| 关联活动 | `activity` | `materials-admin/page.tsx:159` |
| 领取条件（needLogin + needCompanyInfo 组合展示） | `needLogin`, `needCompanyInfo` | `materials-admin/page.tsx:160` |
| 状态 | `status` | `materials-admin/page.tsx:161` |

注意：预览 Dialog 无 `fileUrl` / `fileSize`，缺少文件实际内容展示。

**领取数据 Drawer**

| 展示字段 | 来源字段 | 是否真实数据 | 证据位置 |
|----------|----------|-------------|----------|
| 资料名称 | `name` | 是 | `materials-admin/page.tsx:168` |
| 资料类型 | `type` | 是 | `materials-admin/page.tsx:169` |
| 文件格式 | `format` | 是 | `materials-admin/page.tsx:169` |
| 关联活动 | `activity` | 是 | `materials-admin/page.tsx:169` |
| 领取次数 | `claims` | 是（Mock 数据） | `materials-admin/page.tsx:173` |
| 下载次数 | `downloads` | 是（Mock 数据） | `materials-admin/page.tsx:174` |
| 领取后下载率 | `claims / downloads * 100` | 计算字段，来自 Mock | `materials-admin/page.tsx:60,175` |
| 需留资（是/否） | `needLogin \|\| needCompanyInfo` | 是 | `materials-admin/page.tsx:176` |
| 领取趋势（7天柱状图） | 硬编码数组 | **否，完全写死** | `materials-admin/page.tsx:179` |
| 领取用户画像 | 硬编码文字 | **否，完全写死** | `materials-admin/page.tsx:184-186` |

---

### 3.2 落地页资料领取页（`landing-page/components/mobile/materials-page.tsx`）

**顶部统计数字（3 个）**

| 指标 | 计算方式 | 字段依赖 |
|------|----------|----------|
| 资料总数 | `materials.length` | count |
| 已领取数 | `material.status === 'claimed'` | `status` |
| 需补充信息数 | `material.needsCompanyInfo === true` | `needsCompanyInfo` |

**分类 Tab（4 个）**

| Tab | 枚举值 | 图标 |
|-----|--------|------|
| 沙龙课件 | `courseware` | `BookOpen` |
| 政策解读 | `policy` | `ScrollText` |
| 自查表 | `checklist` | `ClipboardCheck` |
| 案例资料 | `case` | `FolderOpen` |

注意：admin-system 的类型枚举为"政策资料"，landing-page 为"政策解读"；admin-system 无"自查表"分类（对应"工具表"）——这是一个字段值不一致冲突（见第 7 节）。

**资料卡片（每条资料展示的字段）**

| 字段 | 来源字段 | 证据位置 |
|------|----------|----------|
| 资料类型标签 | `type` | `materials-page.tsx:262-263` |
| 文件格式标签 | `format` | `materials-page.tsx:264-265` |
| 资料名称 | `name` | `materials-page.tsx:269` |
| 资料描述 | `description` | `materials-page.tsx:275` |
| 下载次数 | `downloads` | `materials-page.tsx:281` |
| 是否需要补充企业信息 | `needsCompanyInfo` | `materials-page.tsx:284-298` |
| 领取状态 | `status` | `materials-page.tsx:241,302-317` |
| 格式图标（PDF/Excel） | `format` | `materials-page.tsx:252-259` |

**领取操作**

`handleClaim` 在本地修改 `status: 'claimed'` 并将 `downloads + 1`，无 API 调用，无服务端记录。

**底部固定按钮**

跳转路由 `/risk-assessment`，与资料数据无直接关联，不产生字段需求。

---

### 3.3 活动落地页内嵌资料模块（`landing-page/components/mobile/event-landing-page.tsx`）

| 字段 | 来源字段 | 证据位置 |
|------|----------|----------|
| 资料标题 | `title`（不同于 `name`） | `event-landing-page.tsx:57-85` |
| 文件类型 | `type`（"PDF" / "Excel"，与 admin 枚举不同） | `event-landing-page.tsx:57-85` |
| 文件大小 | `size`（"2.4 MB" 字符串） | `event-landing-page.tsx:57-85` |
| 图标 | `icon`（Lucide 组件引用） | `event-landing-page.tsx:57-85` |
| 是否已领取 | `downloaded`（boolean，初始值部分为 true） | `event-landing-page.tsx:57-85` |

注意：`event-landing-page.tsx` 中的资料数组与 `mock-data.ts` 的 `materialItems` 完全独立，字段结构不同，是另一个孤立的 Mock。

---

### 3.4 用户详情页资料标签页（`admin-system/app/users/[id]/page.tsx`）

使用 `materialItems.slice(0, 3)` 展示，实际展示字段：

| 字段 | 来源字段 | 证据位置 |
|------|----------|----------|
| 资料名称 | `name` | `users/[id]/page.tsx:58` |
| 资料类型 | `type` | `users/[id]/page.tsx:58` |
| 创建时间（误作领取时间） | `createdAt` | `users/[id]/page.tsx:58` |

**该标签页展示的不是领取记录，是资料目录的前 3 条数据。**

---

## 4. 业务实体和字段

本模块涉及两个完全不同的业务实体，当前 Mock 将其混淆。

---

### 4.1 资料目录（Material）— 运营上传、管理的资料条目

#### 数据库实体（需持久化）

| 字段 | 类型 | 分类 | 来源系统 | 证据位置 |
|------|------|------|----------|----------|
| `id` | `string`（如 `MAT-001`） | 持久化（主键） | admin | `mock-data.ts:80` |
| `name` | `string` | 持久化 | admin + landing | `mock-data.ts:80` |
| `type` | `string`（枚举） | 持久化 | admin + landing | `mock-data.ts:80` |
| `format` | `string`（枚举：PDF/XLSX/PPTX/DOCX/Excel） | 持久化 | admin + landing | `mock-data.ts:80` |
| `activity` | `string`（关联活动名称） | 持久化（应改为活动 id 外键） | admin | `mock-data.ts:80` |
| `needLogin` | `boolean` | 持久化（领取门槛） | admin | `mock-data.ts:80` |
| `needCompanyInfo` | `boolean` | 持久化（领取门槛） | admin + landing | `mock-data.ts:80` |
| `status` | `string`（枚举：已上架/草稿/已下架） | 持久化 | admin | `mock-data.ts:80` |
| `downloads` | `number` | 持久化（系统计数，写多读多） | admin + landing | `mock-data.ts:80` |
| `claims` | `number` | 持久化（系统计数） | admin | `mock-data.ts:80` |
| `createdAt` | `string` / `timestamp` | 持久化（系统自动） | admin | `mock-data.ts:80` |
| `fileUrl` | `string` | 持久化（文件存储 URL） | **缺失** | — |
| `fileSize` | `string` / `number` | 持久化（文件大小） | **仅 event-landing-page 有，主 mock 无** | `event-landing-page.tsx:58-85` |
| `description` | `string` | 持久化（资料描述） | **仅 materials-page 有，admin mock 无** | `materials-page.tsx:57-119` |

#### Mock 中存在但页面未使用的字段

| 字段 | 存在于 | 页面是否使用 | 备注 |
|------|--------|-------------|------|
| `claims`（列表表格） | `mock-data.ts:80-85` | 列表表格未展示 | 仅用于概览卡片聚合和 Drawer |

#### 列表 DTO（`GET /api/materials`）

`id`, `name`, `type`, `format`, `activity`, `needLogin`, `needCompanyInfo`, `status`, `downloads`, `claims`, `createdAt`

#### 详情 DTO（`GET /api/materials/:id`）

列表 DTO 全部字段 + `fileUrl`, `fileSize`, `description`

#### 表单 DTO（上传/编辑，`POST /api/materials` 和 `PATCH /api/materials/:id`）

`name`, `type`, `format`（由上传文件推断）, `activity`, `needLogin`, `needCompanyInfo`, `status`, `fileUrl`（上传后得到）

#### 落地页资料列表 DTO（`GET /api/materials?activityId=&status=已上架`）

`id`, `name`, `type`, `format`, `description`, `downloads`, `needsCompanyInfo`（注意命名差异）, `category`（仅落地页分类 Tab 需要）

---

### 4.2 领取记录（MaterialClaim）— 用户领取资料产生的 join 表记录

当前整个 codebase 中**不存在**这个实体的 Mock 数据。该实体完全缺失，需要从业务逻辑推断其字段。

#### 数据库实体（需持久化，当前 Mock 缺失）

| 字段 | 类型 | 分类 | 推断来源 |
|------|------|------|----------|
| `id` | `string` / `uuid` | 持久化（主键） | 标准 join 表设计 |
| `userId` | 外键 → `User.id` | 持久化（关联字段） | 用户详情页"资料领取记录"标签页需要按 userId 查询 |
| `materialId` | 外键 → `Material.id` | 持久化（关联字段） | 同上 |
| `claimedAt` | `timestamp` | 持久化（系统自动） | `userTimeline` 中有"领取资料"事件时间 `mock-data.ts:46` |
| `downloadedAt` | `timestamp` / `null` | 持久化（可选，记录实际下载时间） | `claims` vs `downloads` 两个计数说明"领取"和"下载"是两个动作 |
| `activityId` | 外键 → `Activity.id` | 持久化（记录领取时来源活动） | 运营分析需求 |

#### 列表 DTO（`GET /api/users/:id/materials`，用户详情页）

`id`, `materialId`, `materialName`, `materialType`, `claimedAt`

注意：`users/[id]/page.tsx:58` 当前用 `item.createdAt`（资料创建时间）误作领取时间，真实应为 `claimedAt`。

#### 统计 DTO（`GET /api/materials/:id/stats`，领取数据 Drawer）

`claims`（总领取次数）, `downloads`（总下载次数）, `claimDownloadRate`（计算字段）, `trend: number[]`（按日领取趋势）, `userPortrait`（用户画像，需单独分析）

---

### 4.3 资料类型枚举对比

| 枚举值 | admin-system | landing-page（materials-page） | landing-page（event-landing-page） |
|--------|--------------|-------------------------------|----------------------------------|
| 课件类 | `沙龙课件` | `courseware`（分类 key）+ `type: '课程课件'`/`'答疑整理'` | — |
| 政策类 | `政策资料` | `policy`（分类 key）+ `type: '政策资料'`/`'专题指南'` | — |
| 工具类 | `工具表` | `checklist`（分类 key）+ `type: '工具表'` | — |
| 案例类 | `案例资料` | `case`（分类 key）+ `type: '案例资料'` | 无分类 |
| 文件格式 | `PDF/XLSX/PPTX/DOCX` | `"PDF" \| "Excel"` | `"PDF" \| "Excel"` |

---

## 5. 页面操作

### 资料管理后台

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 搜索/筛选资料 | 查询按钮 | 无效（无过滤逻辑） | `GET /api/materials?name=&type=&activity=&status=&page=&pageSize=` |
| 重置筛选 | 重置按钮 | 无效 | — |
| 上传资料 | 上传资料按钮 / 弹窗保存 | 弹窗渲染，Upload 无真实上传，保存无 API | `POST /api/materials`（multipart/form-data） |
| 编辑资料 | 更多菜单"编辑" | 打开弹窗，保存无 API | `PATCH /api/materials/:id` |
| 上架/下架 | 更多菜单"上架"/"下架" | `MessagePlugin.success` 占位 | `PATCH /api/materials/:id/status` |
| 预览资料 | 操作列"预览" | 打开 Dialog，无真实文件预览 | `GET /api/materials/:id`（含 fileUrl） |
| 查看领取数据 | 更多菜单"领取数据" | 打开 Drawer，趋势和画像完全写死 | `GET /api/materials/:id/stats` |
| 删除资料 | 更多菜单"删除" | `MessagePlugin.success` 占位 | `DELETE /api/materials/:id` |
| 批量上架 | 头部按钮 | 按钮渲染，无 onClick 事件 | `PATCH /api/materials/bulk-status` |
| 批量下架 | 头部按钮 | 按钮渲染，无 onClick 事件 | `PATCH /api/materials/bulk-status` |
| 导出领取数据 | 头部按钮 | 按钮渲染，无 onClick 事件 | `GET /api/materials/export-claims` |
| 下载资料（预览 Dialog） | 下载资料按钮 | 按钮渲染，无下载逻辑 | `GET /api/materials/:id/download`（重定向到 fileUrl） |

### 落地页资料领取（materials-page.tsx）

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 切换分类 Tab | Tab 切换 | 纯前端 state 过滤，有效 | — |
| 领取资料 | 领取资料按钮 | `handleClaim` 修改本地 state，无 API | `POST /api/material-claims`（body: `{ materialId, userId }`） |
| 领取后下载文件 | 同上（领取即下载） | 无文件下载逻辑 | `GET /api/materials/:id/download` |
| 补充信息后领取 | 补充信息后领取按钮 | 按钮存在但点击后同"领取资料"逻辑，未触发补充企业信息流程 | `GET /api/auth/me`（校验企业信息是否完整）→ 不完整时跳转补录表单 |
| 跳转测评 | 底部固定按钮 | `router.push('/risk-assessment')` | — |

### 活动落地页资料入口（event-landing-page.tsx）

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 领取资料（已登录） | 领取按钮 | 修改 `downloadedMaterials` state，无 API | `POST /api/material-claims` |
| 领取资料（未登录） | 领取按钮 / 全部领取按钮 | 弹出 LoginModal | — |
| 登录成功后继续领取 | 登录弹窗成功回调 | `setIsLoggedIn(true)`，但未重新触发领取操作 | `POST /api/material-claims` |

---

## 6. 建议 API

### 资料目录管理（admin-system）

| 方法 | 路径 | 请求体 / 参数 | 响应 |
|------|------|--------------|------|
| `GET` | `/api/materials` | `name`, `type`, `activity`, `status`, `page`, `pageSize` | `{ items: MaterialListDTO[], total: number }` |
| `POST` | `/api/materials` | `multipart/form-data`：`name`, `type`, `activity`, `needLogin`, `needCompanyInfo`, `status`, `file` | `MaterialDetailDTO` |
| `GET` | `/api/materials/:id` | — | `MaterialDetailDTO` |
| `PATCH` | `/api/materials/:id` | 同 POST（无 file 时不替换文件） | `MaterialDetailDTO` |
| `PATCH` | `/api/materials/:id/status` | `{ status: '已上架' \| '草稿' \| '已下架' }` | `{ id, status }` |
| `DELETE` | `/api/materials/:id` | — | `{ success: boolean }` |
| `PATCH` | `/api/materials/bulk-status` | `{ ids: string[], status: string }` | `{ updated: number }` |
| `GET` | `/api/materials/:id/download` | — | 文件流（重定向到存储 URL） |
| `GET` | `/api/materials/:id/stats` | `dateFrom?`, `dateTo?` | `MaterialStatsDTO`（含趋势数组、画像数据） |
| `GET` | `/api/materials/export-claims` | 同筛选参数 | CSV / XLSX 文件流 |

### 资料目录查询（landing-page）

| 方法 | 路径 | 参数 | 响应 |
|------|------|------|------|
| `GET` | `/api/materials` | `activityId`, `status=已上架`, `page`, `pageSize` | `{ items: MaterialLandingDTO[], total: number }` |

### 领取记录（landing-page + admin-system）

| 方法 | 路径 | 请求体 / 参数 | 响应 |
|------|------|--------------|------|
| `POST` | `/api/material-claims` | `{ materialId: string }` | `{ claimId: string, claimedAt: string, downloadUrl: string }` |
| `GET` | `/api/users/:id/materials` | `page`, `pageSize` | `{ items: MaterialClaimDTO[], total: number }` |

注意：`POST /api/material-claims` 需要端用户 JWT 认证，从 token 中读取 `userId`，不允许客户端直接传 `userId`。

---

## 7. 字段和类型冲突

| 冲突描述 | 文件 A | 文件 B | 字段 | 风险等级 |
|----------|--------|--------|------|----------|
| **资料目录字段命名不一致：`needCompanyInfo` vs `needsCompanyInfo`**。admin mock 用 `needCompanyInfo`（无 s），landing-page 组件用 `needsCompanyInfo`（有 s）。同一业务字段两套命名，共享类型定义时必须统一。 | `mock-data.ts:80-85` | `materials-page.tsx:29,38` | `needCompanyInfo` / `needsCompanyInfo` | 高风险 |
| **资料类型枚举值不一致**。admin 用中文枚举（沙龙课件/政策资料/工具表/案例资料），landing-page 用英文 key（courseware/policy/checklist/case）且对应的 `type` 字段还有细分值（课程课件/答疑整理/政策资料/专题指南/工具表/案例资料）。两端无法直接映射。 | `mock-data.ts:80-85` | `materials-page.tsx:25-49` | `type` / `category` | 高风险 |
| **`activity` 字段存名称字符串而非 id**。`materialItems.activity` 存活动名称（如"金税四期风险识别专题课"），`activities` 表有唯一 `id`（如 `A003`）。活动改名将导致关联断裂，且无法与活动管理模块做 JOIN 查询。 | `mock-data.ts:80` | `mock-data.ts:28-33` | `activity` vs `activities.id` | 高风险 |
| **文件格式枚举范围不一致**。admin mock 有 PDF/XLSX/PPTX/DOCX 四种，landing-page 只有 "PDF" / "Excel" 两种（且 "Excel" 对应 admin 的 "XLSX"）。落地页无法展示 PPTX/DOCX 格式资料，图标和颜色映射也不覆盖这些格式。 | `mock-data.ts:80-85` | `materials-page.tsx:35` | `format` | 中风险 |
| **`status` 字段含义不同**。admin 中 `status` 是资料的上架状态（已上架/草稿/已下架），landing-page 中 `status` 是单条资料对当前用户的领取状态（available/claimed/needs_company_info）。同名字段完全不同语义，接入真实 API 后极易混淆。 | `mock-data.ts:80` | `materials-page.tsx:27` | `status` | 高风险 |
| **`id` 字段类型不一致**。admin mock 用字符串（`'MAT-001'`），landing-page 用数字（`id: 1`）。共享类型时必须统一。 | `mock-data.ts:80` | `materials-page.tsx:30` | `id` | 中风险 |
| **领取记录完全缺失**。`materialItems` 仅是资料目录，不含任何领取者信息，但用户详情页"资料领取记录"标签页直接用 `materialItems.slice(0, 3)` 展示（且 `createdAt` 被误作领取时间），所有用户看到同样的 3 条资料。领取记录是完全独立的实体，当前 Mock 中不存在。 | `mock-data.ts:79-85` | `users/[id]/page.tsx:58` | `userId`（缺失）/ `claimedAt`（缺失） | 高风险 |
| **`event-landing-page.tsx` 资料数组与主 mock 完全孤立**。`event-landing-page.tsx` 内的 `materials` 数组字段结构（`title`/`type`/`size`/`icon`/`downloaded`）与 `mock-data.ts` 的 `materialItems`（`name`/`type`/`format`/`needLogin`/`status`）完全不同，是独立维护的第二套 Mock，无任何共享。 | `mock-data.ts:79-85` | `event-landing-page.tsx:53-86` | 多字段 | 中风险 |
| **领取后无下载逻辑**。`materials-page.tsx` 的 `handleClaim` 仅改变 `status` 为 `claimed` 并将 `downloads + 1`，但不触发任何文件下载。admin 端的"下载次数"统计因此无对应的触发来源。 | `materials-page.tsx:146-164` | `mock-data.ts:80`（`downloads` 字段） | `downloads` | 中风险 |

---

## 8. 页面状态缺口

| 缺口描述 | 页面 | 当前状态 | 影响 |
|----------|------|----------|------|
| **筛选逻辑完全无效**。admin 资料列表的 Input / Select（名称、类型、活动、状态）均无 `onChange` 和过滤逻辑，查询和重置按钮无事件处理 | 资料管理后台 | 占位 | 筛选功能完全无效 |
| **文件上传无真实实现**。`Upload` 组件渲染但无 `onChange`、无上传进度真实逻辑（Progress 写死 68%），保存按钮无 API 调用 | 资料管理后台上传 Dialog | 占位 | 无法真实上传文件 |
| **领取门槛未实际拦截**。landing-page 的 `needsCompanyInfo` 字段显示"补充信息后领取"，`handleClaim` 函数对 `status === 'needs_company_info'` 的资料可以正常调用（直接将 status 改为 `claimed`），未触发企业信息补录流程 | 落地页资料领取 | 逻辑缺口 | 需补充企业信息的资料实际可以被直接领取，门槛失效 |
| **`needLogin` 字段在落地页未使用**。admin mock 中有 `needLogin` 字段，landing-page 的 `MaterialItem` 接口中无此字段，`materials-page.tsx` 的 `isLoggedIn = true` 写死绕过所有登录门槛，未针对 `needLogin` 做差异化处理 | 落地页资料领取 | 逻辑缺口 | 需登录资料实际未做登录校验 |
| **领取后未持久化**。`handleClaim` 仅修改本地 state，用户刷新页面后领取状态丢失，领取次数归零 | 落地页资料领取 | 无持久化 | 无法支持"已领取"状态跨 session 保持 |
| **领取数据 Drawer 趋势完全写死**。领取趋势 `[42, 68, 51, 92, 120, 109, 162]` 和用户画像文字对所有资料展示同样内容，无论当前是哪条资料的 Drawer | 资料管理后台领取数据 Drawer | 写死 Mock | 数据无意义，接入后需替换为真实统计 API |
| **上架/下架/删除操作无状态回写**。操作后仅 `MessagePlugin.success` 提示，列表中对应行的状态不变（因为 `materialItems` 是 import 的常量，未用 state 管理） | 资料管理后台 | 占位 | 操作无实际效果 |
| **登录成功后未重新触发领取**。`event-landing-page.tsx` 中用户未登录时点击领取跳出 LoginModal，登录成功后 `setIsLoggedIn(true)` 但未触发原来的领取操作，用户需重新点击 | 活动落地页资料入口 | 逻辑缺口 | 登录流程中断，UX 不连贯 |
| **批量上架/下架/导出领取数据无实现**。三个头部按钮渲染但无 `onClick` | 资料管理后台 | 占位 | 完全无效 |

---

## 9. 共用模型

以下模型在两个系统中都有涉及，需要共同约定接口契约：

| 实体 | landing-page 视角 | admin-system 视角 | 需统一的关键字段 |
|------|-------------------|-------------------|-----------------|
| Material（资料目录） | 按分类展示可领取资料，读取 `name`/`type`/`format`/`description`/`downloads`/`needsCompanyInfo` | CRUD 全量字段，额外需要 `claims`/`createdAt`/`needLogin`/`status`（上架状态） | `id`（类型：`string`）、`name`、`format`（统一为 PDF/XLSX/PPTX/DOCX）、`needCompanyInfo`（去掉 s）、`category`（新增字段，替代两端各自的类型 key） |
| MaterialClaim（领取记录） | 创建领取记录（`POST`），读取个人领取状态（`status` 字段） | 读取按用户维度的领取列表、按资料维度的领取统计 | `userId`, `materialId`, `claimedAt`, `downloadedAt` |
| Activity（活动） | 无直接引用（`materials-page.tsx` 无活动字段） | `materials.activity` 关联活动名称 | 建议改为外键 `activityId`，展示时 join `activities.name` |

---

## 10. 推荐迁移顺序

| 优先级 | 任务 | 原因 |
|--------|------|------|
| P0 | 统一 `needCompanyInfo` 命名（去掉 s），确定 `type`/`category` 枚举方案 | 高风险字段冲突，影响共享类型定义，是所有后续开发的基础 |
| P0 | 统一 `status` 字段语义（资料上架状态 vs 用户领取状态），重命名落地页字段为 `claimStatus` | 高风险同名不同义冲突，接入 API 后必然产生 Bug |
| P0 | 创建 `MaterialClaim` 领取记录表和 `POST /api/material-claims` API | 整个领取流程的数据起点，landing-page 领取操作无服务端记录，stats 无原始数据 |
| P1 | `Material.activity` 改为外键 `activityId`，展示时 join 活动名称 | 数据完整性，活动改名不影响关联 |
| P1 | 实现 `GET /api/materials`（landing-page 侧），替换 `initialMaterials` 硬编码 | landing-page 动态加载上架资料 |
| P1 | 实现 `needLogin` / `needCompanyInfo` 实际拦截逻辑（landing-page） | 领取门槛当前形同虚设 |
| P1 | 实现 `GET /api/users/:id/materials`，替换 `materialItems.slice(0,3)` | 用户详情页领取记录是高风险 Mock 误用（参考用户管理审计报告第 7 节） |
| P2 | 实现 admin 资料管理筛选逻辑（前端过滤或接入 API） | 当前筛选完全无效 |
| P2 | 实现文件上传（对接 Supabase Storage 或腾讯云 COS） | 资料管理核心功能 |
| P2 | 实现 `GET /api/materials/:id/stats`，替换 Drawer 内写死趋势和画像 | 管理后台领取分析功能 |
| P3 | 统一 `event-landing-page.tsx` 内的孤立资料 Mock，对接主 API | 两套孤立 Mock 长期维护成本高 |
| P3 | 实现批量上架/下架/导出功能 | 运营效率功能，可最后实现 |

---

## 11. 不确定项

| # | 不确定项 | 文件 | 假设 | 影响范围 |
|---|----------|------|------|----------|
| 1 | `materials-page.tsx` 的 `category` 分类（courseware/policy/checklist/case）与 admin 的 `type` 是否是同一维度？还是 `category` 是大分类，`type` 是小分类（如 category=courseware 下有 type=课程课件/答疑整理）？ | `materials-page.tsx:25-49`, `mock-data.ts:80` | 假设 `category` 是落地页展示用的大分类 key，`type` 是资料的细分类型标签，两者应共存于 Material 表（`category` 为枚举，`type` 为字符串标签） | 影响 Material 表字段设计和落地页 API 筛选参数 |
| 2 | `claims`（领取次数）和 `downloads`（下载次数）是两个独立动作还是同一动作？当前 `handleClaim` 将两者都+1（但 admin mock 中两者数值不同，`claims >= downloads`，暗示领取不一定下载）。 | `mock-data.ts:80-85`, `materials-page.tsx:158-159` | 假设"领取"是用户点击按钮触发的意向动作（记录 MaterialClaim），"下载"是实际获取文件的动作（可能需要额外点击或自动触发）。两者独立计数。 | 影响 MaterialClaim 表设计、`downloads` 字段更新时机和领取 API 响应 |
| 3 | `needLogin` 和 `needCompanyInfo` 是独立门槛还是层级门槛（needCompanyInfo 隐含 needLogin）？当前 admin mock 中 MAT-001 两者均为 true，MAT-002 只有 needLogin，MAT-004 两者均为 false。 | `mock-data.ts:80-85` | 假设层级关系：`needCompanyInfo = true` 隐含 `needLogin = true`；`needLogin = true` 不一定需要企业信息。即门槛级别：无门槛 < 需登录 < 需登录+企业信息。 | 影响领取拦截逻辑设计和 landing-page 分支处理 |
| 4 | 领取数据 Drawer 中的"领取用户画像"（企业老板占比/财务负责人占比）是从用户表聚合计算，还是预计算并存储？ | `materials-admin/page.tsx:183-186` | 假设是从领取记录 JOIN 用户表实时聚合，不单独存储。可能需要独立的数据分析查询，不适合放在普通 CRUD API 中。 | 影响 `GET /api/materials/:id/stats` 的实现复杂度和性能设计 |
| 5 | 资料文件存储在哪里？当前 Mock 中 `materialItems` 无 `fileUrl` 字段，admin 预览 Dialog 也无真实文件展示。是 Supabase Storage 还是腾讯云 COS？ | `materials-admin/page.tsx:154-164` | 假设 Supabase Storage（与数据库同平台），`fileUrl` 存 storage 公开 URL 或 signed URL。具体方案需确认安全要求（是否需要 signed URL 防止未授权访问）。 | 影响 Material 表 `fileUrl` 字段类型和文件下载 API 设计 |
| 6 | 落地页资料领取是否需要绑定活动上下文（即用户从哪个活动进入，领取了哪个活动的资料）？`materials-page.tsx` 当前无活动参数，`event-landing-page.tsx` 有活动信息但未传入领取逻辑。 | `materials-page.tsx`, `event-landing-page.tsx:42-51` | 假设需要绑定，MaterialClaim 应记录 `activityId`（从 URL 参数或 session 传入），用于活动维度的领取数据分析（admin `activities` 表已有 `materialClaims` 字段计数）。 | 影响 MaterialClaim 表设计、落地页路由参数和 `POST /api/material-claims` 请求体 |

---

**高风险不一致项汇总（需优先处理）**：

1. `needCompanyInfo` vs `needsCompanyInfo` 命名冲突——同一字段在两个系统中拼写不同，共享类型时必须统一，否则 TypeScript 无法跨项目对齐。
2. `status` 字段同名异义——admin 中是资料上架状态（`已上架/草稿/已下架`），landing-page 中是用户对该资料的领取状态（`available/claimed/needs_company_info`）。接入同一 API 后极易产生混淆 Bug。
3. 资料类型枚举两端完全不同——admin 用中文枚举 4 类，landing-page 用英文 key 且有细分，无法直接映射，需要在数据库中增加 `category` 字段或建立映射表。
4. `MaterialClaim` 领取记录实体完全缺失——用户详情页"资料领取记录"用 `materialItems.slice(0,3)` 误充，所有用户看同样 3 条资料，领取记录无法按用户隔离，是高风险数据污染问题（与用户管理审计第 7 节第 5 条对应）。
5. `material.activity` 存名称字符串而非外键 id——与活动管理模块关联方式不安全，活动改名导致数据断裂（与用户管理审计第 7 节 `sourceActivity` 问题同类）。
