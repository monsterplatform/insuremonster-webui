# insuremonster-webui

Next.js (App Router) front-end for **Insuremonster** (`insuremonster.com`).

Scaffolded as a buildable coming-soon placeholder so the brand's dev/test deploy pipeline
(Jenkins `*-webui` job → Docker → nginx vhost) works end-to-end. Replace `app/page.tsx` with the
real UI as it's built; when it starts calling the backend, add `transpilePackages: ['@monster/nextapi']`
to `next.config.mjs` and depend on `@monster/nextapi` (Verdaccio).

## Local
```bash
pnpm install
pnpm dev      # http://localhost:3000
pnpm build && pnpm start
```

## Build/deploy
`Dockerfile` (Next standalone) + `Jenkinsfile` follow the monster-platform webui convention
(env-file driven, `app-network`+`edge-network`, port 3000). The Jenkins job passes
`ENV_FILE_CUSTOM=/app/environments/<stage>.insuremonster.com.env`.
