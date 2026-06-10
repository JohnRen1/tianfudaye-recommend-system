# 辅助模块 Mock 审计报告
## 知识库 · 数据看板 · 系统设置 · 落地页客服页

审计时间：2026-06-10
审计人：Mock Auditor Agent
关联报告：[用户管理-mock-audit.md](./用户管理-mock-audit.md)

---

## 1. 审计范围

| 系统 | 页面 | 文件路径 |
|------|------|---------|
| admin-system | 首页数据看板 | 拓客系统-管理后台/app/page.tsx |
| admin-system | 知识库管理 | 拓客系统-管理后台/app/knowledge-base/page.tsx |
| admin-system | 系统设置 | 拓客系统-管理后台/app/settings/page.tsx |
| admin-system | 共享数据源 | 拓客系统-管理后台/lib/mock-data.ts |
| admin-system | 工具函数 | 拓客系统-管理后台/lib/ui.ts |
| landing-page | 客服/支持页 | 拓客系统-落地页/app/support/page.tsx |

不在本次审计范围内（已有独立报告）：用户管理、线索管理、测评报告、问答记录、活动管理、二维码管理、资料管理。

---

## 2. Mock 来源清单

### 2.1 admin-system — mock-data.ts 中与本次范围相关的导出

| 导出名 | 文件 | 行号 | 条数 | Mock 类型 |
|--------|------|------|------|-----------|
| `dashboardMetrics` | 拓客系统-管理后台/lib/mock-data.ts | 4–15 | 10 | 硬编码对象数组，value 为格式化字符串，trend 为百分比字符串 |
| `funnelData` | 拓客系统-管理后台/lib/mock-data.ts | 17–26 | 8 | 硬编码对象数组，value 为数字 |
| `activities` | 拓客系统-管理后台/lib/mock-data.ts | 28–33 | 4 | 用于看板"活动效果排行"，同时也是活动模块 mock |
| `leads` | 拓客系统-管理后台/lib/mock-data.ts | 65–69 | 3 | 用于看板"高意向线索列表"，同时也是线索模块 mock |
| `knowledgeItems` | 拓客系统-管理后台/lib/mock-data.ts | 87–92 | 4 | 硬编码对象数组 |

### 2.2 admin-system — settings/page.tsx 内联 Mock（未提取到 mock-data.ts）

| 变量名 | 文件 | 行号 | 条数 | Mock 类型 |
|--------|------|------|------|-----------|
| `roles` | 拓客系统-管理后台/app/settings/page.tsx | 7–12 | 4 | 组件内硬编码数组 |
| `admins` | 拓客系统-管理后台/app/settings/page.tsx | 14–19 | 4 | 组件内硬编码数组 |
| `auditLogs` | 拓客系统-管理后台/app/settings/page.tsx | 21–26 | 4 | 组件内硬编码数组 |
| `integrationItems` | 拓客系统-管理后台/app/settings/page.tsx | 28–33 | 4 | 组件内硬编码数组 |
| 各配置表单默认值 | 拓客系统-管理后台/app/settings/page.tsx | 69–74, 94–97, 137–138 | — | JSX 内 `value=` 硬编码字符串/数字 |

### 2.3 admin-system — page.tsx（看板）内联 Mock（未提取到 mock-data.ts）

| 变量名 | 文件 | 行号 | Mock 类型 |
|--------|------|------|-----------|
| `trendData` | 拓客系统-管理后台/app/page.tsx | 18–46 | 组件内硬编码数组，含折线图历史点数据 |
| 筛选器 options 中的活动/顾问名 | 拓客系统-管理后台/app/page.tsx | 64–83 | JSX 内硬编码字符串 |

### 2.4 landing-page — support/page.tsx 内联 Mock

| 变量名 | 文件 | 行号 | Mock 类型 |
|--------|------|------|-----------|
| `faqs` | 拓客系统-落地页/app/support/page.tsx | 12–17 | 组件内硬编码字符串数组 |
| 客服电话 `400-888-6688` | 拓客系统-落地页/app/support/page.tsx | 59 | JSX 内硬编码字符串 |
| 服务时间 `09:00 - 18:00` | 拓客系统-落地页/app/support/page.tsx | 53 | JSX 内硬编码字符串 |

---

## 3. 页面数据需求

### 3.1 数据看板（app/page.tsx）

**筛选器**

| 筛选维度 | 当前状态 | 真实数据来源 |
|---------|---------|------------|
| 时间范围 | 有 UI，无实际过滤逻辑，`useState('1w')` 不影响任何数据 | 后端接口参数 |
| 活动 | 有 UI，下拉选项硬编码，不过滤数据 | `activities` 表 |
| 渠道 | 有 UI，下拉选项硬编码，不过滤数据 | `qr_codes.channel` 枚举 |
| 顾问 | 有 UI，下拉选项硬编码，不过滤数据 | 管理员账号表（角色=销售顾问） |

