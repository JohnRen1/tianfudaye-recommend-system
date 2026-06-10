---
name: project-contracts-completed
description: 记录已完成的 API 契约模块清单，避免重复输出
metadata:
  type: project
---

截至 2026-06-10，以下 API 契约模块已完成（输出文件均已存在）：

| 模块 | 契约文档 | 后台类型文件 | 落地页类型文件 |
|------|---------|------------|--------------|
| 用户管理 | `docs/api-contracts/用户管理.md` | `拓客系统-管理后台/lib/contracts/user.ts` | `拓客系统-落地页/lib/contracts/auth.ts` |
| 二维码管理 | `docs/api-contracts/二维码管理.md` | `拓客系统-管理后台/lib/contracts/qr-code.ts` | `拓客系统-落地页/lib/contracts/tracking.ts` |

已存在的后台 contracts 目录文件（可能还有更多模块部分完成）：
- `activity.ts`、`lead.ts`、`qa-record.ts`、`qr-code.ts`、`shared.ts`、`user.ts`

已存在的落地页 contracts 目录文件：
- `activity.ts`、`auth.ts`、`shared.ts`、`tracking.ts`

**Why:** 防止未来对话重新生成已有文件，浪费时间并可能覆盖已有内容。

**How to apply:** 每次开始新模块契约前，先检查对应文件是否已存在。存在则读取验证完整性后决定是否需要补充，而非重新生成。
