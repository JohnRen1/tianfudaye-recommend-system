# Mock 数据审计总纲（index）

**编写日期**：2026-06-10
**覆盖范围**：admin-system 全部页面 + landing-page 全部页面，共 8 个业务模块
**项目阶段**：MVP 原型阶段，数据全部来自 mock，无真实数据库和身份认证
**用途**：跨模块结论汇总，作为下一阶段 API 契约设计与数据库 migration 的输入

---

## 报告清单

| 模块 | 报告 | 修复方案 |
|------|------|----------|
| 用户管理 | [`用户管理-mock-audit.md`](./用户管理-mock-audit.md) | [`用户管理-修复方案.md`](./用户管理-修复方案.md) |
| 活动管理 | [`活动管理-mock-audit.md`](./活动管理-mock-audit.md) | — |
| 线索管理（含预约） | [`线索管理-mock-audit.md`](./线索管理-mock-audit.md) | — |
| 二维码管理 | [`二维码管理-mock-audit.md`](./二维码管理-mock-audit.md) | — |
| 资料管理 | [`资料管理-mock-audit.md`](./资料管理-mock-audit.md) | — |
| 测评报告 | [`测评报告-mock-audit.md`](./测评报告-mock-audit.md) | — |
| 问答记录 | [`问答记录-mock-audit.md`](./问答记录-mock-audit.md) | — |
| 辅助模块（知识库/看板/设置/客服） | [`辅助模块（知识库-看板-设置）-mock-audit.md`](./辅助模块（知识库-看板-设置）-mock-audit.md) | — |

---

## 一、六大跨模块系统性问题

这些是单看某一份报告看不到、但贯穿全系统的结构性问题，必须在 API 契约和数据库设计阶段优先解决。

### S1 — 字符串关联蔓延全系统（最高优先）

整个 mock 体系几乎没有 id 外键，全靠名称字符串关联：

| 关联类型 | 现状（字符串匹配） | 涉及位置 |
|----------|-------------------|----------|
| 实体 → 用户 | `leads.name` / `reports.user` / `qaRecords.user` / `auditLogs.user` 均存姓名 | `mock-data.ts:54,60,66`、`settings/page.tsx:22` |
| 实体 → 活动 | `users.sourceActivity` / `leads.activity` / `qrCodeItems.activity` / `materialItems.activity` / `qaRecords.activity` 均存活动名 | `mock-data.ts:36,66,72,80,54` |
| 实体 → 顾问 | `leads.advisor` / `reports.advisor` / `qrCodeItems.advisor` 均存"周顾问"等姓名 | `mock-data.ts:66,60,72` |
| 实体 → 角色 | `admins.role` 存角色名而非 roleId | `settings/page.tsx:15` |
| 实体 → 二维码 | `leads.qr` 存混合标识，与 `qrCodeItems.id`/`inviteCode` 均不齐 | `mock-data.ts:66` |

**风险**：任意用户改名、活动改名、顾问改名、角色改名，全链路历史数据立即断裂；同名用户数据互相污染。
**对策**：所有实体引入 id 外键（`userId` / `activityId` / `advisorId` / `roleId` / `qrCodeId`），名称仅用于展示时 join。

### S2 — 扫码归因链从源头断裂（P0，直击核心业务漏斗）

三处断裂叠加，导致"扫码 → 注册 → 线索"的归因数据**根本采集不到**：

1. 二维码管理生成的追踪链接带 `?qr_id=&invite=`，但**落地页没有任何代码读取 URL 参数**（`拓客系统-落地页/app/page.tsx` 直接渲染 `<EventLandingPage />`，无 `useSearchParams`）
2. 二维码标识四套命名互不对齐：`user.sourceQr`（`ACT-20260702-001`）／ `qrCodeItems.id`（`QR-ACT-001`）／ `inviteCode`（`ACT20260702`）／ 活动页拼接 `{id}-INVITE`（`A003-INVITE`）
3. `activity_id` 参数同样被落地页忽略，所有用户看到同一份 `defaultEventData`

**对策**：统一二维码标识体系（建议以 `qrCodeId` 为外键）；落地页入口读取 `qr_id`/`activity_id`/`invite` 并贯穿注册流程；活动落地页按 `activity_id` 渲染对应活动。

### S3 — 落地页所有写操作不落库