**指标卡（dashboardMetrics）**：页面消费字段：`label`、`value`（字符串）、`trend`（字符串）、`tone`（字符串）。

**转化漏斗（funnelData）**：页面消费字段：`name`、`value`（数字）。

**趋势折线图（trendData）**：页面消费字段：`label`、`current`、`trend`、`isUp`、`data`（数组）、`lineColor`。

**活动效果排行（activities）**：页面消费字段：`id`、`name`、`theme`、`scan`、`register`、`materialClaims`、`assessments`、`appointments`、`highIntentLeads`。

**高意向线索列表（leads）**：页面消费字段：`id`、`name`、`company`、`activity`、`score`、`risk`、`advisor`、`status`。

### 3.2 知识库管理（app/knowledge-base/page.tsx）

**列表**：页面消费字段：`id`、`title`、`summary`、`type`、`version`、`start`、`end`、`status`、`refs`、`uploader`、`updated`。

**详情抽屉**：页面消费字段（除列表已有外）：`note`、`fileType`。

**概览统计卡**：来源于 `knowledgeItems` 的运行时聚合——`length`、`filter(status==='生效中').length`、`reduce(refs)`、`filter(status==='待审核').length`。

**上传表单**：收集字段：文件（二进制）、`type`、`title`、`start`、`end`、`status`、`note`；`version`、`uploader`、`updated`、`refs`、`id` 不在表单中，应由后端生成。

### 3.3 系统设置（app/settings/page.tsx）

**基础配置 Tab**

| 字段 | 当前 Mock 值 | 字段类型 |
|------|------------|---------|
| 平台名称 | "私域转换管理后台" | 持久化配置 |
| 运营主体 | "上海启航企业服务有限公司" | 持久化配置 |
| 客服电话 | "400-888-2026" | 持久化配置 |
| 默认顾问分配策略 | "score" | 持久化配置（枚举） |
| 数据保留天数 | 365 | 持久化配置（数字） |
| 自动生成线索阈值 | 61 | 持久化配置（数字） |
| 转化规则开关 ×5 | true | 持久化配置（boolean） |

**AI 与合规 Tab**

| 字段 | 当前 Mock 值 | 字段类型 |
|------|------------|---------|
| 风险等级触发转人工 | "high" | 持久化配置（枚举） |
| AI 免责声明文本 | 硬编码字符串 | 持久化配置（长文本） |
| 禁止回答关键词 | 硬编码逗号分隔字符串 | 持久化配置（文本/数组） |
| 知识库检索阈值 | 72（Progress 展示） | 持久化配置（数字 0-100） |
| 高风险动作规则 ×3 | 静态 JSX | 仅展示，无交互，是否为可配置项不明确 |

**角色权限 Tab**

页面消费字段：`id`、`name`、`desc`、`users`（成员数）、`status`、`updated`。
新建角色表单收集字段：`name`、权限说明（`desc`）、菜单权限（文本）。

**管理员账号 Tab**

页面消费字段：`id`、`name`、`phone`、`role`（角色名称字符串）、`dept`、`status`、`lastLogin`。
新增管理员表单收集字段：`name`、`phone`、`role`、`dept`。

**集成配置 Tab**

页面消费字段：`name`、`status`、`desc`。

**通知设置 Tab**

5 个通知场景开关 + 4 个通知渠道开关；全部为 `defaultValue`，无受控绑定，不会持久化。

**安全与审计 Tab**

配置字段：`loginExpiry`（枚举）、`loginFailLimit`（数字）、`sensitiveOpConfirm`（boolean）、`exportPermCheck`（boolean）。

审计日志消费字段：`id`、`user`（操作人姓名）、`action`、`module`、`ip`、`time`。

### 3.4 落地页客服页（app/support/page.tsx）

页面消费数据：
- `faqs`：4 条硬编码字符串，点击均跳转 `/tax-ai`，无个性化逻辑
- 客服电话：硬编码 `400-888-6688`
- 服务时间：硬编码 `09:00 - 18:00`
- 留言表单收集字段：`phone`（手机号）、`content`（留言内容）；提交后只做本地 `setSubmitted(true)`，无任何网络请求

---

## 4. 业务实体和字段

