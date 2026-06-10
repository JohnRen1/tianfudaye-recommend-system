---
name: project-context
description: 项目基本结构、技术栈、契约目录约定和已完成模块
metadata:
  type: project
---

本项目为单 Git 仓库 + 两个独立 Next.js 项目（非 Monorepo，无 packages/ 目录）：
- `拓客系统-落地页/`：Next.js 16 + shadcn/ui + Tailwind，面向外部端用户
- `拓客系统-管理后台/`：Next.js 16 + tdesign-react + 原生 CSS，面向内部员工

**契约输出规范**（已确立）：
- 契约文档：`docs/api-contracts/<module-name>.md`
- 后台类型：`拓客系统-管理后台/lib/contracts/`
- 落地页类型：`拓客系统-落地页/lib/contracts/`
- 共享枚举（RiskLevel/LeadStatus/响应包装）：两个项目各维护一份副本，需人工同步

**Why:** 单仓库双项目结构不支持 packages/ 共享，两份副本是当前阶段唯一可行方案。

**How to apply:** 每次生成新模块契约时，确认共享类型是否需要更新两个项目的 shared.ts；在契约文档中注明同步约定。

**已完成模块**：
- 用户管理（2026-06-10）：`docs/api-contracts/用户管理.md`，类型文件 `admin/lib/contracts/user.ts`、`landing/lib/contracts/auth.ts`、两侧 `shared.ts`
