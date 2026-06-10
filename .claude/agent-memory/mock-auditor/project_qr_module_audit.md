---
name: project-qr-module-audit
description: QR code / invite code module mock audit completed; key findings about cross-entity ID misalignment and broken attribution chain
metadata:
  type: project
---

二维码 / 邀请码模块 mock 审计已完成，报告位于 `docs/mock-audit/二维码管理-mock-audit.md`。

**Why:** 二维码是整个业务漏斗的入口，`user.sourceQr` 和 `lead.qr` 的归因数据来自二维码扫码，下阶段接入 Supabase 前需要对齐所有来源标识符的值体系。

**How to apply:** 实现二维码模块真实 API 时，参考报告第 4、6、9 节的字段分类、API 建议和共用模型约定；优先处理 4 个高风险项。

核心发现：

- `user.sourceQr` / `lead.qr` / `qrCodeItems.id` / `qrCodeItems.inviteCode` 四者之间存在混用，5 条 user 记录中没有一条能精确匹配 `qrCodeItems.id`（如用户1 sourceQr 为 `ACT-20260702-001`，qrCode id 为 `QR-ACT-001`）
- 落地页完全没有实现 URL 参数读取（`?qr_id=` / `?invite=`），扫码注册的来源信息在入口就丢失，整个归因链路断裂
- 活动管理页生成邀请码格式为 `{activity.id}-INVITE`（如 `A003-INVITE`），与 `qrCodeItems.inviteCode`（如 `ACT20260702`）体系完全不同，并行存在两套邀请码格式
- 线索筛选"来源二维码"下拉用 `qrCodeItems.id`，线索 `lead.qr` 值与之不匹配，筛选命中率为 0
- `validPeriod` 为非结构化字符串（含"长期有效"特殊值），无法支持 DateRangePicker 回填和过期判断
- 所有写操作（新建、编辑、停用）无任何 API 调用；二维码图片为文字占位 `<div>QR</div>`
- 落地页 `EventLandingPage` 活动内容为硬编码默认值，未根据扫码二维码动态加载
