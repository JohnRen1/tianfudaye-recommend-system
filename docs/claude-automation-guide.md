# Claude Agent 自动化搭建后台应用指南

## 概述

本文档说明如何使用 `.claude/` 目录下的 Agents 和 Skills 自动化完成后台应用从 Mock 数据到真实数据库、API 和前端集成的完整迁移。

---

## 前提条件

1. 两个项目（落地页和管理后台）的页面已基本完成，当前使用 Mock 数据
2. 已配置 `.claude/CLAUDE.md` 项目上下文
3. 已配置 8 个 Agent（`agents/` 目录）
4. 已配置 3 个 Skill（`skills/` 目录）

---

## 完整迁移流程（6 步）

### 第 1 步：Mock 数据审计

**目标**：识别某个业务模块（如"用户管理"）在落地页和管理后台中真实使用的数据、字段、操作和状态。

**执行方式**：

```
@mock-auditor 审计"用户管理"模块，包含以下范围：
- 落地页：注册、登录、个人信息
- 管理后台：用户列表、用户详情、用户编辑、用户状态管理
```

**或使用 Skill 快捷方式**：

如果已配置 `skills/audit-mock-system/SKILL.md`，可以直接调用：

```
使用 audit-mock-system skill 审计"用户管理"模块
```

**输出**：
- `docs/mock-audit/用户管理-mock-audit.md`
- 包含：Mock 来源清单、页面数据需求、业务实体和字段、页面操作、建议 API、字段冲突、状态缺口

**验收标准**：
- 已列出落地页和管理后台所有相关页面
- 已区分列表 DTO、详情 DTO、表单 DTO
- 已标记两个系统之间的字段差异
- 已列出不确定项（如某字段是计算字段还是存储字段）

---

### 第 2 步：API 契约设计

**目标**：基于 Mock 审计结果，设计前后端共同遵守的稳定 API 契约。

**执行方式**：

```
@api-contract-designer 基于"用户管理"Mock 审计报告，设计 API 契约
```

**输入依赖**：
- `docs/mock-audit/用户管理-mock-audit.md`

**输出**：
- `docs/api-contracts/用户管理.md`
- TypeScript 类型定义（可选，放在 `拓客系统-落地页/lib/contracts/` 和 `拓客系统-管理后台/lib/contracts/`）

**验收标准**：
- 已定义 Create DTO、Update DTO、Query DTO、List Item DTO、Detail DTO
- 已定义统一分页、筛选、排序、错误码格式
- 已说明认证和权限要求
- 已记录与现有页面的兼容性

---

### 第 3 步：数据库设计与 Migration

**目标**：设计 Supabase PostgreSQL 数据库表结构、约束、索引、RLS 策略。

**执行方式**：

```
@database-engineer 基于"用户管理"API 契约和 Mock 审计，设计数据库
```

**输入依赖**：
- `docs/mock-audit/用户管理-mock-audit.md`
- `docs/api-contracts/用户管理.md`

**输出**：
- `supabase/migrations/YYYYMMDDHHMMSS_用户管理.sql`
- `docs/database/用户管理.md`（包含表结构、约束、索引、RLS、迁移和回滚说明）

**验收标准**：
- 已定义主键、外键、唯一约束、Check Constraint
- 已创建必要索引（搜索、筛选、排序）
- 已定义 RLS 策略（管理员 vs 普通用户）
- 已提供本地测试 Seed 数据

**重要提示**：
- 不执行远程 `supabase db push`，只生成 migration 文件
- 不修改已有 migration，通过新 migration 变更

---

### 第 4 步：后端 API 实现

**目标**：实现符合契约的 Next.js Route Handlers / Server Actions，包含校验、权限、Service、Repository。

**执行方式**：

```
@backend-developer 实现"用户管理"后端 API，包含：
- 用户列表（分页、搜索、筛选）
- 用户详情
- 用户创建
- 用户更新
- 用户状态管理
```

**输入依赖**：
- `docs/api-contracts/用户管理.md`
- `docs/database/用户管理.md`
- `supabase/migrations/YYYYMMDDHHMMSS_用户管理.sql`