### 4.1 KnowledgeItem（知识库条目）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `id` | string | 持久化 | 主键 | mock-data.ts:88–92 |
| `title` | string | 持久化 | 知识标题，列表/详情/搜索 | knowledge-base/page.tsx:55 |
| `summary` | string | 持久化 | 摘要，列表副标题和详情展示 | knowledge-base/page.tsx:55, 69 |
| `type` | string（枚举） | 持久化 | 知识分类，过滤器和列表标签 | knowledge-base/page.tsx:11–21, 56 |
| `version` | string | 持久化 | 版本号，列表和详情展示 | knowledge-base/page.tsx:57, 70 |
| `start` | string（日期） | 持久化 | 生效时间 | knowledge-base/page.tsx:58, 70 |
| `end` | string（日期） | 持久化 | 失效时间 | knowledge-base/page.tsx:59, 70 |
| `status` | string（枚举） | 持久化 | 生效中/待审核/已归档，过滤器、列表标签、概览统计 | knowledge-base/page.tsx:39, 47–50, 60 |
| `refs` | number | 持久化/计算 | AI 引用次数，列表和概览统计 | knowledge-base/page.tsx:49, 61 |
| `uploader` | string | 持久化/关联 | 上传人姓名，列表和过滤器；当前无 uploaderId | knowledge-base/page.tsx:40, 62 |
| `updated` | string（datetime） | 持久化 | 最近更新时间，列表和详情 | knowledge-base/page.tsx:63, 70 |
| `note` | string | 持久化 | 备注/来源说明，仅详情抽屉 | knowledge-base/page.tsx:70 |
| `fileType` | string（枚举） | 持久化 | 文件格式（PDF/DOCX/TEXT 等），仅详情预览区 | knowledge-base/page.tsx:71 |

**不进入后端模型的 Mock 字段**：无（所有 mock 字段均在页面中使用）。

**上传表单未收集但需后端生成的字段**：`id`、`refs`（初始为 0）、`uploader`（来自当前登录用户）、`updated`（服务端时间戳）、`version`（后端生成或前端输入，上传表单中未包含该输入项）。

### 4.2 DashboardMetric（指标卡）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `label` | string | 展示 | 指标名称 | page.tsx:90, 92 |
| `value` | string | 计算/聚合 | 格式化后的数值，如 "12,846" | page.tsx:93 |
| `trend` | string | 计算/聚合 | 环比趋势百分比，如 "+8.2%" | page.tsx:90, 95–96 |
| `tone` | string（枚举） | 展示 | 卡片配色（green/red） | page.tsx:92 |

### 4.3 FunnelStep（转化漏斗）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `name` | string | 展示 | 漏斗步骤名称 | page.tsx:107 |
| `value` | number | 计算/聚合 | 该步骤的用户数量 | page.tsx:108–109 |

### 4.4 TrendSeries（趋势折线图，内联 Mock）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `label` | string | 展示 | 指标名称 | page.tsx:139 |
| `current` | number | 计算/聚合 | 最新周期的数值 | page.tsx:143 |
| `trend` | string | 计算/聚合 | 环比趋势 | page.tsx:141 |
| `isUp` | boolean | 计算 | 趋势方向，控制颜色 | page.tsx:140–141 |
| `data` | number[] | 计算/聚合 | 历史 8 个时间点的数值，用于绘制折线 | page.tsx:126–134 |
| `lineColor` | string | 展示 | 折线颜色 hex | page.tsx:149 |
| `tone` | string | 展示 | 卡片配色类名 | page.tsx（未实际渲染，仅定义） |

### 4.5 AdminRole（管理员角色）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `id` | string | 持久化 | 主键 | settings/page.tsx:8 |
| `name` | string | 持久化 | 角色名称，表格和新增管理员下拉 | settings/page.tsx:113, 150 |
| `desc` | string | 持久化 | 权限说明，表格展示 | settings/page.tsx:113 |
| `users` | number | 计算/聚合 | 该角色的管理员人数，表格展示 | settings/page.tsx:113 |
| `status` | string（枚举） | 持久化 | 启用中/停用中 | settings/page.tsx:113 |
| `updated` | string（datetime） | 持久化 | 最近更新时间 | settings/page.tsx:113 |

### 4.6 AdminAccount（管理员账号）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `id` | string | 持久化 | 主键 | settings/page.tsx:15 |
| `name` | string | 持久化 | 姓名 | settings/page.tsx:119 |
| `phone` | string | 持久化 | 手机号（脱敏展示） | settings/page.tsx:119 |
| `role` | string | 持久化/关联 | 角色名称字符串，非 roleId | settings/page.tsx:119 |
| `dept` | string | 持久化 | 部门 | settings/page.tsx:119 |
| `status` | string（枚举） | 持久化 | 启用中/停用中 | settings/page.tsx:119 |
| `lastLogin` | string（datetime） | 持久化 | 最近登录时间 | settings/page.tsx:119 |

### 4.7 IntegrationItem（集成配置）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `name` | string | 持久化 | 服务名称 | settings/page.tsx:125 |
| `status` | string（枚举） | 持久化 | 已连接/待配置 | settings/page.tsx:125 |
| `desc` | string | 持久化 | 用途说明 | settings/page.tsx:125 |

### 4.8 AuditLog（操作审计日志）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `id` | string | 持久化 | 主键 | settings/page.tsx:22 |
| `user` | string | 持久化/关联 | 操作人姓名，非 adminId | settings/page.tsx:139 |
| `action` | string | 持久化 | 操作描述 | settings/page.tsx:139 |
| `module` | string | 持久化 | 所属模块 | settings/page.tsx:139 |
| `ip` | string | 持久化 | 操作 IP 地址 | settings/page.tsx:139 |
| `time` | string（datetime） | 持久化 | 操作时间 | settings/page.tsx:139 |

