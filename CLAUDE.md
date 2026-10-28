# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`theagentoffice` (npm package, bins `theagentoffice` / `agentoffice` / `agent-office`, all pointing at `dist/cli.js`). It tails the transcripts coding agents already write (Claude Code, Codex, Command Code, opencode, Cursor, Droid, Qwen Code, Gemini CLI) and renders them as a live pixel-art office at `127.0.0.1:4747`. Agents can run locally, over ssh, or in sandboxes (Daytona, Vercel, Railway, boat). Since 0.2.0 the page can also hire and drive agents (PTY terminal or chat mode with approvals), and agents report back through a bundled MCP server and skill.

## Commands

```bash
npm run build       # node scripts/build.mjs (esbuild) -> dist/
npm run dev         # build, then run the office in --demo mode
npm run typecheck   # tsc --noEmit (covers src/, web/, scripts/ only)
npm test            # build, then node --test on test/*.test.mjs
npm run site        # build the landing page into site/dist (site:dev serves it on 5040-5049)
```

Run a single test file (no build needed, suites bundle the TS sources themselves via esbuild at load time):

```bash
node --test --test-timeout=120000 --test-force-exit test/ingest.redact.test.mjs
node --test --test-timeout=120000 --test-force-exit --test-name-pattern="..." test/<file>.test.mjs
```

Exception: `test/cli.test.mjs` exercises `dist/cli.js` and silently skips when `dist/` is missing.

UI-only dev server with a synthetic office (no transcripts): `node web/ui/dev/dev-server.mjs --scenario cloud` (also `busy`, `empty`, `quiet`, `hostile`).

There is no lint script and no ESLint/Prettier config. CI (`.github/workflows/ci.yml`) runs `npm ci`, `npm run typecheck`, `npm test` on Node 24; `windows.yml` repeats this on Windows and smoke-tests the packed tarball on Node 18/22/24. Published CLI must run on Node >= 18; development needs Node 20+.

Release: bump `version` in `package.json`, commit, push tag `vX.Y.Z`. `release.yml` checks the tag matches and publishes via npm Trusted Publishing. The landing page deploys from `site/dist` to Cloudflare (`wrangler.jsonc`) on pushes to main touching site/web/src/assets.

## Architecture

**Build (`scripts/build.mjs`).** Three esbuild outputs: `src/cli.ts` -> `dist/cli.js` (ESM, node18, `@lydell/node-pty` external); `src/control/term-worker.ts` -> `dist/term-worker.mjs` (worker thread); `web/main.ts` -> `dist/web/assets/app-[hash].js` with lazy chunks (terminal, chat, hire, settings). `web/index.html` must keep the exact placeholder `<script type="module" src="/assets/app.js">` or the build fails. CSS and SVG are imported as text; `.md` files via `with { type: "text" }` (that is how `skills/agent-office/SKILL.md` gets bundled by `src/install/skill.ts`). `assets/` is copied with precompressed `.br`/`.gz`.

**Event pipeline.**
1. `src/ingest/`: one parser per agent (`claude.ts`, `codex.ts`, ...) emitting `RawEvent`s. `discover.ts` holds the drivers, `tail.ts`/`source.ts` the file tailing, `redact.ts`/`categories.ts` the scrubbing and labeling, `signals.ts` reads the MCP outbox, `presence.ts` scans `ps` for running agents. `src/ingest/index.ts` is the largest and most intricate file.
2. `src/server/state.ts` (`OfficeState`) re-redacts every event, synthesizes idle/session_end on timers, assigns `seq`.
3. `src/server/http.ts` serves SSE `/events`, `/api/snapshot`, `/healthz` (HMAC challenge); `static.ts` serves `dist/web`.
4. Browser: `web/main.ts` + `web/ui/` (chrome) and `web/scene/` (Canvas 2D office), joined through `web/contract.ts`.

Shared contracts: `src/shared/events.ts` (`OfficeEvent`, `RawEvent`, `Snapshot`, `BRAND`, `RemoteTarget`) and `src/shared/control.ts` (wire types for `/api/control/**`, used by server and web UI).

**Remote (`src/remote/`).** Each platform is a `RemoteTarget` whose only primitive is `exec(sh script)`. Every host gets its own ingest watcher feeding the same parsers. Discovery every 30 s, a health gate with backoff, and a "dormant" mode so sandboxes can go idle (on Daytona/Railway any exec counts as activity, so polling would keep them awake).

