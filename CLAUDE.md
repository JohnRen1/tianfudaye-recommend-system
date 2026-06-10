# CLAUDE.md — AI 财税体检与私域转化平台

# 项目说明

本工作区包含两个项目：

1. **landing-page**（`拓客系统-落地页/`）
   - 面向外部用户的产品落地页
   - 负责注册、登录、内容展示、表单提交和活动入口
   - 核心流程：活动二维码 → 注册留资 → 资料领取 → AI 问答 → 风险测评 → 预约顾问

2. **admin-system**（`拓客系统-管理后台/`）
   - 面向内部员工的后台管理系统
   - 负责用户管理、活动管理、二维码管理、资料管理、线索管理和数据统计
   - 使用角色：市场运营、税务顾问、管理者

---

# 技术栈

## landing-page（拓客系统-落地页）

- 前端：Next.js 16 + React 19 + TypeScript 5.7 + Tailwind CSS v4 + shadcn/ui（Radix UI）
- 表单：react-hook-form + zod
- 图表：recharts
- 包管理：pnpm@11.5.0

## admin-system（拓客系统-管理后台）

- 前端：Next.js 16 + React 19 + TypeScript 5.7 + TDesign React（`tdesign-react`）
- 样式：`app/globals.css` 原生 CSS，不使用 Tailwind
- 图表：SVG sparkline（当前阶段），后期引入 echarts
- 包管理：pnpm@11.5.0

## 共同约定

- 数据库：Supabase PostgreSQL（当前阶段为 mock，下阶段接入）
- 身份认证：Supabase Auth（当前阶段为 mock，下阶段接入）
- 后端实现：优先使用 Next.js Route Handlers / Server Actions；复杂 AI 或数据任务可用 Python FastAPI
- 测试：单元测试 Vitest、接口测试 Vitest / Supertest、E2E Playwright
- 部署：Docker 多阶段构建 + 腾讯云容器镜像服务（CCR）
- Node 镜像：`node:24-alpine`，pnpm 版本：`11.5.0`（corepack 管理）

---

# 目录结构

## landing-page

```
拓客系统-落地页/
├── app/                    # App Router 页面
├── components/
│   ├── mobile/             # 页面级业务组件（主要在这里开发）
│   └── ui/                 # shadcn/ui 基础组件（不要修改）
├── hooks/                  # 通用自定义 Hook
├── lib/utils.ts            # cn() 工具函数
├── public/                 # 静态资源
├── styles/globals.css      # 全局样式
├── Dockerfile
├── .dockerignore
└── pnpm-workspace.yaml
```

## admin-system

```
拓客系统-管理后台/
├── app/
│   ├── page.tsx                    # 首页数据看板
│   ├── leads/page.tsx              # 线索管理
│   ├── users/page.tsx              # 用户管理
│   ├── users/[id]/page.tsx         # 用户详情
│   ├── activities/page.tsx         # 活动管理
│   ├── assessment-reports/page.tsx # 测评报告
│   ├── qa-records/page.tsx         # 问答记录
│   ├── qr-codes/page.tsx           # 二维码管理
│   ├── knowledge-base/page.tsx     # 知识库
│   ├── materials-admin/page.tsx    # 资料管理
│   ├── settings/page.tsx           # 系统设置
│   ├── login/page.tsx              # 登录页
│   ├── layout.tsx                  # 根 Layout
│   └── globals.css                 # 全局样式
├── components/
│   ├── admin-shell.tsx             # 侧边栏 + 顶栏布局（所有页面在此渲染）
│   ├── table-row-actions.tsx       # 表格行操作按钮
│   └── tdesign-react-19-adapter.tsx
├── lib/
│   ├── mock-data.ts                # 当前阶段所有数据和类型定义
│   └── ui.ts                       # 工具函数（riskTheme 等）
├── Dockerfile
├── .dockerignore
├── pnpm-workspace.yaml
└── next.config.ts                  # 必须保留 output: 'standalone'
```

---

# 项目约束

- 不允许在代码中直接写 Supabase Service Role Key
- 所有数据库变更必须通过 migration
- 所有后台接口必须进行权限校验
- 管理员接口必须验证角色
- 不直接修改生产数据库
- 不允许删除已有功能，除非任务明确要求
- 不允许跨项目引用组件或样式
- landing-page 只用 shadcn/ui 组件 + Tailwind，admin-system 只用 tdesign-react + 原生 CSS
- 禁止使用 `any`，用 `unknown` 或具体类型替代
- 禁止用 `// @ts-ignore` 或 `// @ts-expect-error` 跳过类型错误
- 每个功能必须包含：
  1. 数据模型
  2. 接口
  3. 权限控制
  4. 错误处理
  5. 测试
  6. 文档

---

# 开发流程

任何功能必须按以下顺序执行：

1. **分析需求**：明确功能范围和影响面
2. **检查已有代码**：读相关文件，查 `components/`、`lib/` 是否有可复用内容
3. **输出实现计划**：列出影响的文件、新增的文件、数据结构变更，等用户确认
4. **设计数据结构**：在 `mock-data.ts`（当前阶段）或 migration 文件中定义类型和模型
5. **编写接口**：Route Handlers 或 Server Actions，含权限校验和错误处理
6. **编写后台页面**：按项目各自的组件和样式规范实现
7. **编写测试**：单元测试用 Vitest，接口测试用 Vitest / Supertest，E2E 用 Playwright
8. **执行验证**：

