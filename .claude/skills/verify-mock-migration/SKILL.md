---
name: verify-mock-migration
description: Verify a module migration for contract consistency, persistence, permissions, tests, build health, and remaining mock dependencies.
argument-hint: "<模块名称、改动范围或 Git diff 范围>"
---

# 验证目标

验证以下 Mock 迁移结果：

`$ARGUMENTS`

# 步骤 1：范围确认

主会话读取：

- 当前 Git Diff
- Mock 审计报告
- API 契约
- 数据库说明
- 测试报告

# 步骤 2：联调测试

调用 `integration-test-engineer`：

- 执行真实本地 API 和测试数据库链路
- 验证 401、403、404、409、422、429、500
- 验证数据写入和再次查询
- 验证普通用户不能访问管理员功能
- 扫描 Mock 残留

# 步骤 3：代码审查

调用 `code-reviewer`，重点检查：

- Service Role 泄露
- 服务端权限
- RLS
- 契约偏差
- 数据库对象直接返回
- 重复提交
- 状态流转
- 前端虚假成功
- 测试是否只使用 Mock

# 步骤 4：构建检查

主会话检查真实脚本，执行可用的 lint、typecheck、test 和 build。

# 发布判断

仅在以下条件全部满足时输出 `READY_FOR_COMMIT`：

- 无 P0
- 无 P1
- 关键测试通过
- 构建通过
- 无生产代码 Mock 残留
- 契约、数据库和代码一致

否则输出 `NOT_READY` 并列出阻断项。