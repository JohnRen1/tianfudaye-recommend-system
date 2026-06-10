---
name: audit-design-decisions
description: 审计总纲 S1-S6 在契约设计中的落地决策，供后续模块保持一致
metadata:
  type: project
---

审计总纲六大系统性问题的契约层决策（已在用户管理模块中确立，后续模块必须一致）：

**S1 — 字符串关联改外键**
- 所有实体间关联一律用 id 外键（userId / activityId / advisorId / qrCodeId 等）
- 名称字段（如 sourceActivityName）仅作服务端 join 后的展示补充，随 id 一并返回
- 不接受前端提交名称字符串作为关联键

**S2 — 落地页归因链**
- 登录/注册请求 DTO 携带 sourceQrId / sourceActivityId（落地页从 URL query 读取后提交）
- 已有用户登录时服务端不覆盖原始归因

**S3 — 写操作落库**
- 登录响应必须返回 accessToken + expiresAt，前端负责持久化 session
- 所有写操作响应返回更新后的完整 DTO

**S4 — 两端枚举统一**
- RiskLevel：统一 4 个英文值 low / medium / high / critical（落地页旧值 uncertain 待产品确认处理方式）
- LeadStatus：统一 8 个英文值，补全 none（"未生成"）
- 时间字段：全部 ISO 8601 字符串，禁止 "YYYY-MM-DD HH:mm" 无时区格式
- 两端共享枚举各维护一份 shared.ts 副本，必须同步

**S5 — 认证两套独立**
- 端用户（landing-page）：Bearer JWT，路径前缀 /api/auth/
- 管理员（admin-system）：Bearer JWT + role claim，路径前缀 /api/admin/auth/
- AdminRole 三值：market_ops / tax_advisor / manager
- 服务端生成字段（id / registeredAt / activeAt / openid / score）不得出现在任何 Create/Update DTO

**S6 — 统计值类型**
- Statistics DTO 所有值为 number，禁止返回格式化字符串（如 '12,846'）

**Why:** 这些决策来自跨模块审计，单看某一模块看不到，必须全局一致才能在接入 Supabase 时不返工。

**How to apply:** 设计任意模块契约时，先对照这 6 条检查，若有偏差记录兼容方案。
