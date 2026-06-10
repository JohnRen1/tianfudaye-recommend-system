---
name: migrate-mock-module
description: Orchestrate one business module migration from frontend mock data to contracts, Supabase schema, backend APIs, frontend integration, tests, and review.
argument-hint: "<模块名称、页面范围、业务规则和验收要求>"
---

# 迁移目标

将以下业务模块从 Mock 数据迁移为真实数据链路：

`$ARGUMENTS`

# 重要规则

- 本 Skill 在主会话执行。
- 普通子 Agent 不能继续调用其他子 Agent，由主会话串行调度。
- 每次只迁移一个业务模块。
- 不允许两个写代码 Agent 同时修改相同文件。
- 契约和数据库变更串行执行。
- 契约未确认，不进入后端实现。
- 存在 P0 或 P1，不得宣布完成。

# 阶段 1：Mock 审计

调用 `mock-auditor`：

- 扫描页面和 Mock
- 输出字段、实体、操作和状态
- 写入 `docs/mock-audit/`

主会话读取并检查范围。

# 阶段 2：API 契约

调用 `api-contract-designer`：

- 请求和响应 DTO
- 列表、详情和表单模型
- 分页、筛选和排序
- 错误码
- 认证和权限
- 写入 `docs/api-contracts/`

# 阶段 3：数据库

调用 `database-engineer`：

- 设计表
- 创建 migration
- 索引和约束
- RLS
- 测试 seed
- 写入 `docs/database/`

禁止自动推送远程数据库。

# 阶段 4：后端

调用 `backend-developer`：

- 实现校验、Service、Repository、Mapper 和 API
- 实现认证、权限和错误映射
- 编写单元测试和 API 测试

# 阶段 5：前端集成

根据范围串行调用：

- 落地页：`landing-page-integrator`
- 后台：`admin-system-integrator`
- 两者都涉及：依次调用两个 Agent

要求保留现有 UI，使用 API Client 和 Adapter，只删除已完成闭环的 Mock。

# 阶段 6：联调测试

调用 `integration-test-engineer`：

- 验证前端、后端和测试数据库闭环
- 验证认证、权限和错误状态
- 验证刷新后的持久化
- 扫描 Mock 残留
- 生成 `docs/test-reports/`

# 阶段 7：代码审查

调用 `code-reviewer`：

- 安全
- 权限和 RLS
- 契约一致性
- Mock 残留
- 测试完整性

输出 `REVIEW_BLOCKED` 时，调用对应 Agent 修复、重测并再次审查。

# 阶段 8：最终验证

主会话检查两个项目 `package.json`，只运行实际存在的 lint、typecheck、test 和 build。

# 最终报告

- 已迁移页面
- 已删除和剩余 Mock
- 契约
- 数据库变更
- API
- 权限与 RLS
- 测试结果
- 审查结果
- 风险
- 建议提交信息