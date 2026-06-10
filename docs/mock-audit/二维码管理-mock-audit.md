# 二维码 / 邀请码模块 Mock 数据审计报告

**审计日期**：2026-06-10
**审计员**：mock-auditor agent
**项目阶段**：MVP 原型阶段，无真实数据库和身份认证
**关联报告**：`docs/mock-audit/用户管理-mock-audit.md`（用户模块已标记 sourceQr 不一致问题，本报告深化分析）

---

## 1. 审计范围

| 系统 | 文件路径 | 页面 / 用途 |
|------|----------|-------------|
| admin-system | `拓客系统-管理后台/app/qr-codes/page.tsx` | 二维码 / 邀请码列表与管理主页面 |
| admin-system | `拓客系统-管理后台/lib/mock-data.ts:71-77` | `qrCodeItems` 数组及相关类型 |
| admin-system | `拓客系统-管理后台/app/leads/page.tsx` | 线索管理（引用 `qrCodeItems` 作为筛选来源） |
| admin-system | `拓客系统-管理后台/app/activities/page.tsx` | 活动管理（内嵌二维码预览 Dialog，生成邀请链接） |
| admin-system | `拓客系统-管理后台/app/users/page.tsx` | 用户列表（展示 `sourceQr` 列） |
| admin-system | `拓客系统-管理后台/app/users/[id]/page.tsx` | 用户详情（展示 `sourceQr`、来源记录标签页） |
| landing-page | `拓客系统-落地页/app/page.tsx` | 落地页首页（入口，EventLandingPage 容器） |
| landing-page | `拓客系统-落地页/components/mobile/event-landing-page.tsx` | 落地页主体组件（未读取 URL 参数） |
| landing-page | `拓客系统-落地页/app/risk-assessment/report/page.tsx` | 风险报告页（唯一使用 `useSearchParams` 的落地页） |

---

## 2. Mock 来源清单

| 来源类型 | 文件 | 具体内容 | 证据位置 |
|----------|------|----------|----------|
| 硬编码对象数组 | `lib/mock-data.ts` | `qrCodeItems` 数组，5 条二维码记录，含 `id`、`inviteCode`、类型、绑定活动、顾问、渠道、有效期、状态和三个转化计数字段 | `mock-data.ts:71-77` |
| 页面硬编码选项 | `app/qr-codes/page.tsx` | `qrTypeOptions`（5 种类型）、`advisorOptions`（3 名顾问 + 未绑定）、`channelOptions`（5 个渠道） — 均为写死字符串，未来自数据 | `qr-codes/page.tsx:11-34` |
| 写死分页总数 | `app/qr-codes/page.tsx` | `total: qrCodeItems.length`（当前固定为 5） | `qr-codes/page.tsx:149` |
| 写死统计汇总 | `app/qr-codes/page.tsx` | `summary` 通过 `useMemo` 聚合 `qrCodeItems` 本地数组，非后端接口统计 | `qr-codes/page.tsx:50-61` |
| 写死预览链接格式 | `app/qr-codes/page.tsx` | `` `https://m.example.com/track?qr_id=${current.id}&invite=${current.inviteCode}` `` 硬编码域名和参数格式 | `qr-codes/page.tsx:185` |
| 写死活动邀请链接格式 | `app/activities/page.tsx` | `` `https://m.example.com/event?activity_id=${selectedActivity.id}&invite=${selectedActivity.id}-INVITE` `` | `activities/page.tsx:155` |
| 写死活动邀请码格式 | `app/activities/page.tsx` | `` `${selectedActivity.id}-INVITE` `` 拼接生成，非二维码实体字段 | `activities/page.tsx:152` |
| 硬编码下拉选项（引用） | `app/leads/page.tsx` | 线索筛选"来源二维码"下拉选项，遍历 `qrCodeItems` 用 `item.id` 作为 value | `leads/page.tsx:49` |
| 占位 QR 图形 | `app/qr-codes/page.tsx` | `<div className="qr-box qr-preview-box">QR</div>` 文字占位，无真实二维码图片生成 | `qr-codes/page.tsx:177` |
| 占位 QR 图形（活动） | `app/activities/page.tsx` | `<div className="qr-box">QR</div>` 同样是占位文字 | `activities/page.tsx:149` |
| 仅前端状态的 Dialog | `app/qr-codes/page.tsx` | `createVisible`、`inviteVisible`、`previewVisible` 三个 Dialog 状态，表单提交无任何 API 调用 | `qr-codes/page.tsx:45-47` |
| 搜索框无过滤逻辑 | `app/qr-codes/page.tsx` | `<Input clearable placeholder="搜索二维码名称 / ID / 邀请码" />` 无 `onChange` 和过滤逻辑；所有 Select 筛选器均无绑定 | `qr-codes/page.tsx:85-93` |
| URL 参数未接入 | `拓客系统-落地页/app/page.tsx` | 落地页入口直接渲染 `<EventLandingPage />`，无 `searchParams` 提取，`EventLandingPage` 组件也不接受 `qr_id` 或 `inviteCode` props | `app/page.tsx:1-9`, `event-landing-page.tsx:27-40` |
| 唯一使用 searchParams 的落地页 | `app/risk-assessment/report/page.tsx` | 仅读取 `?score=` 参数渲染风险分数，无 `qr_id` / `invite` 参数消费 | `report/page.tsx:107-110` |