### 4.9 PlatformConfig（平台配置，无独立实体，当前为表单硬编码默认值）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `platformName` | string | 持久化配置 | 平台名称 | settings/page.tsx:69 |
| `operator` | string | 持久化配置 | 运营主体名称 | settings/page.tsx:70 |
| `servicePhone` | string | 持久化配置 | 客服电话 | settings/page.tsx:71 |
| `advisorAssignStrategy` | string（枚举） | 持久化配置 | 默认顾问分配策略 | settings/page.tsx:72 |
| `dataRetentionDays` | number | 持久化配置 | 数据保留天数 | settings/page.tsx:73 |
| `leadAutoGenThreshold` | number | 持久化配置 | 自动生成线索阈值（分） | settings/page.tsx:74 |
| `autoTagOnScan` | boolean | 持久化配置 | 转化规则开关 | settings/page.tsx:80 |
| `guidAssessAfterMaterial` | boolean | 持久化配置 | 转化规则开关 | settings/page.tsx:81 |
| `autoLeadOnHighRisk` | boolean | 持久化配置 | 转化规则开关 | settings/page.tsx:82 |
| `notifyAdvisorOnBooking` | boolean | 持久化配置 | 转化规则开关 | settings/page.tsx:83 |
| `leadFollowupReminder24h` | boolean | 持久化配置 | 转化规则开关 | settings/page.tsx:84 |
| `aiTriggerHandoffRisk` | string（枚举） | 持久化配置 | AI 触发转人工风险等级 | settings/page.tsx:94 |
| `aiDisclaimer` | string | 持久化配置 | AI 免责声明文本 | settings/page.tsx:95 |
| `aiBannedKeywords` | string | 持久化配置 | 禁止回答关键词 | settings/page.tsx:96 |
| `kbRetrievalThreshold` | number | 持久化配置 | 知识库检索阈值 0–100 | settings/page.tsx:97 |
| `loginExpiry` | string（枚举） | 持久化配置 | 登录有效期 | settings/page.tsx:138 |
| `loginFailLimit` | number | 持久化配置 | 登录失败锁定阈值 | settings/page.tsx:138 |
| `sensitiveOpConfirm` | boolean | 持久化配置 | 敏感操作二次确认 | settings/page.tsx:138 |
| `exportPermCheck` | boolean | 持久化配置 | 导出数据权限校验 | settings/page.tsx:138 |

### 4.10 SupportFeedback（落地页留言，无实体定义，表单直接提交）

| 字段名 | 类型 | 分类 | 字段用途 | 证据位置 |
|--------|------|------|---------|---------|
| `phone` | string | 持久化 | 联系手机号 | support/page.tsx:92 |
| `content` | string | 持久化 | 留言内容 | support/page.tsx:93 |
| `submittedAt` | datetime | 持久化 | 提交时间（后端生成） | 推断，页面无此字段 |

---

## 5. 页面操作

### 5.1 数据看板

| 操作 | 触发方式 | 当前状态 | 真实接口需求 |
|------|---------|---------|------------|
| 筛选（时间/活动/渠道/顾问） | 点击"应用筛选" | 状态更新但数据不变，完全无效 | GET /api/dashboard?timeRange=&activityId=&channel=&advisorId= |
| 导出数据（活动排行） | 点击"导出数据"按钮 | 无任何逻辑 | POST /api/activities/export |
| 进入线索池 | 点击"进入线索池" | 无跳转逻辑（缺少 router.push） | 导航到 /leads |
| 查看线索详情 | TableRowActions | 仅 UI，无路由跳转 | 导航到 /leads/[id] |
| 分配顾问 | 下拉菜单 | 仅 UI，无逻辑 | PATCH /api/leads/[id]/assign |
| 添加跟进 | 下拉菜单 | 仅 UI，无逻辑 | POST /api/leads/[id]/follow-ups |

### 5.2 知识库

| 操作 | 触发方式 | 当前状态 | 真实接口需求 |
|------|---------|---------|------------|
| 搜索/筛选 | 输入框 + Select + DateRangePicker + "查询"按钮 | 无任何过滤逻辑 | GET /api/knowledge?q=&type=&status=&uploader=&startDate=&endDate= |
| 重置筛选 | "重置"按钮 | 无逻辑 | 清空筛选状态 |
| 查看详情 | TableRowActions 主操作 | 打开 Drawer，展示 `current` 状态（通过 setCurrent 更新） | 可复用本地数据或 GET /api/knowledge/[id] |
| 编辑 | 下拉菜单"编辑" | 仅 MessagePlugin，无表单 | PATCH /api/knowledge/[id] |
| 停用 | 下拉菜单"停用" | 弹出 MessagePlugin.warning，数据不变 | PATCH /api/knowledge/[id] { status: '已归档' } |
| 归档 | 下拉菜单"归档" | 无逻辑 | PATCH /api/knowledge/[id] { status: '已归档' } |
| 删除 | 下拉菜单"删除" | 弹出 MessagePlugin.success，列表不变 | DELETE /api/knowledge/[id] |
| 批量归档 | "批量归档"按钮 | 无逻辑 | POST /api/knowledge/batch-archive |
| 导出引用数据 | "导出引用数据"按钮 | 无逻辑 | GET /api/knowledge/export-refs |
| 上传知识文件 | Dialog 表单提交 | Dialog 可开关，提交无逻辑 | POST /api/knowledge（multipart/form-data） |
| 新建知识内容 | "新建知识内容"按钮 | 无 Dialog，点击无反应 | POST /api/knowledge（JSON，无文件） |