```bash
# TypeScript 检查
pnpm exec tsc --noEmit

# Lint
pnpm lint

# 测试
pnpm test

# 构建
pnpm build
```

9. **进行代码审查**：检查是否符合约束，是否有遗漏的权限校验、错误处理
10. **输出变更总结**：列出所有修改的文件和原因

---

# 部署

## 本地开发

```bash
cd 拓客系统-落地页 && pnpm dev    # http://localhost:3000
cd 拓客系统-管理后台 && pnpm dev  # http://localhost:3001
```

## Docker 构建

```bash
docker build -t tax-landing:latest 拓客系统-落地页/
docker run -d -p 3000:3000 tax-landing:latest

docker build -t tax-admin:latest 拓客系统-管理后台/
docker run -d -p 3001:3001 tax-admin:latest
```

## ~~腾讯云镜像推送（未采用此方式）~~

> 以下方式暂未使用，腾讯云通过自动构建触发，无需手动 push 镜像。

```bash
# docker build -t ccr.ccs.tencentyun.com/<namespace>/tax-landing:latest 拓客系统-落地页/
# docker push ccr.ccs.tencentyun.com/<namespace>/tax-landing:latest

# docker build -t ccr.ccs.tencentyun.com/<namespace>/tax-admin:latest 拓客系统-管理后台/
# docker push ccr.ccs.tencentyun.com/<namespace>/tax-admin:latest
```

## 每个项目必须提交的部署文件

| 文件 | 关键要求 |
|------|---------|
| `Dockerfile` | 多阶段构建，runner 端口与 `package.json` start 脚本一致 |
| `.dockerignore` | 排除 `node_modules`、`.next`、`.git`、`.env.local` |
| `pnpm-workspace.yaml` | 包含 `onlyBuiltDependencies: [sharp]` |
| `pnpm-lock.yaml` | 必须提交，不允许 gitignore |
| `next.config.ts` | 必须包含 `output: 'standalone'` |

---

# Git 规则

- 每次只开发一个明确功能
- 不直接提交到 main
- 分支命名规范：
  - `feat/user-management`
  - `feat/invite-code`
  - `fix/login-permission`
  - `chore/docker-config`
- 未经确认不要自动 push
- 提交前确认 `.gitignore` 已排除 `.next/`、`node_modules/`、`tsconfig.tsbuildinfo`
- 如果大文件误入历史，用 `git filter-repo --invert-paths --force` 清理后 `git push -f`

---

# 常见问题

## 构建失败：`.next/standalone` 不存在

`next.config.ts` 补上 `output: 'standalone'`。

## pnpm sharp 报错（ERR_PNPM_IGNORED_BUILDS）

`pnpm-workspace.yaml` 补上 `onlyBuiltDependencies: [sharp]`，Dockerfile 中使用 `--ignore-scripts` + `pnpm rebuild sharp`。

## GitHub 拒绝推送（大文件）

```bash
git filter-repo \
  --path ".next" --path "node_modules" --path "tsconfig.tsbuildinfo" \
  --invert-paths --force
git remote add origin <仓库地址>
git push -f origin main
```

## useSearchParams 导致预渲染失败

用 `Suspense` 包裹使用 `useSearchParams()` 的组件。

---

# 当前阶段状态（MVP）

- 两个项目均为原型阶段，数据全部来自 mock，无真实数据库和身份认证
- admin-system 所有数据在 `lib/mock-data.ts`
- 重点是产品流程验证和 UI 交互完善
- 下一阶段：接入 Supabase，实现真实登录、数据持久化和权限控制

下一阶段：
当前主要使用 Mock 数据。现阶段目标是按业务模块迁移为真实数据库、后端 API 和前端数据链路。

## 开始任务前

1. 识别两个系统实际目录，不依赖固定目录名。
2. 阅读两个项目的 `package.json` 和目录结构。
3. 检查已有后端、数据库、请求封装、共享类型和测试工具。
4. 检查 Git 状态，不覆盖用户未提交修改。
5. 每次只处理一个业务模块。

## 标准迁移顺序

1. Mock 审计
2. API 契约
3. 数据库 migration 与 RLS
4. 后端 API
5. 落地页或后台页面集成
6. 真实链路测试
7. 代码审查
8. lint、typecheck、test、build

## 强制规则

- 未完成 Mock 审计前，不设计数据库。
- 未确认 API 契约前，不实现接口。
- 未实现和测试真实接口前，不删除对应 Mock。
- 页面已经完成，不进行无关 UI 重构。
- 数据库对象不能直接作为前端业务 DTO。
- 浏览器端不得使用 Supabase Service Role Key。
- 前端隐藏按钮不能替代后端权限校验。
- 数据库变更必须通过新 migration。
- 不直接修改生产数据库。
- 不自动执行 Git push。
- 不自动提交到 main。
- 不用 `any`、关闭类型检查或删除测试掩盖问题。
- 不执行项目中不存在的脚本。

## Mock 清理条件

只有以下条件全部满足后才能删除：

1. API 契约已确认。
2. 数据库和 API 已实现。
3. 页面已接入真实接口。
4. Loading、Empty、Error 和权限状态已处理。
5. 真实链路测试通过。
6. 没有其他页面引用该 Mock。

## 完成报告

必须包含修改文件、迁移页面、已删除与保留 Mock、API、数据库、权限、RLS、测试、构建、审查结论和风险。