**Control plane (`src/control/`).** Disabled with `--demo`, `--no-control`, a non-loopback `--host`, and on Windows. `types.ts` defines three parts that only talk through those types: sessions (`sessions.ts`, `pty.ts`, `term*.ts`, `chat/*` adapters for claude/codex/opencode/ACP), platform (`index.ts`, `api.ts`, `auth.ts`, `keys.ts`, `link.ts`, `presence.ts`, `service.ts`), and cloud/places (`cloud/*`). A hired agent appears immediately as placeholder worker `ctl:<id>` (spawned process: `proc:<pid>`); `link.ts` later swaps it in place for the transcript-backed worker, by session id or by agent+host+folder heuristic. Unlocking requires the `ao_key` cookie plus `X-Agent-Office: 1` and the page token in `X-Agent-Office-Token` (cookies on 127.0.0.1 leak across ports, hence the token). PTY falls back from node-pty to a python3 bridge to none (`AGENT_OFFICE_PTY`).

**MCP (`src/mcp/`).** Hand-written stdio JSON-RPC server (no SDK) with tools `office_status`, `office_peers`, `office_shout`, `office_celebrate`, `office_flip`. Tools append signals to `~/.agentoffice/outbox/<pid>.jsonl`, which ingest tails. The running office is located via `office.json` (port + secret).

**Install (`src/install/`).** Subcommands `install`, `uninstall`, `doctor`, `mcp`, `open`. `agents.ts` registers the MCP server and skill in each agent's config (JSONC/TOML edits, or `claude mcp add`).

**Other directories.** `src/demo/` is the `--demo` simulator. `site/` is the landing page; it bundles the real `web/scene`, `src/demo` and `src/server/state.ts` for the browser with node builtins stubbed in `site/shims/node.ts`, so changes to those paths affect the site too. `video/` is a separate npm project (playwright-core, macOS only) for launch video and README media.

## Conventions

- ESM throughout; imports use explicit `.ts` extensions (`allowImportingTsExtensions`, `moduleResolution: Bundler`). `test/` is not typechecked; `site/` and `video/` have their own tsconfigs not run in CI.
- Zero runtime dependencies except optional `@lydell/node-pty`. Flag parsing, the WebSocket client (`src/control/ws.ts`), the MCP server and ANSI handling are all hand-rolled. Do not add frameworks or CDNs.
- Many files open with a prose header comment explaining the design; keep it current when changing behavior.
- Tests live flat as `test/<area>.<topic>.test.mjs` using `node:test` + `node:assert/strict`. Fakes in `*.fakes.mjs`, hand-written fixtures in `test/fixtures/<agent>/` (never commit real transcripts). Remote/cloud tests use fake HTTP servers or fake CLIs. Use `test/platform.mjs` (`CONTROL`, `POSIX`, `skipAll`) to skip control-plane or POSIX-shell tests on Windows. Set `AGENT_OFFICE_HOME` to isolate state.
- Windows: system binaries are launched by full System32 path, agent CLIs looked up via PATH (`src/remote/util.ts`, `src/control/cli.ts`); npx installs become `cmd /c npx -y theagentoffice@x.y.z` (`src/install/command.ts`); home is `USERPROFILE`. `.gitattributes` forces LF because SKILL.md and fixtures are read byte for byte.
- Privacy rules are mandatory: labels carry only action + filename, never content; show basenames only, home as `~`, mask IPs, drop token-like strings; secrets never go into argv or logs. Do not remove the redundant redaction layers (`redact.ts`, `state.ts`, `signals.ts`).
- Cloud cost guards: sandboxes default to a 30 min TTL, owned sandboxes are capped, and `sandboxes.json` is written before creation.
- Adding a new agent: driver in `src/ingest/discover.ts`, parser using `common.ts` helpers plus `categories.ts`/`redact.ts`, entry in `BINARIES`/`SCRIPTS` in `presence.ts`, `BRAND` in `src/shared/events.ts`, logo in `assets/logos/<agent>.svg` (using `currentColor`), fixtures, and `src/install/agents.ts` if it supports MCP/skills.
- PRs: keep them focused, fill in the PR template, attach before/after screenshots at desktop and phone width for UI changes.