---

## 3. 页面数据需求

### 3.1 二维码管理页（`admin-system/app/qr-codes/page.tsx`）

**统计概览卡片（5 张）**

| 指标 | 计算来源 | 字段依赖 |
|------|----------|----------|
| 二维码总数 | `qrCodeItems.length` | count |
| 启用中数量 | `item.status === '启用中'` | `status` |
| 累计扫码 | `sum(item.scans)` | `scans: number` |
| 注册人数 | `sum(item.registers)` | `registers: number` |
| 线索数 | `sum(item.leads)` | `leads: number` |

**筛选条件**

| 筛选项 | 数据来源 | 字段依赖 | 当前状态 |
|--------|----------|----------|----------|
| 名称 / ID / 邀请码 关键字搜索 | 用户输入 | `name`, `id`, `inviteCode` | 无过滤逻辑 |
| 类型 | 硬编码 `qrTypeOptions` | `type: string` | 无过滤逻辑 |
| 绑定活动 | `activities` 动态生成 | `activity: string` → `activities.name` | 无过滤逻辑 |
| 绑定顾问 | 硬编码 `advisorOptions` | `advisor: string` | 无过滤逻辑 |
| 状态 | 硬编码（启用中 / 暂停中） | `status: string` | 无过滤逻辑 |

**列表表格（12 列实际使用）**

| 列 | 字段 | 字段类型 | 备注 |
|----|------|----------|------|
| 二维码 ID | `id` | `string` | 加粗展示，如 `QR-ACT-001` |
| 名称 + 邀请码 | `name`, `inviteCode` | `string` | 嵌套展示，inviteCode 以 `<small>` 副文本显示 |
| 类型 | `type` | `string`（枚举） | Tag 颜色由 `typeTheme()` 驱动 |
| 绑定活动 | `activity` | `string` | 纯文本，活动名称 |
| 绑定顾问 | `advisor` | `string` | 纯文本，顾问名 |
| 渠道 | `channel` | `string` | 纯文本 |
| 有效期 | `validPeriod` | `string` | 单一字符串，非结构化（含"长期有效"特殊值） |
| 状态 | `status` | `string`（枚举） | Tag 颜色由 `statusTheme()` 驱动 |
| 扫码次数 | `scans` | `number` | |
| 注册人数 | `registers` | `number` | |
| 线索数 | `leads` | `number` | Tag warning 颜色 |
| 操作列 | — | — | 查看、编辑、下载二维码、停用 |

**新建 / 编辑二维码表单（Dialog，7 个字段）**

| 表单字段 | 对应实体字段 | 类型 |
|----------|-------------|------|
| 名称 | `name` | `string` |
| 类型 | `type` | `string`（枚举，5 种） |
| 绑定活动 | `activity` | `string`（活动名称） |
| 绑定顾问 | `advisor` | `string`（顾问名） |
| 绑定渠道 | `channel` | `string`（渠道名） |
| 有效期 | `validPeriod` | `DateRange`（前端为 DateRangePicker，但实体存为单一字符串） |
| 状态 | `status` | `string`（枚举：启用中 / 暂停中） |

注意：`inviteCode` 字段在表单中不存在，仅展示，说明邀请码由系统生成，非用户填写。

**新建邀请码表单（独立 Dialog，5 个字段）**

| 表单字段 | 对应字段 | 类型 |
|----------|---------|------|
| 邀请码名称 | `name`（语义等同） | `string` |
| 绑定顾问 | `advisor` | `string` |
| 绑定活动 | `activity` | `string` |
| 绑定渠道 | `channel` | `string` |
| 有效期 | `validPeriod` | `DateRange` |

注：新建邀请码表单与新建二维码表单字段几乎相同，缺少 `type` 字段（隐含类型为"顾问二维码"）。两个表单在 UI 上独立，但后端很可能映射到同一实体。

**预览 Dialog（只读，展示 6 项）**