六条核心转化动作全是纯前端 state，刷新即丢，后台完全不可见：

| 动作 | 落地页位置 | 现状 |
|------|-----------|------|
| 注册/登录 | `login-register-form.tsx:58,68` | 仅 `onSuccess?.()`，无 session |
| 资料领取 | `materials-page.tsx:146` | 仅改本地 state，`claims` 不更新 |
| AI 问答 | `tax-ai-assistant-page.tsx` | `messages` 仅 React state |
| 测评提交 | `risk-assessment-quiz-page.tsx` | 跳转 `?score=`，无落库 |
| 预约 | `appointment/page.tsx` | 仅 `setSubmitted(true)` |
| 客服留言 | `support/page.tsx` | 仅 `setSubmitted(true)` |

**后果**：看板所有指标永远不会因真实用户行为变化；业务漏斗每一步都中断。
**对策**：每个动作配对一个落库 API；落地页先实现 session 持久化（见 S5）。

### S4 — 两端字段命名/枚举各成一套（共享类型时必然冲突）

| 模块 | 字段 | landing-page | admin-system | 风险 |
|------|------|--------------|--------------|------|
| 问答 | 风险等级 | 英文三值 `medium/high/uncertain` | 中文四值 `低/中/高/严重风险` | 高，`uncertain` 在 admin 不存在 |
| 问答 | 涉及风险 | `involvedRisks: string[]` | `risks: string` | 高，格式不通 |
| 问答 | 处理建议 | `suggestions: string[]` | `suggestion: string` | 高，名称+类型都不同 |
| 资料 | 企业信息门槛 | `needsCompanyInfo` | `needCompanyInfo` | 高，差一个 s |
| 资料 | id | `number`（1/2/3） | `string`（`MAT-001`） | 高 |
| 资料 | `status` | 领取状态 available/claimed | 上架状态 已上架/草稿 | 高，同名异义 |
| 测评 | `answers` | 选项索引 `Record<number,number[]>` | 自然语言摘要 string[] | 高，无法互转 |
| 测评 | 模块 | 报告 5 模块 | 题库 8 模块 | 高，对不上 |
| 活动 | 时间 | `date`+`time` 拆分 | `time` 单字符串 | 高 |
| 活动 | 讲师/地点 | `speaker`+`speakerTitle`/`location` | `teacher`/`place` | 高 |

**对策**：API 契约阶段定义共享 DTO 与枚举（建议放共享 types 包或对齐命名规范），数据库存原始值、前端负责格式化与展示映射。

### S5 — 认证与会话整体缺失（高风险，安全相关）

- 落地页：登录后无 token/cookie/context，刷新即丢登录态（`login-register-form.tsx`）
- 后台：token 固定字符串 `mock-admin-token`，`admin-shell.tsx:63` 仅判断 key 是否存在，手填 localStorage 即绕过；角色用 `username==='admin'` 二分，与 CLAUDE.md 规定的三角色（市场运营/税务顾问/管理者）不符
- 测评分数可篡改：`report/page.tsx` `score = Number(searchParams.get("score"))`，改 URL 即伪造风险等级

**对策**：随 Supabase Auth 接入统一设计，端用户与管理员两套身份；路由级权限守卫；服务端生成并校验测评报告，不信任 URL 参数。

### S6 — 看板/统计指标全是写死值且自相矛盾

- `dashboardMetrics.value` 是格式化字符串 `'12,846'`（应为 number，否则排序/聚合失效）
- 漏斗"预约顾问" 193 与指标卡"预约顾问数" 98 不一致，同源两值（`mock-data.ts:17-26` vs `4-15`）
- 活动数据抽屉对所有活动展示同一份全局 `funnelData`（无 `activityId` 归因）
- 角色成员数 `roles.users`、审计日志数 `summary.logs` 等均为写死/数组长度，非真实聚合

**对策**：看板每个指标明确聚合来源（哪个实体/事件），后端返回 number；活动漏斗按 activityId 归因。

---

## 二、各模块高风险项速查

