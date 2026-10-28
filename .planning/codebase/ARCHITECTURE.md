# Architecture

**Analysis Date:** 2026-10-28

## Pattern Overview

**Overall:** Local-first event-driven CLI with an HTTP/SSE visualizer and optional control plane.

**Key Characteristics:**
- Single Node.js executable with hand-parsed CLI flags and subcommands
- In-memory office state fed by transcript/process watchers
- Browser view receives snapshots and events over Server-Sent Events
- Optional authenticated control plane starts agents and manages remote places

## Layers

**CLI/orchestration:**
- Purpose: parse flags, choose demo/ingest/remotes and start services
- Contains: `src/cli.ts`, `src/control/cli.ts`, `src/install/`
- Depends on: all runtime subsystems; used by the executable

**Ingest and domain state:**
- Purpose: translate agent transcripts/signals into office events
- Contains: `src/ingest/`, `src/demo/`, `src/server/state.ts`, `src/shared/`
- Depends on: filesystem/process sources; used by server and control consumers

**HTTP presentation:**
- Purpose: serve static UI, snapshots and event streams
- Contains: `src/server/http.ts`, `src/server/static.ts`
- Depends on: `OfficeState` and optional `ControlPlane`

**Control and remote execution:**
- Purpose: authenticate browser controls, manage sessions, PTYs, installers and cloud targets
- Contains: `src/control/`, `src/remote/`, `src/mcp/`
- Depends on: Node process/filesystem APIs and remote provider CLIs/APIs

## Data Flow

**Office startup:**
1. `src/cli.ts` parses arguments and initializes `OfficeState`.
2. `src/ingest/index.ts` watches local agent sources; optional demo and remote watchers start.
3. `src/server/http.ts` serves the built UI and `/api/snapshot`.
4. Browser connects to `/events` and receives snapshot, office events and pings.
5. If enabled, `src/control/index.ts` mounts authenticated control routes and frames.

**State Management:**
- Runtime state is in memory and broadcast through subscriptions.
- Durable user configuration and runtime secrets live below `~/.agentoffice/`.

## Key Abstractions

**OfficeState:**
- Purpose: central snapshot/event store
- Examples: `src/server/state.ts`, `src/shared/events.ts`
- Pattern: subscription/event emitter

**ControlPlane:**
- Purpose: boundary for browser-driven hiring and session operations
- Examples: `src/control/types.ts`, `src/control/index.ts`
- Pattern: composed services behind a route dispatcher

**Remote target adapters:**
- Purpose: normalize platform-specific sandbox operations
- Examples: `src/remote/vercel.ts`, `src/remote/daytona.ts`, `src/remote/railway.ts`, `src/remote/ssh.ts`
- Pattern: provider factories and shared source/util interfaces

## Entry Points

**CLI entry:** `src/cli.ts`, invoked by `dist/cli.js` through the package bin aliases.

**HTTP entry:** `startServer` in `src/server/http.ts`, started by the CLI.

**MCP entry:** modules under `src/mcp/`, used for office integration and hooks.

## Error Handling

**Strategy:** validate at CLI/API boundaries, throw typed or descriptive errors, catch at process/request boundaries.

**Patterns:**
- HTTP handler converts unexpected failures to a 500 response.
- Remote failures are scrubbed before user-facing control frames.
- Tests use explicit fake providers and fixtures for failure paths.

## Cross-Cutting Concerns

**Logging:** injected callbacks, service loggers and console/stderr output.

**Validation:** hand-written CLI/API parsing at trust boundaries.

**Authentication:** loopback/Host/origin checks plus one-time unlock cookies and page tokens.

---

*Architecture analysis: 2026-10-28*
*Update when major patterns change*