| 展示项 | 字段 |
|--------|------|
| 名称 | `name` |
| 类型 Tag | `type` |
| 状态 Tag | `status` |
| 邀请码 | `inviteCode` |
| 绑定活动 | `activity` |
| 绑定顾问 | `advisor` |
| 追踪链接（只读 Input）| 拼接：`https://m.example.com/track?qr_id={id}&invite={inviteCode}` |
| 扫码 / 注册 / 线索统计 | `scans`, `registers`, `leads` |

### 3.2 线索管理页（`admin-system/app/leads/page.tsx`）—— 二维码相关部分

- 筛选器"来源二维码"下拉选项：遍历 `qrCodeItems`，用 `item.id` 为 value（`leads/page.tsx:49`）
- 线索表格列"来源二维码"：展示 `lead.qr` 字段（`leads/page.tsx:68`）
- 线索详情 Drawer"来源信息"卡片：展示 `lead.qr`（`leads/page.tsx:85`）

`lead.qr` 字段存的是二维码 ID 格式字符串（如 `ACT-20260702-001`、`CHANNEL-SZ-002`、`CONSULTANT-ZHOU`），筛选下拉用的是 `qrCodeItems.id`（如 `QR-ACT-001`、`QR-CH-SZ-002`、`QR-CONS-008`）——两者的值并不对齐，筛选将无法命中。

### 3.3 活动管理页（`admin-system/app/activities/page.tsx`）—— 二维码相关部分

活动"生成二维码"操作弹出 Dialog，展示：
- 活动名称（`activity.name`）
- 邀请码：`{activity.id}-INVITE`（写死拼接，非 `qrCodeItems` 中的数据）
- 活动状态 Tag
- 追踪链接：`https://m.example.com/event?activity_id={activity.id}&invite={activity.id}-INVITE`

此处生成的邀请码格式（如 `A003-INVITE`）与 `qrCodeItems.inviteCode`（如 `ACT20260702`）的格式体系完全不同，且与 `qrCodeItems.id`（如 `QR-ACT-001`）也不同。这是本次审计中最严重的命名不一致。

### 3.4 用户管理页（二维码相关字段）

- 列表页：`sourceQr` 列直接展示原始值（`users/page.tsx:76`）
- 详情页来源标签卡片：`user.sourceQr` 作为 Tag 展示（`users/[id]/page.tsx:36`）
- 详情页顾问摘要：`user.sourceQr` 出现在文本摘要中（`users/[id]/page.tsx:45`）
- 详情页来源记录标签页：`user.sourceQr` 展示为 Descriptions 项（`users/[id]/page.tsx:57`）

### 3.5 落地页（landing-page）—— 二维码 / 邀请码参数

- `app/page.tsx`：不传递任何 URL 参数给 `EventLandingPage`（`app/page.tsx:1-9`）
- `components/mobile/event-landing-page.tsx`：组件 Props 中无 `qr_id`、`inviteCode`、`sourceQr` 任何相关字段（`event-landing-page.tsx:27-40`）
- 整个落地页系统中**没有任何组件读取 `?qr_id=` 或 `?invite=` URL 参数**
- 唯一使用 `useSearchParams` 的落地页（`risk-assessment/report/page.tsx`）仅读取 `?score=`，不读取来源追踪参数

结论：落地页目前完全没有实现扫码来源归因逻辑，`user.sourceQr` 字段在落地页注册时无从填充。

---

## 4. 业务实体和字段

### 4.1 QrCode（二维码 / 邀请码）

#### 数据库实体（需持久化）

| 字段 | Mock 字段 | 类型 | 分类 | 证据位置 |
|------|-----------|------|------|----------|
| 主键 | `id` | `string`（如 `QR-ACT-001`） | 持久化（主键） | `mock-data.ts:72` |
| 名称 | `name` | `string` | 持久化（用户填写） | `mock-data.ts:72` |
| 类型 | `type` | `string`（枚举 5 种） | 持久化 | `mock-data.ts:72` |
| 邀请码 | `inviteCode` | `string`（如 `ACT20260702`） | 持久化（系统生成） | `mock-data.ts:72` |
| 绑定活动 | `activity` | `string`（活动名称） | 持久化（关联字段，存名称字符串） | `mock-data.ts:72` |
| 绑定顾问 | `advisor` | `string`（顾问名 / "未绑定"） | 持久化（关联字段，存名称字符串） | `mock-data.ts:72` |
| 渠道 | `channel` | `string` | 持久化 | `mock-data.ts:72` |
| 有效期 | `validPeriod` | `string`（非结构化，含"长期有效"特殊值） | 持久化 | `mock-data.ts:72` |
| 状态 | `status` | `string`（枚举：启用中 / 暂停中） | 持久化 | `mock-data.ts:72` |
| 累计扫码 | `scans` | `number` | 计算字段（系统累加） | `mock-data.ts:72` |
| 注册人数 | `registers` | `number` | 计算字段（系统累加） | `mock-data.ts:72` |
| 线索数 | `leads` | `number` | 计算字段（系统累加） | `mock-data.ts:72` |

