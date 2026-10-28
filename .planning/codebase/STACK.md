# Technology Stack

**Analysis Date:** 2026-10-28

## Languages

**Primary:**
- TypeScript - application, server, control plane, ingest and MCP code in `src/`

**Secondary:**
- JavaScript/ESM - build scripts in `scripts/` and tests in `test/`
- HTML/CSS - browser site in `site/`

## Runtime

**Environment:**
- Node.js >=18, declared in `package.json`
- Browser runtime for the bundled office UI

**Package Manager:**
- npm; `package-lock.json` is committed

## Frameworks

**Core:**
- No application framework; Node built-ins provide HTTP, filesystem, process and crypto primitives

**Testing:**
- Node built-in test runner via `node --test`

**Build/Dev:**
- TypeScript 7 compiler for type checking
- esbuild for bundling in `scripts/build.mjs`

## Key Dependencies

**Critical:**
- `@xterm/xterm` - browser terminal rendering
- `@xterm/headless` - terminal processing for control/session flows
- `@xterm/addon-fit` and `@xterm/addon-serialize` - terminal sizing and serialization
- `@lydell/node-pty` - optional local pseudo-terminal backend

**Infrastructure:**
- `esbuild` - application and site build output
- Node.js built-ins - HTTP, SSE, filesystem, child processes and cryptography

## Configuration

**Environment:**
- CLI flags and `~/.agentoffice/` files configure operation; remote integrations use platform-specific environment tokens
- `package.json` defines commands, package metadata and executable aliases

**Build:**
- `tsconfig.json` controls strict TypeScript compilation
- `scripts/build.mjs` and `scripts/build-site.mjs` create `dist/` artifacts

## Platform Requirements

**Development:**
- Node.js 18 or newer and npm
- Local agent transcript locations and optional platform CLIs/logins

**Production:**
- Distributed as the npm package `theagentoffice`
- Supports local use and configured Vercel, Daytona, Railway, boat and SSH targets

---

*Stack analysis: 2026-10-28*
*Update after major dependency changes*