### 5.3 系统设置

| 操作 | 触发方式 | 当前状态 | 真实接口需求 |
|------|---------|---------|------------|
| 保存基础配置 | "保存基础配置"按钮 | 无逻辑 | PUT /api/settings/platform |
| 保存 AI 配置 | "保存 AI 配置"按钮 | 无逻辑 | PUT /api/settings/ai |
| 保存安全策略 | "保存安全策略"按钮 | 无逻辑 | PUT /api/settings/security |
| 新建角色 | Dialog 提交 | Dialog 可开关，提交无逻辑 | POST /api/roles |
| 编辑角色 | TableRowActions | 无逻辑 | PATCH /api/roles/[id] |
| 停用角色 | 下拉菜单 | MessagePlugin.success，数据不变 | PATCH /api/roles/[id] { status: '停用中' } |
| 复制角色 | 下拉菜单 | 无逻辑 | POST /api/roles/[id]/copy |
| 新增管理员 | Dialog 提交 | Dialog 可开关，提交无逻辑 | POST /api/admins |
| 编辑管理员 | TableRowActions | 无逻辑 | PATCH /api/admins/[id] |
| 重置密码 | 下拉菜单 | MessagePlugin.success，无实际逻辑 | POST /api/admins/[id]/reset-password |
| 停用管理员 | 下拉菜单 | MessagePlugin.success，数据不变 | PATCH /api/admins/[id] { status: '停用中' } |
| 通知开关（9 个） | Switch | `defaultValue`，非受控，无法持久化 | PUT /api/settings/notifications |
| 去配置/查看配置（集成） | 按钮 | 无路由跳转，无逻辑 | 需要各集成专属配置页面或弹窗 |

### 5.4 落地页客服页

| 操作 | 触发方式 | 当前状态 | 真实接口需求 |
|------|---------|---------|------------|
| 点击 FAQ 条目 | button onClick | 全部跳转 `/tax-ai`，无参数传递 | 可选：带 `?q=<faq>` 参数预填 AI 输入框 |
| 提交留言 | "提交留言"按钮 | 仅 `setSubmitted(true)`，无网络请求 | POST /api/support/feedback |
| 继续问 AI | 按钮 | 正确跳转 `/tax-ai` | 已实现 |
| 预约顾问 | 按钮 | 正确跳转 `/appointment` | 已实现 |

---

## 6. 建议 API

### 6.1 数据看板

```
GET    /api/dashboard/metrics?timeRange=&activityId=&channel=&advisorId=
       → { metrics: DashboardMetric[], funnelSteps: FunnelStep[], trendSeries: TrendSeries[] }

GET    /api/dashboard/activities?timeRange=&page=&pageSize=
       → 聚合活动统计，复用 activities 实体加聚合字段

GET    /api/dashboard/high-intent-leads?page=&pageSize=
       → 筛选 score 高于阈值的 leads，复用 leads 列表 DTO
```

### 6.2 知识库

```
GET    /api/knowledge?q=&type=&status=&uploader=&startDate=&endDate=&page=&pageSize=
POST   /api/knowledge                    （multipart/form-data 上传文件版）
POST   /api/knowledge/text               （JSON 创建纯文本知识条目）
GET    /api/knowledge/:id
PATCH  /api/knowledge/:id
DELETE /api/knowledge/:id
POST   /api/knowledge/batch-archive      body: { ids: string[] }
GET    /api/knowledge/export-refs        → CSV/Excel 下载
```

### 6.3 系统设置

```
GET    /api/settings                     → 完整 PlatformConfig
PUT    /api/settings/platform
PUT    /api/settings/ai
PUT    /api/settings/security
PUT    /api/settings/notifications
PUT    /api/settings/conversion-rules

GET    /api/roles?page=&pageSize=
POST   /api/roles
PATCH  /api/roles/:id
POST   /api/roles/:id/copy

GET    /api/admins?page=&pageSize=
POST   /api/admins
PATCH  /api/admins/:id
POST   /api/admins/:id/reset-password

GET    /api/integrations
GET    /api/audit-logs?page=&pageSize=
```

### 6.4 落地页客服留言