#### Mock 中存在但页面未使用的字段

`qrCodeItems` 中的所有字段均已在页面的某处使用，无冗余字段。

#### 列表 DTO（用于 `qr-codes/page.tsx` 表格和概览统计）

`id`, `name`, `inviteCode`, `type`, `activity`, `advisor`, `channel`, `validPeriod`, `status`, `scans`, `registers`, `leads`（即全量字段）

#### 详情 DTO（用于预览 Dialog）

同列表 DTO，与列表 DTO 无差异，不需要单独详情接口（数据量不大）。

#### 新建 / 编辑表单 DTO（CreateQrCodeDTO）

`name`, `type`, `activity`（活动名或 activityId），`advisor`（顾问名或 advisorId），`channel`，`validFrom`+`validTo`（结构化有效期，替代 `validPeriod` 字符串），`status`

`inviteCode` 由后端生成，不在表单 DTO 中。

#### 类型枚举

```
type QrCodeType = '活动二维码' | '顾问二维码' | '渠道二维码' | '资料二维码' | '测评二维码'
type QrCodeStatus = '启用中' | '暂停中'
```

### 4.2 User（端用户）—— 来源追踪相关字段

（完整 User 实体见 `docs/mock-audit/用户管理-mock-audit.md`，此处仅列与二维码模块直接相关的字段。）

| 字段 | Mock 值示例 | 类型 | 当前存的是什么 | 分类 |
|------|-------------|------|--------------|------|
| `sourceQr` | `'ACT-20260702-001'`, `'CONSULTANT-ZHOU'`, `'CHANNEL-SZ-002'`, `'QR-MAT-019'`, `'QR-ACT-001'` | `string` | 混用：部分像 `qrCodeItems.id`，部分像 `inviteCode`，部分既不是 id 也不是 inviteCode（见第 7 节） | 持久化（关联字段） |
| `sourceActivity` | `'金税四期风险识别专题课'` | `string` | 活动名称（非 activityId） | 持久化（关联字段） |

### 4.3 Lead（线索）—— 来源追踪相关字段

| 字段 | Mock 值示例 | 类型 | 当前存的是什么 | 分类 |
|------|-------------|------|--------------|------|
| `qr` | `'ACT-20260702-001'`, `'CHANNEL-SZ-002'`, `'CONSULTANT-ZHOU'` | `string` | 与 `user.sourceQr` 值相同，混用 id / inviteCode 格式 | 持久化（关联字段） |
| `activity` | 活动名称字符串 | `string` | 活动名称（非 activityId） | 持久化（关联字段） |

---

## 5. 页面操作

### 5.1 二维码管理页操作

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 搜索/筛选二维码 | 查询按钮 | 无效（所有筛选器均无绑定逻辑） | `GET /api/qr-codes?name=&type=&activity=&advisor=&status=&page=&pageSize=` |
| 重置筛选 | 重置按钮 | 无效 | — |
| 新建二维码 | "新建二维码"按钮 → Dialog | Dialog 打开，表单无提交逻辑 | `POST /api/qr-codes` |
| 新建邀请码 | "新建邀请码"按钮 → Dialog | Dialog 打开，表单无提交逻辑 | `POST /api/qr-codes`（type 固定为顾问二维码） |
| 查看（预览）二维码 | 操作列"查看" | `preview(row)` 打开预览 Dialog，仅展示 | `GET /api/qr-codes/:id`（可复用列表数据） |
| 编辑二维码 | 更多菜单"编辑" | 打开 Dialog 并 `setCurrent(row)`，无提交逻辑 | `PUT /api/qr-codes/:id` |
| 下载二维码 | 更多菜单"下载二维码" | 调用 `preview(row)` 打开预览 Dialog，无实际下载 | `GET /api/qr-codes/:id/image`（返回二维码图片） |
| 停用二维码 | 更多菜单"停用" | `MessagePlugin.success('二维码已停用')`，无状态变更 | `PATCH /api/qr-codes/:id/status` |
| 批量启用 | "批量启用"按钮 | 无实现（占位） | `PATCH /api/qr-codes/bulk-status` |
| 批量停用 | "批量停用"按钮 | 无实现（占位） | `PATCH /api/qr-codes/bulk-status` |
| 导出数据 | "导出数据"按钮 | 无实现（占位） | `GET /api/qr-codes/export` |
| 复制链接 | 预览 Dialog cancelBtn="复制链接" | 按钮文字设为"复制链接"但绑定的是关闭 Dialog 的 `onClose`，实际无复制功能 | 前端 Clipboard API，无需后端接口 |

