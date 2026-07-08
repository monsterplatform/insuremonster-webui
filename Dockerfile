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
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
