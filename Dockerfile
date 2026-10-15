# ---------- Builder ----------
FROM node:20-bookworm-slim AS builder
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@9.15.4 --activate

# Private @monster scope resolves to Verdaccio inside the build network (see Jenkinsfile).
ARG NPM_REGISTRY_URL=http://verdaccio:4873
COPY pnpm-lock.yaml* package.json ./
RUN echo "@monster:registry=${NPM_REGISTRY_URL}" > .npmrc \
 && pnpm install --no-frozen-lockfile

COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build

# ---------- Runner ----------
FROM node:20-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3000
# Listen on every interface. Without this, Docker sets HOSTNAME to the container id and Next's
# standalone server binds to whichever IP that name resolves to first. The container sits on
# app-network AND edge-network, so after a restart it could bind edge-network only, and nginx
# (on app-network) fell back to the coming-soon page (DR, 2026-10-15).
ENV HOSTNAME=0.0.0.0
# The commit this image was built from, served by /api/health as `commit` so a deploy is
# verified over HTTPS instead of by root on the box. Jenkins passes `git rev-parse HEAD`.
ARG BUILD_COMMIT=unknown
ENV BUILD_COMMIT=${BUILD_COMMIT}
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
