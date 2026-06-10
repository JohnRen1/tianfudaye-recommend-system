# 腾讯云 Docker 部署记录（拓客系统-落地页）

## 1. 项目基本信息

- 项目目录：`拓客系统-落地页`
- 技术栈：Next.js + React + pnpm
- 包管理器：pnpm
- pnpm 版本：`11.5.0`
- Node Docker 镜像：`node:24-alpine`
- 部署方式：`Dockerfile + pnpm-lock.yaml + 腾讯云镜像仓库 / 腾讯云服务器`
- 应用端口：`3000`

核心部署文件：

```text
拓客系统-落地页/
├── Dockerfile
├── package.json
├── pnpm-lock.yaml
├── pnpm-workspace.yaml
├── next.config.mjs
└── .dockerignore
```

---

## 2. Dockerfile 部署方式说明

本项目使用多阶段 Docker 构建：

1. `builder` 阶段：安装 pnpm 依赖并执行 `pnpm build`
2. `runner` 阶段：只复制 Next.js standalone 运行产物
3. 最终通过 `node server.js` 启动服务

当前 Dockerfile 核心逻辑：

```dockerfile
FROM node:24-alpine AS builder

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@11.5.0 --activate

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

RUN pnpm install --frozen-lockfile --ignore-scripts
RUN pnpm rebuild sharp 2>/dev/null || true

COPY . .

RUN pnpm build

FROM node:24-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
```

---

## 3. pnpm-lock 部署要点

本项目使用 `pnpm-lock.yaml` 固定依赖版本。

Dockerfile 中使用：

```bash
pnpm install --frozen-lockfile --ignore-scripts
```

说明：

- `--frozen-lockfile`：严格按照 `pnpm-lock.yaml` 安装依赖，保证腾讯云构建环境和本地依赖一致。
- `--ignore-scripts`：避免 pnpm 11 在 Docker 构建中因为 `sharp` 构建脚本报错。
- `pnpm rebuild sharp 2>/dev/null || true`：尝试重建 sharp，但失败不阻塞构建。

---

## 4. package.json 要求

`package.json` 中需要保留：

```json
{
  "packageManager": "pnpm@11.5.0"
}
```

这样 Docker 构建时执行：

```bash
corepack prepare pnpm@11.5.0 --activate
```

可以和项目 pnpm 版本保持一致。

---

## 5. pnpm-workspace.yaml 配置

当前项目的 `pnpm-workspace.yaml`：

```yaml
packages:
  - "."

onlyBuiltDependencies:
  - sharp
```

注意：pnpm 11 不再读取 `package.json` 中的 `pnpm.onlyBuiltDependencies`，所以 `onlyBuiltDependencies` 应该放在 `pnpm-workspace.yaml` 中。

---

## 6. next.config.mjs 配置要求

因为 Dockerfile 使用 `.next/standalone` 作为运行产物，所以 `next.config.mjs` 必须开启：

```js
output: 'standalone'
```

推荐配置：

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
}

export default nextConfig
```

说明：

- `output: 'standalone'`：生成 `.next/standalone`，供 Docker runner 阶段复制。
- `images.unoptimized: true`：关闭 Next 图片优化，避免生产环境强依赖 `sharp`。
- `typescript.ignoreBuildErrors: true`：原型阶段避免类型错误阻塞构建。

---

## 7. .dockerignore 配置

当前 `.dockerignore`：

```text
node_modules
.next
.git
.env.local
.DS_Store
npm-debug.log
pnpm-debug.log
yarn-error.log
```

作用：

- 不上传本地 `node_modules`
- 不上传本地 `.next`
- 减少 Docker 构建上下文体积
- 避免本地构建产物污染腾讯云构建环境

---

## 8. 本地 Docker 构建

进入项目目录：

```bash
cd "拓客系统-落地页"
```

构建镜像：

```bash
docker build -t tax-landing:latest .
```

运行容器：

```bash
docker run -d \
  --name tax-landing \
  -p 3000:3000 \
  tax-landing:latest
```

访问：

```text
http://localhost:3000
```

查看日志：

```bash
docker logs -f tax-landing
```

停止并删除容器：

```bash
docker stop tax-landing
docker rm tax-landing
```

---

## 9. 推送到腾讯云容器镜像服务

### 9.1 登录腾讯云镜像仓库

腾讯云个人版 CCR 示例：

```bash
docker login ccr.ccs.tencentyun.com
```

如果使用 TCR 企业版，地址通常类似：

```bash
docker login xxx.tencentcloudcr.com
```

### 9.2 构建腾讯云镜像

示例镜像地址：

```text
ccr.ccs.tencentyun.com/命名空间/tax-landing:latest
```

构建：

```bash
docker build -t ccr.ccs.tencentyun.com/命名空间/tax-landing:latest .
```

### 9.3 推送镜像

```bash
docker push ccr.ccs.tencentyun.com/命名空间/tax-landing:latest
```

---

## 10. 腾讯云服务器运行容器

在腾讯云 CVM / 轻量应用服务器上执行：

```bash
docker pull ccr.ccs.tencentyun.com/命名空间/tax-landing:latest
```

运行容器：

```bash
docker run -d \
  --name tax-landing \
  --restart always \
  -p 3000:3000 \
  ccr.ccs.tencentyun.com/命名空间/tax-landing:latest
