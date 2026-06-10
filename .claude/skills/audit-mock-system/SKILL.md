---
name: audit-mock-system
description: Audit mock data and frontend data requirements for one business module before designing APIs or databases.
argument-hint: "<模块名称、页面范围和两个项目的目录信息>"
---

# 目标

对以下模块执行 Mock 数据审计：

`$ARGUMENTS`

# 执行流程

1. 在主会话调用 `mock-auditor`。
2. 扫描落地页和后台系统相关页面。
3. 查找 Mock、硬编码数据、类型、表格、表单、图表和模拟请求。
4. 输出业务实体、字段、页面操作、状态缺口和建议 API。
5. 报告写入 `docs/mock-audit/`。
6. 主会话检查：
   - 两个系统是否都覆盖
   - 是否区分列表、详情和表单模型
   - 是否标记字段冲突
   - 是否记录不确定项
7. 本 Skill 不进入数据库和 API 实现阶段。

# 完成条件

- 已生成审计报告。
- 已列出相关 Mock 来源。
- 已列出页面真实使用字段。
- 已列出状态和权限缺口。
- 已给出业务闭环迁移建议。