### 5.2 活动管理页 —— 二维码相关操作

| 操作 | 触发元素 | 当前实现 | 需要的 API |
|------|----------|----------|------------|
| 生成活动二维码 | 更多菜单"生成二维码" → Dialog | Dialog 展示写死邀请码格式和占位 QR 图，无实际生成逻辑 | `POST /api/qr-codes`（type 固定为活动二维码，activity 绑定当前活动） |
| 下载活动二维码 | 活动二维码 Dialog confirmBtn="下载二维码" | 无实现 | `GET /api/qr-codes/:id/image` |
| 复制活动链接 | 活动二维码 Dialog cancelBtn="复制链接" | 无实现 | 前端 Clipboard API |

---

## 6. 建议 API

### 二维码管理（admin-system）

| 方法 | 路径 | 请求体 / 参数 | 响应 |
|------|------|--------------|------|
| `GET` | `/api/qr-codes` | `name`, `type`, `activity`, `advisor`, `status`, `page`, `pageSize` | `{ items: QrCodeListDTO[], total: number, summary: QrCodeSummaryDTO }` |
| `POST` | `/api/qr-codes` | `CreateQrCodeDTO` | `QrCodeDetailDTO`（含系统生成的 `inviteCode`） |
| `GET` | `/api/qr-codes/:id` | — | `QrCodeDetailDTO` |
| `PUT` | `/api/qr-codes/:id` | `UpdateQrCodeDTO` | `QrCodeDetailDTO` |
| `PATCH` | `/api/qr-codes/:id/status` | `{ status: '启用中' \| '暂停中' }` | `{ id: string, status: string }` |
| `GET` | `/api/qr-codes/:id/image` | — | 二维码图片（PNG 或 SVG） |
| `PATCH` | `/api/qr-codes/bulk-status` | `{ ids: string[], status: '启用中' \| '暂停中' }` | `{ updated: number }` |
| `GET` | `/api/qr-codes/export` | 同筛选参数 | CSV / XLSX 文件流 |

**QrCodeSummaryDTO**（概览卡片用）：

```typescript
interface QrCodeSummaryDTO {
  total: number;
  active: number;      // status === '启用中'
  scans: number;       // 累计扫码
  registers: number;   // 注册人数
  leads: number;       // 线索数
}
```

**QrCodeListDTO**（列表 / 详情共用，字段量不大无需拆分）：

```typescript
interface QrCodeListDTO {
  id: string;
  name: string;
  inviteCode: string;
  type: QrCodeType;
  activityId: string;        // 外键，替代 activity 名称字符串
  activityName: string;      // 展示用（join）
  advisorId: string | null;  // 外键，null 对应"未绑定"
  advisorName: string | null;
  channel: string;
  validFrom: string | null;  // ISO 日期
  validTo: string | null;    // ISO 日期，null 对应"长期有效"
  status: QrCodeStatus;
  scans: number;
  registers: number;
  leads: number;
}
```

**CreateQrCodeDTO**：

```typescript
interface CreateQrCodeDTO {
  name: string;
  type: QrCodeType;
  activityId?: string;
  advisorId?: string;
  channel: string;
  validFrom?: string;
  validTo?: string;    // 不传 = 长期有效
  status: QrCodeStatus;
}
```

