手动调用 6 步流程
假设我们要迁移"用户管理"模块，以下是具体操作方式：

第 1 步：Mock 数据审计
在 Cursor 的Chat 窗口输入：

@.claude/agents/mock-auditor.md 
请审计"用户管理"模块，包含以下范围：
落地页（拓客系统-落地页/）：
- app/loginpage.tsx（注册、登录表单）
- 相关 Mock 数据
管理后台（拓客系统-管理后台/）：
- app/users/page.tsx（用户列表）
- app/users/[id]/page.tsx（用户详情）
- lib/mock-data.ts 中的用户相关数据
请输出审计报告到 docs/mock-audit/用户管理-mock-audit.md
等待 Agent 完成后，检查输出文件是否生成，内容是否完整。

第 2 步：API 契约设计
在 Cursor Chat 窗口输入：

@.claude/agents/api-contract-designer.md
@docs/mock-audit/用户管理-mock-audit.md
基于上述 Mock 审计报告，设计"用户管理"模块的 API 契约，包括：
- 用户列表 API（分页、搜索、筛选）
- 用户详情 API
- 用户创建 API
- 用户更新 API
- 注册和登录 API
请输出到 docs/api-contracts/用户管理.md
等待完成后，检查契约文档是否包含所有必需的 DTO 定义。

第 3 步：数据库设计
在 Cursor Chat 窗口输入：

@.claude/agents/database-engineer.md
@docs/mock-audit/用户管理-mock-audit.md
@docs/api-contracts/用户管理.md
基于上述 Mock 审计报告和 API 契约，设计Supabase PostgreSQL 数据库：
- users 表结构
- 主键、外键、唯一约束
- 必要的索引（用户名搜索、邮箱查询）
- RLS 策略（管理员可见所有用户，普通用户只能查看自己）
请输出：
1. supabase/migrations/YYYYMMDDHHMMSS_create_users_table.sql
2. docs/database/用户管理.md（设计文档）
等待完成后，检查 migration 文件SQL 语法是否正确。

第 4 步：后端 API 实现
在 Cursor Chat 窗口输入：

@.claude/agents/backend-developer.md
@docs/api-contracts/用户管理.md
@docs/database/用户管理.md
实现"用户管理"后端 API，符合已确认的契约：
1. 用户列表 API（GET /api/users）
   - 分页、搜索（用户名、邮箱）、筛选（状态、角色）
   
2. 用户详情 API（GET /api/users/[id]）
   
3. 用户创建 API（POST /api/users）
   - 管理员权限校验
   
4. 用户更新 API（PATCH /api/users/[id]）
   - 管理员权限校验
   
5. 注册 API（POST /api/auth/register）
   
6. 登录 API（POST /api/auth/login）
请使用 Next.js Route Handlers，包含：
- lib/services/userService.ts
- lib/repositories/userRepository.ts
- Zod Schema 校验
- 单元测试
等待完成后，验证 API 是否符合契约。

第 5 步：前端集成
5.1 管理后台集成
在 Cursor Chat 窗口输入：

@.claude/agents/admin-system-integrator.md
@docs/mock-audit/用户管理-mock-audit.md
@docs/api-contracts/用户管理.md
接入"用户管理"真实 API，替换以下页面的 Mock 数据：
1. 拓客系统-管理后台/app/users/page.tsx
   - 接入 GET /api/users
   - 处理分页、搜索、筛选
   - Loading、Empty、Error 状态
   
2. 拓客系统-管理后台/app/users/[id]/page.tsx
   - 接入 GET /api/users/[id]
   - 接入 PATCH /api/users/[id]
   - 表单数据回显和提交
请创建：
- lib/api/users.ts（API Client）
- lib/adapters/userAdapter.ts（DTO 转换）
确认无其他引用后，删除 lib/mock-data.ts 中的用户 Mock。
5.2 落地页集成
在 Cursor Chat 窗口输入：

@.claude/agents/landing-page-integrator.md
@docs/mock-audit/用户管理-mock-audit.md
@docs/api-contracts/用户管理.md
接入"用户注册和登录"真实 API，替换以下页面的 Mock 数据：
拓客系统-落地页/app/login/page.tsx
- 接入 POST /api/auth/register
- 接入 POST /api/auth/login
- react-hook-form + zod 校验
- 防止重复提交
- 错误提示和成功跳转
请创建：
- lib/api/auth.ts（API Client）
等待完成后，启动 dev server 手动测试功能。

第 6 步：测试与审查
6.1 集成测试
在 Cursor Chat 窗口输入：

@.claude/agents/integration-test-engineer.md
@docs/mock-audit/用户管理-mock-audit.md
@docs/api-contracts/用户管理.md
测试"用户管理"模块的真实链路：
1. 用户注册流程
   - 落地页填写注册表单
   - API 校验和存储
   - 管理后台能查询到新用户
   
2. 管理员操作流程
   - 管理员登录
   - 查询用户列表
   - 搜索和筛选
   - 查看用户详情
   - 修改用户状态
   - 数据库持久化验证
   
3. 权限测试
   - 普通用户不能访问管理后台
   - 普通用户不能修改其他用户
请输出：
- docs/test-reports/用户管理-integration-test.md
- E2E 测试脚本（如需要）
- Mock 残留扫描结果
6.2 代码审查
在 Cursor Chat 窗口输入：

@.claude/agents/code-reviewer.md
@docs/mock-audit/用户管理-mock-audit.md
@docs/api-contracts/用户管理.md
@docs/database/用户管理.md
@docs/test-reports/用户管理-integration-test.md
审查"用户管理"模块的 mock-to-real 迁移代码，重点检查：
1. 安全问题
   - Service Role Key 是否硬编码
   - 管理员接口权限校验
   - RLS 策略是否生效
   
2. 契约一致性
   - API 响应是否符合契约
   - DTO 映射是否正确
   
3. 数据完整性
   - 唯一约束
   - 外键关系
   - 幂等性
   
4. Mock 残留
   - 是否还有写死的数据
   - setTimeout 模拟请求
   
请输出：
- docs/review-reports/用户管理-review.md
- P0/P1/P2/P3 问题清单
- 最终结论：REVIEW_PASSED 或 REVIEW_BLOCKED