```

查看运行状态：

```bash
docker ps
```

查看日志：

```bash
docker logs -f tax-landing
```

浏览器访问：

```text
http://服务器公网IP:3000
```

---

## 11. 腾讯云自动构建配置

如果腾讯云从 Git 仓库自动构建，需要注意当前项目位于子目录：

```text
拓客系统-落地页
```

推荐配置：

```text
构建目录：拓客系统-落地页
Dockerfile 路径：拓客系统-落地页/Dockerfile
```

如果腾讯云支持自定义构建命令，也可以使用：

```bash
docker build -f 拓客系统-落地页/Dockerfile -t 镜像地址:tag 拓客系统-落地页
```

---

## 12. 使用 Nginx 绑定域名

如果需要通过域名访问，可以使用 Nginx 反向代理到容器的 `3000` 端口。

安装 Nginx：

```bash
apt update
apt install nginx -y
```

Nginx 配置示例：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

检查配置：

```bash
nginx -t
```

重载 Nginx：

```bash
systemctl reload nginx
```

---

## 13. 配置 HTTPS

安装 Certbot：

```bash
apt install certbot python3-certbot-nginx -y
```

申请证书：

```bash
certbot --nginx -d your-domain.com
```

测试自动续期：

```bash
certbot renew --dry-run
```

---

## 14. 常见问题记录

### 14.1 pnpm sharp 构建脚本错误

错误示例：

```text
ERR_PNPM_IGNORED_BUILDS: Ignored build scripts: sharp
```

原因：

- pnpm 11 默认拦截部分依赖构建脚本
- `sharp` 有 postinstall/build 脚本
- Docker / CI 环境无法交互执行 `pnpm approve-builds`

解决方案：

Dockerfile 中使用：

```dockerfile
RUN pnpm install --frozen-lockfile --ignore-scripts
RUN pnpm rebuild sharp 2>/dev/null || true
```

并且 `next.config.mjs` 中配置：

```js
images: {
  unoptimized: true,
}
```

### 14.2 `.next/standalone` 不存在

错误示例：

```text
COPY --from=builder /app/.next/standalone ./ not found
```

原因：`next.config.mjs` 没有开启 standalone 输出。

解决方案：

```js
const nextConfig = {
  output: 'standalone',
}
```

### 14.3 `server.js` 不存在

错误示例：

```text
Cannot find module '/app/server.js'
```

原因：`.next/standalone` 没有生成或没有正确复制。

检查项：

- `next.config.mjs` 是否配置 `output: 'standalone'`
- `pnpm build` 是否成功
- Dockerfile 是否复制了 `/app/.next/standalone`

### 14.4 页面 prerender 失败

错误示例：

```text
Error occurred prerendering page "/risk-assessment/report"
```

原因：页面中使用了：

```tsx
useSearchParams()
```

Next.js App Router 在构建预渲染时要求这类组件被 `Suspense` 包裹。

解决方案：

```tsx
import { Suspense } from "react";
import { useSearchParams } from "next/navigation";

function RiskReportContent() {
  const searchParams = useSearchParams();
  return <div>...</div>;
}

export default function Page() {
  return (
    <Suspense fallback={<div>正在加载...</div>}>
      <RiskReportContent />
    </Suspense>
  );
}
```

---

## 15. 推荐发布流程

### 15.1 首次发布

```bash
cd "拓客系统-落地页"

docker build -t ccr.ccs.tencentyun.com/命名空间/tax-landing:latest .

docker push ccr.ccs.tencentyun.com/命名空间/tax-landing:latest
```

服务器执行：

```bash
docker pull ccr.ccs.tencentyun.com/命名空间/tax-landing:latest

docker run -d \
  --name tax-landing \
  --restart always \
  -p 3000:3000 \
  ccr.ccs.tencentyun.com/命名空间/tax-landing:latest
```

### 15.2 后续更新

本地提交代码：

```bash
git add .
git commit -m "update landing page"
git push
```

如果腾讯云配置了自动构建，推送后会自动重新构建镜像。

如果是手动部署：

```bash
docker build -t ccr.ccs.tencentyun.com/命名空间/tax-landing:latest .
docker push ccr.ccs.tencentyun.com/命名空间/tax-landing:latest
```

服务器更新容器：

```bash
docker pull ccr.ccs.tencentyun.com/命名空间/tax-landing:latest

docker stop tax-landing
docker rm tax-landing

docker run -d \
  --name tax-landing \
  --restart always \
  -p 3000:3000 \
  ccr.ccs.tencentyun.com/命名空间/tax-landing:latest
```

---

## 16. 上线检查清单

- [ ] `Dockerfile` 已提交
- [ ] `pnpm-lock.yaml` 已提交
- [ ] `pnpm-workspace.yaml` 已提交
- [ ] `next.config.mjs` 已配置 `output: 'standalone'`
- [ ] `.dockerignore` 已排除 `node_modules` 和 `.next`
- [ ] 腾讯云构建目录指向 `拓客系统-落地页`
- [ ] 镜像构建成功
- [ ] 容器端口 `3000` 正常监听
- [ ] 腾讯云安全组已开放对应端口
- [ ] 如使用域名，Nginx 反向代理配置正确
- [ ] 如使用 HTTPS，SSL 证书配置正确