### 来源归因（landing-page → 后端）

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/qr-codes/track?qr_id=&invite=` | 落地页扫码入口：验证二维码有效性，返回绑定的活动信息。记录扫码事件（scans+1）。响应包含活动数据以渲染落地页。 |
| `POST` | `/api/auth/login-phone` | 注册时携带 `sourceQrId`（从 URL 参数取得），后端写入 `users.source_qr_id` |

---

## 7. 字段和类型冲突

| 冲突描述 | 文件 A | 字段 A 值 | 文件 B | 字段 B 值 | 风险等级 |
|----------|--------|----------|--------|----------|----------|
| **`user.sourceQr` 与 `qrCodeItems.id` 不对齐**：用户 1（李明）`sourceQr: 'ACT-20260702-001'`，但 `qrCodeItems` 中没有 id 为 `ACT-20260702-001` 的记录（最近的是 `QR-ACT-001`，inviteCode 为 `ACT20260702`） | `mock-data.ts:36` | `ACT-20260702-001` | `mock-data.ts:72` | `QR-ACT-001` / `ACT20260702` | 高风险 |
| **`user.sourceQr` 与 `qrCodeItems.inviteCode` 部分对齐、部分不对齐**：用户 3（赵瑞）`sourceQr: 'CHANNEL-SZ-002'`，与 `qrCodeItems[2].inviteCode: 'CHANNEL-SZ-002'` 一致；用户 2（张倩）`sourceQr: 'CONSULTANT-ZHOU'`，`qrCodeItems[1].inviteCode: 'CONSULT-ZHOU'`（相差一个字母"ANT"），不完全匹配 | `mock-data.ts:37` | `CONSULTANT-ZHOU` | `mock-data.ts:73` | `CONSULT-ZHOU` | 高风险 |
| **`lead.qr` 与 `qrCodeItems.id` 不对齐**：线索筛选下拉用 `qrCodeItems.id`（如 `QR-ACT-001`），但线索表格展示列 `lead.qr` 存的是混合值（如 `ACT-20260702-001`），筛选时无法命中 | `leads/page.tsx:49` | `qrCodeItems.id` | `mock-data.ts:66` | `lead.qr: 'ACT-20260702-001'` | 高风险 |
| **活动页生成的邀请码格式与 `qrCodeItems.inviteCode` 体系不同**：活动页写死格式为 `{activity.id}-INVITE`（如 `A003-INVITE`），`qrCodeItems.inviteCode` 为自定义可读码（如 `ACT20260702`），两者无关联 | `activities/page.tsx:152` | `A003-INVITE` | `mock-data.ts:72` | `ACT20260702` | 高风险 |
| **`validPeriod` 为非结构化字符串**：`qrCodeItems.validPeriod` 存储格式为 `"2026-06-01 至 2026-07-02"` 或 `"长期有效"`，表单使用 `DateRangePicker` 组件，无法直接回填，也无法做过期判断 | `mock-data.ts:72` | `string` | `qr-codes/page.tsx:160` | `DateRangePicker` | 中风险 |
| **`advisor` 字段存名称字符串，`advisorOptions` 也存名称**：无 advisorId 外键，顾问改名将导致历史数据断裂；"未绑定"是特殊值混在顾问名列表中，数据库难以 nullable 约束 | `mock-data.ts:72` | `advisor: '未绑定'` | `qr-codes/page.tsx:20-26` | `advisorOptions` value 也是中文名 | 中风险 |
| **`activity` 字段存活动名称字符串，与 `activities.id` 无外键关联**：`qrCodeItems.activity` 存 `'金税四期风险识别专题课'`，`activities.id` 为 `'A003'`，活动改名后数据断裂；同一问题也存在于 `user.sourceActivity` 和 `lead.activity`（三处） | `mock-data.ts:72` | `activity: '全部活动'` | `mock-data.ts:29` | `activities[2].id: 'A003'` | 中风险 |
| **落地页无任何 URL 参数读取逻辑**：`m.example.com/track?qr_id=QR-ACT-001&invite=ACT20260702` 的两个参数在落地页完全未被消费，用户注册时 `sourceQr` 无从填充 | `qr-codes/page.tsx:185` | 生成链接含 `qr_id` + `invite` | `拓客系统-落地页/app/page.tsx:1-9` | 无 searchParams 处理 | 高风险 |
| **预览 Dialog cancelBtn 文字为"复制链接"但行为是关闭**：`onClose={() => setPreviewVisible(false)}` 绑定到 cancelBtn，cancelBtn 文字显示为"复制链接"，用户点击实为关闭 Dialog | `qr-codes/page.tsx:175` | cancelBtn="复制链接" | — | onClose 行为 | 低风险（UI bug） |

---

## 8. 页面状态缺口

| 缺口描述 | 系统 | 页面 | 当前状态 | 影响 |
|----------|------|------|----------|------|
| 所有筛选条件无过滤逻辑 | admin-system | 二维码管理页 | Input / Select 均无 `onChange` 绑定，查询和重置按钮无事件处理 | 筛选功能完全无效 |
| 新建二维码表单无提交逻辑 | admin-system | 二维码管理页 | Dialog confirmBtn "保存二维码" 未绑定任何 API 调用，表单数据不提交 | 新建二维码不可用 |
| 新建邀请码表单无提交逻辑 | admin-system | 二维码管理页 | 同上 | 新建邀请码不可用 |
| 编辑二维码无提交逻辑 | admin-system | 二维码管理页 | `setCurrent(row)` 打开 Dialog 后，confirmBtn 无 API 调用 | 编辑不可用 |
| 停用操作无状态持久化 | admin-system | 二维码管理页 | `MessagePlugin.success('二维码已停用')` 仅弹出 Toast，`qrCodeItems` 数据不变，刷新后恢复 | 停用操作无效 |
| 批量启用 / 停用无实现 | admin-system | 二维码管理页 | 按钮无 onClick | 批量操作不可用 |
| 导出数据无实现 | admin-system | 二维码管理页 | 按钮无 onClick | 数据导出不可用 |
| 下载二维码为占位文字 | admin-system | 二维码管理页 | 预览 Dialog 中 `<div>QR</div>` 文字占位，无二维码图片生成逻辑 | 无法下载实际二维码图片 |
| 复制链接按钮行为错误 | admin-system | 二维码管理页 | cancelBtn="复制链接"绑定 `onClose`，实为关闭 Dialog | 用户无法复制追踪链接 |
| 活动页生成二维码为占位 | admin-system | 活动管理页 | `<div className="qr-box">QR</div>` 文字占位，邀请码格式与二维码实体无关联 | 无法生成和下载真实活动二维码 |
| 落地页无扫码归因入口 | landing-page | 所有落地页页面 | 无任何组件读取 `?qr_id=` / `?invite=` URL 参数；注册流程不传递来源信息 | `user.sourceQr` 在注册时永远为空，二维码转化追踪数据无从积累 |
| 线索筛选"来源二维码"无效 | admin-system | 线索管理页 | 下拉选项用 `qrCodeItems.id`，线索 `lead.qr` 值与之不匹配，筛选命中率为 0 | 按二维码筛选线索完全无效 |

---

## 9. 共用模型

以下实体在两个系统中均被引用，需统一契约：

| 实体 | admin-system 视角 | landing-page 视角 | 共用字段 | 当前问题 |
|------|-------------------|-------------------|----------|----------|
| QrCode | CRUD 全权限；展示 `id`、`inviteCode`、转化统计 | 读取 `?qr_id=` / `?invite=` 参数以识别来源；注册时写入 `user.sourceQr` | `id`, `inviteCode`, `status`, `activityId` | 落地页完全未实现参数消费 |
| Activity | CRUD；生成活动二维码 | 根据 QrCode 关联的 activityId 渲染活动内容（eventData） | `id`, `name`, `time`, `place`, `speaker`, `status` | 落地页 `EventLandingPage` 的 `eventData` 为硬编码默认值，未从 URL 参数 + API 读取 |
| User | 查看 `sourceQr`、`sourceActivity`；作为线索归因依据 | 注册时写入 `sourceQr`（来自 URL 参数） | `sourceQr`（应存 `qrCodeId` 外键） | 三张表（users / leads / qrCodeItems）中的 QR 标识符值体系不统一 |

**统一建议**：

1. 数据库中用 `qr_code_id`（外键 → `qr_codes.id`）替代所有三处字符串存储（`users.source_qr`、`leads.qr`、活动 Dialog 的拼接码）。
2. 落地页 URL 参数统一为 `?qr_id={qrCode.id}`，不需要同时传 `inviteCode`（`inviteCode` 面向人类可读，`id` 面向系统追踪）。
3. 注册 API 接收 `sourceQrId`，后端写入 `users.source_qr_id`；`scans`/`registers`/`leads` 在对应事件发生时由后端原子递增。

---

## 10. 推荐迁移顺序

| 优先级 | 任务 | 原因 |
|--------|------|------|
| P0 | 修复 `user.sourceQr`、`lead.qr` 的值体系，统一使用 `qrCodeItems.id`（如 `QR-ACT-001`） | 三张 Mock 表的关联值已经不一致，真实接入前必须对齐，否则所有来源归因数据都是错误的 |
| P0 | 落地页实现 `useSearchParams` 读取 `?qr_id=`，注册时将 `sourceQrId` 传入注册 API | 整个转化漏斗的归因能力依赖此功能，当前为零 |
| P1 | 后端实现 `GET /api/qr-codes/track?qr_id=`，落地页加载时验证二维码有效性并获取活动信息 | 支持落地页动态渲染活动内容；`scans` 计数在此阶段写入 |
| P1 | 替换 `validPeriod` 字符串为结构化 `validFrom`/`validTo`，`DateRangePicker` 正确回填和提交 | 否则新建编辑表单的有效期无法正确处理"长期有效"逻辑 |
| P1 | 新建 / 编辑 / 停用二维码接入真实 API | 当前所有写操作均无效 |
| P1 | 线索管理"来源二维码"筛选器改用 `qrCodeItems.id` 与 `lead.source_qr_id` 外键对齐 | 否则筛选功能命中率为 0 |
| P2 | 活动管理页"生成二维码"改为调用 `POST /api/qr-codes` 接口，不再用 `{activity.id}-INVITE` 拼接 | 消除两套邀请码格式体系并存的问题 |
| P2 | 实现真实二维码图片生成（服务端使用 `qrcode` 库，或前端用 `qrcode.react`） | 当前 `<div>QR</div>` 占位无实用价值 |
| P2 | 修复预览 Dialog 的"复制链接"按钮，绑定 Clipboard API | UI 功能性 bug，用户体验修复 |
| P3 | 批量启用 / 停用、导出数据 | 运营效率功能，可最后实现 |
| P3 | `activity` 和 `advisor` 字段改为存外键 id，展示层 join 名称 | 数据健壮性，可在数据库设计阶段统一处理 |

---

## 11. 不确定项

| # | 不确定项 | 文件 | 假设 | 影响范围 |
|---|----------|------|------|----------|
| 1 | `inviteCode` 与 `id` 的业务语义区别是什么？页面中两者都展示（列表展示 `inviteCode`，预览链接同时带 `qr_id` 和 `invite`），但落地页 URL 中两个参数都出现，后端到底用哪个做主键查询？ | `qr-codes/page.tsx:185` | 假设 `id` 为系统内部主键（UUID 或自增），`inviteCode` 为对外的可读短码（类似邀请码格式），两者均需存储，`inviteCode` 也需要唯一索引以支持 URL 参数查询 | 影响 `qr_codes` 表索引设计和落地页 Track API 查询方式 |
| 2 | `scans`/`registers`/`leads` 是存在 `qr_codes` 表还是实时聚合计算？当前 Mock 为直接存储的数字。实时聚合准确但查询慢，预存计数快但需事务维护一致性 | `mock-data.ts:72` | 假设采用预存计数（counter 字段），注册/线索生成时原子递增，定期对账 | 影响 `qr_codes` 表设计和注册/线索 API 的写入逻辑 |
| 3 | 新建邀请码和新建二维码是同一实体的不同表单，还是不同实体？当前两个 Dialog 字段几乎相同，区别仅在于是否显示 `type` 字段。若是同一实体，后端只需一个接口 | `qr-codes/page.tsx:165-173` | 假设是同一实体，"新建邀请码"是 type 固定为"顾问二维码"的快捷入口，后端统一用 `POST /api/qr-codes` | 影响 UI 是否合并为一个表单，以及后端是否需要单独的邀请码接口 |
| 4 | `validPeriod: '长期有效'` 在数据库中如何存储？`validTo` 为 NULL、为远未来时间（2099-12-31）还是另设一个 `isPermanent` 布尔字段？ | `mock-data.ts:76` | 假设 `validTo` 为 NULL 代表长期有效，前端判断 `validTo === null` 时展示"长期有效" | 影响表设计和前端日期组件的空值处理 |
| 5 | 落地页渲染活动内容（`EventLandingPage` 的 `eventData`）是否应该根据扫码的二维码动态加载？当前 `defaultEventData` 为硬编码，不同二维码扫码后看到的是同一个活动内容 | `event-landing-page.tsx:42-51` | 假设需要动态加载：扫码二维码 → 后端返回绑定的活动信息 → 落地页渲染对应活动内容。若二维码未绑定活动则展示通用落地页 | 影响落地页的路由设计和 `EventLandingPage` 组件的 Props 接口 |
| 6 | `channel` 字段的值来源是什么？当前 `channelOptions` 为页面硬编码（线上直播间、顾问私域、深圳渠道商等），是否需要后台可配置？ | `qr-codes/page.tsx:28-34` | 假设当前阶段枚举写死可接受，后续可考虑做成可配置的渠道字典表 | 影响 `channel` 字段是否需要外键关联渠道表 |

---

**高风险不一致项汇总（4 项，需优先处理）**：

1. `user.sourceQr` / `lead.qr` 与 `qrCodeItems.id` 完全不对齐（混用自定义字符串、inviteCode、id 三种格式），导致用户来源归因和线索筛选数据均不可信。
2. 落地页无任何 `?qr_id=` / `?invite=` 参数读取逻辑，扫码注册的来源信息在系统入口就已丢失，整个二维码转化追踪链路断裂。
3. 活动管理页生成的邀请码格式（`{activity.id}-INVITE`）与二维码实体的 `inviteCode` 字段体系完全无关，存在两套并行的邀请码格式，不统一。
4. `lead.qr` 筛选下拉使用 `qrCodeItems.id`，但 `lead.qr` 存储值与之不匹配，按二维码来源筛选线索的命中率为 0。