```
POST   /api/support/feedback             body: { phone, content }
GET    /api/settings/public              → { servicePhone, serviceHours, faqs }
       （落地页客服页硬编码的电话和服务时间应从此接口读取）
```

---

## 7. 字段和类型冲突

| # | 冲突项 | 系统 A | 系统 B | 风险等级 | 说明 |
|---|--------|--------|--------|---------|------|
| 1 | 客服电话不一致 | landing-page support/page.tsx:59 — `400-888-6688` | admin-system settings/page.tsx:71 — `400-888-2026` | **P0** | 两个系统硬编码了不同的客服电话号码，落地页用户看到的号码与后台配置不同 |
| 2 | `uploader` 为姓名字符串，无 ID 关联 | knowledge-base/page.tsx:62 消费 `uploader` 字段（姓名） | settings/page.tsx 的 `admins` 数组有 `id` 字段 | P1 | 知识库过滤器硬编码了上传人姓名列表，与管理员账号无真实关联；删除或改名管理员后过滤器仍显示旧姓名 |
| 3 | `AuditLog.user` 为姓名字符串，无 adminId | settings/page.tsx:22–26 `user` 字段存姓名 | admins 数组有 `id` 字段 | P1 | 与用户管理模块中 leads/qaRecords/reports 均通过姓名字符串关联的问题一致（见用户管理审计报告）；审计日志通过姓名匹配操作人，账号改名后历史日志将无法关联 |
| 4 | `AdminAccount.role` 为角色名字符串，无 roleId | settings/page.tsx:15–19 `role` 字段存角色名 | roles 数组有 `id` 字段 | P1 | 角色改名后管理员表中的 `role` 字段值将与 `roles.name` 不一致，新增管理员 Dialog 也直接用 `role.name` 作为 value |
| 5 | `roles.users`（成员数）为硬编码静态值 | settings/page.tsx:8–12，`users: 2/6/18/1` | 实际成员数应从 `admins` 表聚合 | P1 | 增删管理员账号后角色成员数不会更新，是计算字段而非持久化字段 |
| 6 | 通知开关使用 `defaultValue`（非受控） | settings/page.tsx:131–132，9 个 Switch 均用 `defaultValue` | 无对应持久化数据 | P1 | 用户切换开关后刷新页面恢复初始值，任何通知偏好设置都不会保存 |
| 7 | `dashboardMetrics.value` 为格式化字符串 | mock-data.ts:5–15，如 `'12,846'`、`'184'` | 真实数据应为数字，格式化应在前端 | P2 | 后端返回格式化字符串会导致排序、比较、聚合失效；前端应接收 number，自行格式化 |
| 8 | `funnelData` 第 8 步 `'生成线索'` 的 value 784 与 `dashboardMetrics` 中"新增线索数" 784 相同，但 `funnelData` 第 7 步 `'预约顾问'` 的 value 193 与 `dashboardMetrics` 中"预约顾问数" 98 不同 | mock-data.ts:17–26 vs 4–15 | 同一份 mock 数据 | P2 | 看板指标卡和漏斗图数据来自同一数据源但数值不一致，接入真实数据时需明确两者是否使用同一聚合查询 |
| 9 | `knowledgeItems` 上传表单无 `version` 输入项 | knowledge-base/page.tsx:74–85，表单无 version 字段 | mock-data.ts:88–92，version 是必要展示字段 | P2 | 新上传的知识文件无法设置版本号，后端需决定是自动生成（如 v1.0）还是前端补充输入项 |
| 10 | `trendData` 完全内联在 page.tsx 中，与 mock-data.ts 中的 `dashboardMetrics` 部分重叠 | page.tsx:18–46（新增用户、线索数、AI 问答次数） | mock-data.ts:4–15 中有相同指标 | P2 | 两处数据独立维护，接入真实接口时需统一为单一 `/api/dashboard/metrics` 响应，避免两次查询 |
| 11 | 落地页客服 FAQ 为静态数组，admin 知识库有 FAQ 类型条目但两者完全独立 | support/page.tsx:12–17 | knowledge-base/page.tsx（type === 'FAQ' 的条目） | P2 | 客服页 FAQ 应从知识库的 FAQ 类型条目动态读取，以保持一致性；目前两处完全割裂 |

---

## 8. 页面状态缺口

### 8.1 数据看板

| 缺口 | 严重度 | 描述 |
|------|--------|------|
| 筛选器无效 | P0 | 4 个筛选维度（时间/活动/渠道/顾问）均有 UI 和状态，但"应用筛选"点击后数据完全不变；所有展示数据均为静态 mock |
| trendData 时间轴无标签 | P1 | 折线图 8 个数据点无对应日期，用户无法判断时间跨度，接入真实数据时需增加 x 轴时间序列 |
| 活动排行无筛选联动 | P1 | 活动排行表格和高意向线索列表均与筛选器状态无关联 |
| 分页为纯 UI | P2 | 两个 Table 的 pagination 使用本地 defaultCurrent/defaultPageSize，总数写死为数组长度，接入后需改为受控分页 |