| 模块 | 高风险项数 | 代表性高风险 |
|------|-----------|-------------|
| 用户管理 | 4 | leadStatus 枚举缺"未生成"；name 字符串关联；后台 token 形同虚设；落地页无会话 |
| 活动管理 | 6 | 两端时间/讲师/地点字段全不一致；description/coverImage admin 侧缺失；落地页无 activity_id 读取；漏斗不归因 |
| 线索管理 | 5 | name 字符串关联 User/Report/QA；activity/qr 外键缺失；leadStatus 冲突；预约不落库；预约不关联用户 |
| 二维码管理 | 4 | 三套二维码标识不对齐；落地页无 URL 参数读取；线索按二维码筛选命中率 0；活动页邀请码体系孤立 |
| 资料管理 | 5 | needCompanyInfo 拼写不一致；type 枚举中英文不通；status 同名异义；id 类型不同；领取记录实体完全缺失 |
| 测评报告 | 3 | report 按姓名关联；题库与报告模块对不上；answers 格式不可互转；分数可被 URL 篡改 |
| 问答记录 | 3 | RiskLevel 枚举体系不同（uncertain 缺失）；risks/suggestions 类型不同；问答不落库 |
| 辅助模块 | 多 P0 | 客服电话两端不一致；所有设置保存无逻辑；通知开关非受控；看板筛选无效 |

---

## 三、统一迁移优先级

按"是否阻塞核心业务漏斗 + 是否影响数据正确性"排序，跨模块统一编排：

### P0 — 数据模型地基（必须最先做，否则全部返工）
1. **统一 id 外键体系**（S1）：定义 User/Activity/Advisor/Role/QrCode/Material 主键，所有关联改外键
2. **统一二维码标识 + 落地页归因**（S2）：定一套二维码 id，落地页读 URL 参数贯穿注册
3. **统一两端枚举与 DTO 命名**（S4）：RiskLevel、LeadStatus（补"未生成"）、资料 type、测评模块
4. **领取记录、预约、appointments 等缺失实体补齐**（S3 相关）

### P1 — 认证与核心写入
5. **认证与会话**（S5）：端用户 + 管理员两套身份，路由权限守卫
6. **落地页六条写操作落库**（S3）：注册/领取/问答/测评/预约/留言
7. **测评服务端化**（S5）：分数后端生成校验，杜绝 URL 篡改
8. **各 admin 列表筛选 + 写操作**：当前几乎所有筛选/编辑/批量/导出均为占位

### P2 — 统计与体验
9. **看板指标聚合**（S6）：明确每个 metric 来源，活动漏斗按 activityId 归因
10. **知识库 ↔ 问答 RAG 引用、知识库 ↔ 客服 FAQ 打通**
11. 草稿保存、登录后续跳转、领取门槛拦截等体验缺口

---

## 四、共享模型清单（API 契约阶段需共同约定）

| 实体 | 跨系统使用 | 关键统一点 |
|------|-----------|-----------|
| User | landing 注册者 / admin 管理对象 | id 主键、phone 存储格式、openid 与 phone 账号合并 |
| Activity | landing 展示 / admin CRUD | id 外键、时间字段拆分、speaker/location 命名、description/coverImage 补齐 |
| QrCode | landing 扫码归因 / admin CRUD | 统一 id 体系、inviteCode、validPeriod 结构化、URL 参数协议 |
| Material + MaterialClaim | landing 领取 / admin 目录 | 目录实体与领取记录拆分、type/format/status 枚举统一、id 类型 |
| AssessmentReport | landing 生成 / admin 查看 | 服务端评分、模块结构统一、answers 格式、RiskLevel 共享 |
| QaRecord | landing 问答 / admin 管理 | RiskLevel 枚举、risks/suggestions 类型、字段命名、知识库引用 |
| Lead | landing 预约转化 / admin 管理 | userId/activityId/qrCodeId/advisorId 外键、状态机、预约联动 |
| Advisor / AdminUser | admin 全模块 | 独立实体、roleId 外键、三角色权限 |
| KnowledgeItem | admin 管理 / landing FAQ+RAG | FAQ 类型打通客服页、refs 写入时机 |
| DashboardMetric | admin 看板 | number 类型、聚合来源、活动级归因 |

---

## 五、审计完成标准核对

- 未修改任何业务代码
- 未删除任何 Mock
- 未创建数据库 migration
- 未实现任何 API
- 所有结论附 `file_path:line_number` 证据（见各模块报告）
- 高风险不一致项已逐模块汇总并跨模块归纳为 6 大系统性问题
