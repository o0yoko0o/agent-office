# Codebase Structure

**Analysis Date:** 2026-10-28

## Directory Layout

```text
agent-office/
├── src/                 # TypeScript application and server code
│   ├── control/         # Browser control plane, sessions, cloud lifecycle
│   ├── demo/            # Deterministic demo event generation
│   ├── ingest/          # Agent transcript/process discovery and parsing
│   ├── install/         # Agent and service installation helpers
│   ├── mcp/             # MCP clients/server and office files
│   ├── remote/          # Remote provider adapters
│   ├── server/          # HTTP/SSE/static serving and state
│   └── shared/          # Shared event/control types
├── site/                # Browser UI source and assets
├── test/                # Node test-runner suites and fakes
├── scripts/              # esbuild/build orchestration
├── .github/workflows/   # CI, release, site and platform workflows
├── package.json         # Package metadata and commands
└── README.md            # User-facing documentation
```

## Directory Purposes

**`src/`:** primary application source; modules are grouped by runtime responsibility.

**`src/control/`:** authenticated local control, PTYs, installers, services and cloud placement; key file `src/control/index.ts`.

**`src/ingest/`:** per-agent readers and event normalization; key file `src/ingest/index.ts`.

**`src/remote/`:** Vercel, Daytona, Railway, boat and SSH adapters; key file `src/remote/index.ts`.

**`src/server/`:** HTTP server, static assets and event state; key files `src/server/http.ts` and `src/server/state.ts`.

**`site/`:** TypeScript/CSS browser application compiled into the web root.

**`test/`:** separate `.test.mjs` suites, including fake cloud/session providers.

## Key File Locations

**Entry Points:**
- `src/cli.ts` - executable startup and option handling
- `src/server/http.ts` - HTTP/SSE server

**Configuration:**
- `package.json` - scripts, bins, dependencies and Node engine
- `tsconfig.json` - TypeScript settings
- `scripts/build.mjs` - application build

**Core Logic:**
- `src/server/state.ts` - event state
- `src/control/index.ts` - control composition
- `src/ingest/index.ts` - watcher startup
- `src/remote/index.ts` - remote selection and lifecycle

**Testing:**
- `test/*.test.mjs` - unit/integration-style suites
- `test/control.cloud.fakes.mjs` and `test/control.session-fakes.mjs` - test doubles

**Documentation:**
- `README.md` - installation and operational behavior
- `SECURITY.md` - security reporting guidance

## Naming Conventions

**Files:** lowercase descriptive names, mostly `.ts`; tests use `*.test.mjs`.

**Directories:** lowercase responsibility-based names such as `control`, `ingest`, `remote`.

**Special Patterns:** `index.ts` composes or exports subsystem APIs; `types.ts` centralizes subsystem contracts.

## Where to Add New Code

**New feature:** place implementation in the owning `src/<area>/` module and add a matching `test/<area>.*.test.mjs` suite.

**New remote provider:** add provider logic under `src/remote/`, control lifecycle under `src/control/cloud/` when needed, and fake-backed tests.

**New route/command:** extend `src/server/http.ts` or `src/control/api.ts` for routes; extend `src/cli.ts`/`src/control/cli.ts` for CLI behavior.

**Utilities:** keep shared contracts in `src/shared/`; avoid creating broad utility modules without multiple callers.

## Special Directories

**`dist/`:** generated build output; produced by npm scripts and not source of truth.

**`.planning/codebase/`:** generated planning reference documents created by the mapping workflow.

---

*Structure analysis: 2026-10-28*
*Update when directory structure changes*