### 8.2 知识库

| 缺口 | 严重度 | 描述 |
|------|--------|------|
| 搜索/筛选无效 | P0 | 搜索框、类型/状态/上传人 Select、日期范围选择器均无逻辑，查询和重置按钮均无绑定 |
| 新建知识内容按钮无 Dialog | P1 | "新建知识内容"按钮点击无任何反应，Dialog 未实现（对比"上传知识文件"已有 Dialog） |
| 上传进度为固定值 | P2 | Upload 表单中 Progress 固定为 68%，非真实上传进度 |
| fileType 仅展示，无文件实际预览 | P2 | 详情抽屉的"文件预览"区域为占位文本，无真实文件内容渲染 |
| refs 字段语义不明 | P2 | `refs` 是 AI 每次检索到该条目就 +1，还是用户看到该引用就 +1？需业务确认后才能设计写入时机 |

### 8.3 系统设置

| 缺口 | 严重度 | 描述 |
|------|--------|------|
| 所有保存按钮无逻辑 | P0 | 三个保存按钮（基础配置/AI 配置/安全策略）均无 onClick 绑定，所有配置修改丢失 |
| 通知开关非受控 | P0 | 9 个通知 Switch 均使用 `defaultValue` 而非 `value`，无法读取和持久化当前状态 |
| 角色/管理员 CRUD 仅有弹窗框架 | P1 | 新建角色和新增管理员的 Dialog 可以开关，但提交按钮无 onClick，表单无 ref/state，数据完全不保存 |
| 高风险动作规则为静态 JSX | P1 | AI 与合规 Tab 中的"高风险动作"区域（严重风险/高风险/中风险对应行动）为静态展示，无法配置；但 `settings/page.tsx:7–12` 中无对应数据结构，不确定是否计划做成可配置项 |
| integrationItems 集成配置页缺详细配置 | P1 | "去配置"按钮无路由跳转，微信小程序、短信、企业微信等实际 appId/secret 等配置项无任何 UI |
| `summary.logs` 写死为 `auditLogs.length` | P2 | 概览卡中"审计日志"数字等于 mock 数组长度（4），非真实日志总量 |

### 8.4 落地页客服页

| 缺口 | 严重度 | 描述 |
|------|--------|------|
| 留言表单无网络请求 | P0 | 提交留言仅 `setSubmitted(true)`，留言内容不会被保存，用户以为已提交但后端无任何记录 |
| 客服电话硬编码 | P1 | 电话号码与后台配置不一致（见冲突项 #1），且无法通过后台动态更新 |
| FAQ 为静态，与知识库割裂 | P1 | 4 条 FAQ 硬编码，无法通过知识库后台管理动态更新 |
| 留言表单无 userId/openid 关联 | P1 | 留言仅采集手机号，未关联当前登录用户的 userId，若用户未登录也无法溯源 |

---

## 9. 共用模型

以下模型在本次审计范围内，与其他模块存在跨页面使用关系：

| 实体 | 本模块使用位置 | 其他模块使用位置 | 关联关系 |
|------|--------------|----------------|---------|
| `activities` | 看板活动效果排行（page.tsx:178–191） | activities/page.tsx（独立模块） | 看板消费同一数据，增加 scan/register/materialClaims/assessments/appointments/highIntentLeads 聚合字段 |
| `leads` | 看板高意向线索列表（page.tsx:193–208） | leads/page.tsx（独立模块） | 看板消费同一实体，仅展示部分字段；过滤条件为 `score >= threshold` |
| `KnowledgeItem.type === 'FAQ'` | knowledge-base（管理） | landing-page/support/page.tsx（展示） | 客服页 FAQ 应从知识库动态读取，目前两者完全独立 |
| `PlatformConfig.servicePhone` | settings/page.tsx:71 | landing-page/support/page.tsx:59 | 同一业务配置，目前两处各自硬编码且数值不同 |
| `AdminAccount` | settings/page.tsx（管理） | activities/page.tsx `creator` 字段、knowledge-base/page.tsx `uploader` 字段 | uploader/creator 均为姓名字符串，应统一为 adminId 外键 |
| `RiskLevel` | lib/mock-data.ts:1（类型定义），lib/ui.ts:3（riskTheme） | 多个模块（leads、reports、qaRecords、看板） | 已有共享类型，接入 Supabase 时应定义为数据库枚举 |
| `LeadStatus` | lib/mock-data.ts:2（类型定义），lib/ui.ts:10（statusTheme） | leads、users、reports | 同上；注意已审计的"未生成"值未在枚举中定义（见用户管理审计报告） |

---

## 10. 推荐迁移顺序

优先级基于：数据正确性风险 > 用户可感知的功能失效 > 后台运营效率。

