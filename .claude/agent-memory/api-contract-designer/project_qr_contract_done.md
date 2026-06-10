---
name: project-qr-contract-done
description: 二维码/邀请码模块 API 契约已完成，三个文件均已存在且内容完整，记录已完成状态和 DTO 数量
metadata:
  type: project
---

二维码/邀请码模块 API 契约已于 2026-06-10 完成，三个输出文件均已存在且内容完整，无需重新生成。

**Why:** 该模块契约由 api-contract-designer 角色在同一天完成，后续对话不需要重新输出文件。

**How to apply:** 若用户再次请求二维码模块契约，先读取现有文件验证完整性，再决定是否需要修改或补充，不要无条件重新生成。

已完成文件：
- `docs/api-contracts/二维码管理.md`（652 行，完整契约文档）
- `拓客系统-管理后台/lib/contracts/qr-code.ts`（426 行，管理后台类型定义）
- `拓客系统-落地页/lib/contracts/tracking.ts`（246 行，落地页扫码归因 DTO）

DTO 总数：21 个（不含枚举、错误码常量和响应包装基础类型）

关联：[[project-contracts-completed]] [[feedback-no-regenerate-existing]]