**输出**：
- `app/api/users/route.ts`（列表）
- `app/api/users/[id]/route.ts`（详情、更新）
- `app/api/users/create/route.ts`（创建）
- `lib/services/userService.ts`
- `lib/repositories/userRepository.ts`
- 单元测试和 API 集成测试

**验收标准**：
- 所有接口符合契约
- 数据库对象不直接返回，已映射为响应 DTO
- 管理员接口已校验角色
- Service Role Key 只从环境变量读取
- 测试覆盖正常、缺参、权限不足、资源不存在、状态冲突

---

### 第 5 步：前端集成（管理后台 + 落地页）

**目标**：替换 Mock 数据，接入真实 API，处理 Loading、Empty、Error、权限等状态。

#### 5.1 管理后台集成

**执行方式**：

```
@admin-system-integrator 接入"用户管理"真实 API，替换以下页面 Mock：
- 用户列表（app/users/page.tsx）
- 用户详情（app/users/[id]/page.tsx）
```

**输入依赖**：
- `docs/mock-audit/用户管理-mock-audit.md`
- `docs/api-contracts/用户管理.md`
- 已实现的后端 API

**输出**：
- 修改 `拓客系统-管理后台/app/users/page.tsx`
- 新增 `拓客系统-管理后台/lib/api/users.ts`（API Client）
- 新增 `拓客系统-管理后台/lib/adapters/userAdapter.ts`（DTO 转换）
- 删除 `拓客系统-管理后台/lib/mock-data.ts` 中的用户 Mock（确认无其他引用后）

**验收标准**：
- 表格分页、搜索、筛选、排序已接入真实接口
- Loading、Empty、Error 状态已处理
- 表单提交成功后刷新列表
- URL 查询参数与表格状态同步

#### 5.2 落地页集成

**执行方式**：

```
@landing-page-integrator 接入"用户注册和登录"真实 API，替换以下页面 Mock：
- 注册表单（app/login/page.tsx）
- 登录表单（app/login/page.tsx）
```

**输入依赖**：
- `docs/mock-audit/用户管理-mock-audit.md`
- `docs/api-contracts/用户管理.md`
- 已实现的后端 API

**输出**：
- 修改 `拓客系统-落地页/app/login/page.tsx`
- 新增 `拓客系统-落地页/lib/api/auth.ts`
- 表单使用 `react-hook-form + zod` 校验

**验收标准**：
- 表单客户端校验、服务端错误映射
- 防止重复提交
- 成功后跳转或刷新
- 网络异常和限流提示

---

### 第 6 步：集成测试与代码审查

#### 6.1 集成测试

**目标**：验证真实业务闭环（前端 → API → 数据库 → 前端）。

**执行方式**：

```
@integration-test-engineer 测试"用户管理"完整链路：
- 管理员登录 → 查询用户列表 → 搜索和筛选 → 查看详情 → 修改状态
- 新用户注册 → 登录 → 后台能查询到该用户
```

**输入依赖**：
- `docs/mock-audit/用户管理-mock-audit.md`
- `docs/api-contracts/用户管理.md`
- 已接入的前端页面
- 已实现的后端 API

**输出**：
- `docs/test-reports/用户管理-integration-test.md`
- E2E 测试脚本（Playwright）
- Mock 残留扫描报告

**验收标准**：
- 真实业务闭环通过
- 权限测试通过（普通用户不能执行管理员操作）
- 数据库持久化验证通过
- 无 Mock 残留（写死的 `total`、`setTimeout` 模拟请求等）

#### 6.2 代码审查

**执行方式**：

```
@code-reviewer 审查"用户管理"模块的 mock-to-real 迁移代码
```

**输入依赖**：
- `docs/mock-audit/用户管理-mock-audit.md`
- `docs/api-contracts/用户管理.md`
- `docs/database/用户管理.md`
- `docs/test-reports/用户管理-integration-test.md`
- 当前 Git Diff

**输出**：
- `docs/review-reports/用户管理-review.md`
- P0/P1/P2/P3 问题清单
- 最终结论：`REVIEW_PASSED` 或 `REVIEW_BLOCKED`