| 优先级 | 模块 | 迁移项 | 原因 |
|--------|------|--------|------|
| P0-1 | 落地页 | 留言提交接入真实 API（POST /api/support/feedback） | 用户以为留言已提交，实际数据全部丢失 |
| P0-2 | 落地页 | 客服电话从 /api/settings/public 动态读取 | 两个系统电话号码不一致，用户拨打错误号码 |
| P0-3 | 系统设置 | 通知开关改为受控组件，接入 GET/PUT /api/settings/notifications | 当前所有通知偏好无法保存，功能形同虚设 |
| P0-4 | 系统设置 | 三个保存按钮绑定 API | 所有配置修改均丢失 |
| P1-1 | 数据看板 | dashboardMetrics 接入聚合 API，删除内联 trendData，统一为 /api/dashboard/metrics | 核心数据仪表盘全是假数据，是最高价值页面 |
| P1-2 | 数据看板 | 筛选器接入后端参数传递 | 筛选 UI 已完整，唯一缺的是 API 调用 |
| P1-3 | 知识库 | 搜索/筛选接入 /api/knowledge?q=... | 知识库是 AI 检索核心，管理员必须能实际搜索 |
| P1-4 | 知识库 | 上传表单 Dialog 接入 POST /api/knowledge | 上传流程已有 UI，补充提交逻辑 |
| P1-5 | 系统设置 | 角色/管理员 CRUD 接入真实 API | 新增角色/管理员无法持久化 |
| P1-6 | 系统设置 | AdminAccount.role 改为 roleId 外键 | 防止角色改名导致关联断裂 |
| P2-1 | 知识库 | 落地页 FAQ 改为从知识库 type=FAQ 动态读取 | 保证客服侧信息一致性 |
| P2-2 | 知识库 | 上传表单补充 version 输入项 | 所有知识条目均展示版本号 |
| P2-3 | 系统设置 | AuditLog.user 改为 adminId 外键 | 防止改名后历史日志无法溯源 |
| P2-4 | 系统设置 | roles.users 改为从 admins 表聚合计算 | 静态数值在增删账号后立即过期 |
| P2-5 | 数据看板 | dashboardMetrics.value 后端返回 number，前端自行格式化 | 当前字符串 value 无法排序和比较 |
| P3-1 | 落地页 | FAQ 点击带 ?q= 参数预填 AI 输入框 | 改善用户体验，非阻塞 |
| P3-2 | 知识库 | refs 字段语义确认后实现写入逻辑 | 需业务决策，暂缓 |
| P3-3 | 系统设置 | 集成配置各项的专属配置 UI | 企业微信/Webhook 等需要独立配置页面 |

---

## 11. 不确定项

| # | 文件 | 系统 | 页面 | 字段/行为 | 假设 | 需确认 |
|---|------|------|------|---------|------|--------|
| 1 | settings/page.tsx:101–106 | admin | AI 与合规 | "高风险动作"规则区域（严重/高/中风险对应行动描述）为纯静态 JSX，无数据结构 | 假设这是固定业务规则展示，不需要配置化 | 若需可配置，则需新增 `riskActionRules` 配置实体 |
| 2 | mock-data.ts:88–92 | admin | 知识库 | `refs` 字段的写入时机：AI 每次检索 +1？还是用户看到引用 +1？ | 假设为 AI 每次成功检索并使用该条目时 +1（服务端写入） | 需与 AI 服务设计对齐，影响是否需要 knowledge_refs_log 表 |
| 3 | settings/page.tsx:28–33 | admin | 系统设置 | `integrationItems` 中"数据导出 Webhook"的具体配置项（url、secret、触发事件）未在页面体现 | 假设 Webhook 配置需要独立 Dialog 或子页面 | 需产品确认 Webhook 支持的事件类型和认证方式 |
| 4 | support/page.tsx:93 | landing | 客服页 | 留言表单未要求用户登录，但字段仅有 phone + content | 假设用户可能未登录，phone 是主要溯源手段；若用户已登录则应同时关联 userId | 需确认客服页是否仅在登录后可访问 |
| 5 | knowledge-base/page.tsx:83 | admin | 知识库 | Upload Dialog 中的 Progress 组件（固定 68%）是否为真实分段上传进度的占位 | 假设是占位，真实实现需要分片上传或后端返回进度 | 若文件较大（政策 PDF 等），是否需要 presigned URL 直传 Supabase Storage |
| 6 | page.tsx:18–46 | admin | 数据看板 | `trendData` 的 8 个历史点代表最近 8 周还是 8 天？与顶部时间范围筛选（1w/2w/1m/all）的关系？ | 假设默认为最近 8 个自然日，时间范围筛选改变 data 数组长度和密度 | 需与产品对齐时间粒度（日/周/月），影响后端聚合查询设计 |
| 7 | settings/page.tsx:69–74 | admin | 系统设置 | `PlatformConfig` 是全局单例（一行记录）还是支持多套配置（如不同活动有不同阈值）？ | 假设为全局单例，一张 `platform_config` 表一行记录 | 若需支持按活动/渠道覆盖配置，模型会有显著变化 |