**验收标准**：
- 无 P0 或 P1 安全、数据完整性、契约一致性问题
- Service Role Key 未硬编码
- RLS 已生效
- Mock 已清理

---

## 快捷 Skill 使用方式

如果配置了 `skills/` 目录的 3 个 Skill，可以用更简洁的命令：

### Skill 1: audit-mock-system

```
使用 audit-mock-system skill 审计"线索管理"模块
```

内部会自动调用 `@mock-auditor`，扫描落地页和管理后台，输出审计报告。

### Skill 2: migrate-mock-module

```
使用 migrate-mock-module skill 迁移"线索管理"模块
```

内部会自动按顺序调用：
1. `@api-contract-designer`
2. `@database-engineer`
3. `@backend-developer`
4. `@admin-system-integrator` 或 `@landing-page-integrator`

### Skill 3: verify-mock-migration

```
使用 verify-mock-migration skill 验证"线索管理"模块迁移
```

内部会自动调用：
1. `@integration-test-engineer`
2. `@code-reviewer`

---

## 模块迁移优先级

建议按以下顺序迁移模块（从简单到复杂）：

1. **用户管理**：字段少、关系简单、两个系统都有
2. **活动管理**：管理后台为主，落地页只读
3. **二维码管理**：依赖活动，字段简单
4. **资料管理**：包含文件上传
5. **线索管理**：依赖用户、活动、测评报告，关系复杂
6. **测评报告**：依赖用户，数据结构复杂
7. **AI 问答记录**：依赖用户，数据量大
8. **知识库**：管理后台为主，可能需要向量搜索
9. **数据看板**：依赖所有其他模块的统计数据

---

## 注意事项

### 安全规则

- Service Role Key 只能通过环境变量读取，禁止硬编码
- 管理员接口必须服务端角色校验，前端隐藏按钮不能替代
- 敏感信息不写入日志
- RLS 策略必须覆盖所有表

### Mock 清理规则

只有以下条件全部满足才能删除 Mock：

1. API 契约已确认
2. 数据库和 API 已实现
3. 页面已接入真实接口
4. 状态处理完成（Loading、Empty、Error、权限）
5. 真实链路测试通过
6. 没有其他页面引用该 Mock

### Git 规则

- 每个模块迁移开独立分支（如 `feat/migrate-user-management`）
- 不直接提交到 `main`
- 未经确认不自动 push
- 提交前确认 `.gitignore` 已排除 `.next/`、`node_modules/`、`tsconfig.tsbuildinfo`

### 验证命令

每次修改后必须执行：

```bash
cd 拓客系统-管理后台
pnpm exec tsc --noEmit
pnpm lint
pnpm test
pnpm build
```

---

## 常见问题

### Q1: Agent 说找不到某个文件？

检查：
1. 目录路径是否正确（`拓客系统-落地页/` vs `拓客系统-管理后台/`）
2. 文件是否已提交到 Git
3. `.gitignore` 是否误排除了该文件

### Q2: 后端 API 实现后，前端集成报 404？

检查：
1. 路由路径是否符合契约
2. Next.js 是否重启（`pnpm dev`）
3. 环境变量是否配置（`.env.local`）

### Q3: 数据库 migration 失败？

检查：
1. Supabase 本地环境是否启动（`supabase start`）
2. migration 文件 SQL 语法是否正确
3. 是否有外键约束冲突

### Q4: 前端接入后数据显示异常？

检查：
1. DTO Adapter 是否正确映射字段
2. 时间字段是否统一 ISO 8601 格式
3. 枚举值是否与契约一致
4. 浏览器 Network 面板查看 API 实际返回数据

### Q5: Mock 删除后其他页面报错？

说明还有其他页面引用该 Mock，需要先完成所有相关页面的集成，再统一删除 Mock。

---

## 总结

通过 6 步流程（审计 → 契约 → 数据库 → 后端 → 前端 → 测试审查），可以系统化地完成一个业务模块从 Mock 到真实数据的完整迁移。

每个 Agent 的职责明确、输入输出清晰，确保迁移过程可追溯、可验证、可回滚。
