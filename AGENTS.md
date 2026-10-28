# AGENTS.md

Canonical project context for all coding agents (Claude Code, OpenCode, Codex, ...). `CLAUDE.md` imports this file and only adds Claude-specific notes. Keep shared rules here, not in `CLAUDE.md`.

## Fork

This repository is a personal fork of [bas3line/agent-office](https://github.com/bas3line/agent-office), maintained at [o0yoko0o/agent-office](https://github.com/o0yoko0o/agent-office) (`origin`). It is developed for fun and heads in a personal direction, so features here may diverge from upstream and are not meant to be upstreamed by default.

- Upstream: `https://github.com/bas3line/agent-office` (the original author is credited in `README.md` and the MIT license; keep that attribution).
- To pull upstream changes, add the remote once (`git remote add upstream https://github.com/bas3line/agent-office.git`), then `git fetch upstream` and merge or rebase `upstream/main`.
- Release, npm publishing (`release.yml`) and the Cloudflare site deploy are set up for the upstream package `theagentoffice`. Do not tag releases or publish from this fork unless that is explicitly decided.

## What this is

`theagentoffice` (npm package, bins `theagentoffice` / `agentoffice` / `agent-office`, all pointing at `dist/cli.js`). It tails the transcripts coding agents already write (Claude Code, Codex, Command Code, opencode, Cursor, Droid, Qwen Code, Gemini CLI) and renders them as a live pixel-art office at `127.0.0.1:4747`. Agents can run locally, over ssh, or in sandboxes (Daytona, Vercel, Railway, boat). Since 0.2.0 the page can also hire and drive agents (PTY terminal or chat mode with approvals), and agents report back through a bundled MCP server and skill.

## Commands

Use Node 20+ and `npm ci`. CI runs Node 24; the published CLI must run on Node >= 18.

```bash
npm run build       # node scripts/build.mjs (esbuild) -> dist/
npm run dev         # build, then run the office in --demo mode
npm run typecheck   # tsc --noEmit (covers src/, web/, scripts/ only)
npm test            # build, then node --test on test/*.test.mjs
npm run site        # build the landing page into site/dist (site:dev serves it on 5040-5049)
```

Verify with `npm run typecheck`, then `npm test`.

Run a single test file (no build needed, suites bundle the TS sources themselves via esbuild at load time):

```bash
node --test --test-timeout=120000 --test-force-exit test/ingest.redact.test.mjs
node --test --test-timeout=120000 --test-force-exit --test-name-pattern="..." test/<file>.test.mjs
```

Exception: `test/cli.test.mjs` exercises `dist/cli.js` and silently skips when `dist/` is missing, so run `npm run build` first.

UI-only dev server with a synthetic office (no transcripts): `node web/ui/dev/dev-server.mjs --scenario cloud` (also `busy`, `empty`, `quiet`, `hostile`).

There is no lint script, formatter, codegen, or ESLint/Prettier config. CI (`.github/workflows/ci.yml`) runs `npm ci`, `npm run typecheck`, `npm test` on Node 24; `windows.yml` repeats this on Windows and smoke-tests the packed tarball on Node 18/22/24.

Release (upstream flow): bump `version` in `package.json`, commit, push tag `vX.Y.Z`. `release.yml` checks the tag matches and publishes via npm Trusted Publishing. The landing page deploys from `site/dist` to Cloudflare (`wrangler.jsonc`) on pushes to main touching site/web/src/assets. See the Fork section before using either.

## Architecture

**Build (`scripts/build.mjs`).** Three esbuild outputs: `src/cli.ts` -> `dist/cli.js` (ESM, node18, `@lydell/node-pty` external); `src/control/term-worker.ts` -> `dist/term-worker.mjs` (worker thread); `web/main.ts` -> `dist/web/assets/app-[hash].js` with lazy chunks (terminal, chat, hire, settings). `web/index.html` must keep the exact placeholder `<script type="module" src="/assets/app.js">` or the build fails. CSS and SVG are imported as text; `.md` files via `with { type: "text" }` (that is how `skills/agent-office/SKILL.md` gets bundled by `src/install/skill.ts`). `assets/` is copied with precompressed `.br`/`.gz`.

**Event pipeline.**
1. `src/ingest/`: one parser per agent (`claude.ts`, `codex.ts`, ...) emitting `RawEvent`s. `discover.ts` holds the drivers, `tail.ts`/`source.ts` the file tailing, `redact.ts`/`categories.ts` the scrubbing and labeling, `signals.ts` reads the MCP outbox, `presence.ts` scans `ps` for running agents. `src/ingest/index.ts` is the largest and most intricate file.
2. `src/server/state.ts` (`OfficeState`) re-redacts every event, synthesizes idle/session_end on timers, assigns `seq`.
3. `src/server/http.ts` serves SSE `/events`, `/api/snapshot`, `/healthz` (HMAC challenge); `static.ts` serves `dist/web`.
4. Browser: `web/main.ts` + `web/ui/` (chrome) and `web/scene/` (Canvas 2D office), joined through `web/contract.ts`.

Shared contracts: `src/shared/events.ts` (`OfficeEvent`, `RawEvent`, `Snapshot`, `BRAND`, `RemoteTarget`) and `src/shared/control.ts` (wire types for `/api/control/**`, used by server and web UI). Keep the wire contract there; put parsers in `src/ingest`, remote providers in `src/remote`, server state and HTTP in `src/server`, controls in `src/control`, and browser code in `web`.

**Remote (`src/remote/`).** Each platform is a `RemoteTarget` whose only primitive is `exec(sh script)`. Every host gets its own ingest watcher feeding the same parsers. Discovery every 30 s, a health gate with backoff, and a "dormant" mode so sandboxes can go idle (on Daytona/Railway any exec counts as activity, so polling would keep them awake).

**Control plane (`src/control/`).** Disabled with `--demo`, `--no-control`, a non-loopback `--host`, and on Windows. `types.ts` defines three parts that only talk through those types: sessions (`sessions.ts`, `pty.ts`, `term*.ts`, `chat/*` adapters for claude/codex/opencode/ACP), platform (`index.ts`, `api.ts`, `auth.ts`, `keys.ts`, `link.ts`, `presence.ts`, `service.ts`), and cloud/places (`cloud/*`). A hired agent appears immediately as placeholder worker `ctl:<id>` (spawned process: `proc:<pid>`); `link.ts` later swaps it in place for the transcript-backed worker, by session id or by agent+host+folder heuristic. Unlocking requires the `ao_key` cookie plus `X-Agent-Office: 1` and the page token in `X-Agent-Office-Token` (cookies on 127.0.0.1 leak across ports, hence the token). PTY falls back from node-pty to a python3 bridge to none (`AGENT_OFFICE_PTY`).

**MCP (`src/mcp/`).** Hand-written stdio JSON-RPC server (no SDK) with tools `office_status`, `office_peers`, `office_shout`, `office_celebrate`, `office_flip`. Tools append signals to `~/.agentoffice/outbox/<pid>.jsonl`, which ingest tails. The running office is located via `office.json` (port + secret).

**Install (`src/install/`).** Subcommands `install`, `uninstall`, `doctor`, `mcp`, `open`. `agents.ts` registers the MCP server and skill in each agent's config (JSONC/TOML edits, or `claude mcp add`).

**Other directories.** `src/demo/` is the `--demo` simulator. `site/` is the landing page; it bundles the real `web/scene`, `src/demo` and `src/server/state.ts` for the browser with node builtins stubbed in `site/shims/node.ts`, so changes to those paths affect the site too. `video/` is a separate npm project (own `package-lock`, playwright-core, macOS only) for launch video and README media.

## Conventions

- ESM throughout; imports use explicit `.ts` extensions (`allowImportingTsExtensions`, `moduleResolution: Bundler`). `test/` is not typechecked; `site/` and `video/` have their own tsconfigs not run in CI.
- Zero runtime dependencies except optional `@lydell/node-pty`. Flag parsing, the WebSocket client (`src/control/ws.ts`), the MCP server and ANSI handling are all hand-rolled. Do not add frameworks or CDNs.
- Many files open with a prose header comment explaining the design; keep it current when changing behavior.
- Generated output: `npm run build` replaces `dist/`, `npm run site` replaces `site/dist/`. Do not edit generated files.
- Tests live flat as `test/<area>.<topic>.test.mjs` using `node:test` + `node:assert/strict`. Fakes in `*.fakes.mjs`, hand-written fixtures in `test/fixtures/<agent>/` (never commit real transcripts, use synthetic fixtures). Remote/cloud tests use fake HTTP servers or fake CLIs. Use `test/platform.mjs` (`CONTROL`, `POSIX`, `skipAll`) to skip control-plane or POSIX-shell tests on Windows. Set `AGENT_OFFICE_HOME` to isolate state.
- Windows: system binaries are launched by full System32 path, agent CLIs looked up via PATH (`src/remote/util.ts`, `src/control/cli.ts`); npx installs become `cmd /c npx -y theagentoffice@x.y.z` (`src/install/command.ts`); home is `USERPROFILE`. `.gitattributes` forces LF because SKILL.md, skill frontmatter and fixtures are read byte for byte. Preserve LF line endings.
- Privacy rules are mandatory: labels carry only action + basename, never prompts, contents, command arguments, credentials, full paths or IPs; home as `~`, mask IPs, drop token-like strings; secrets never go into argv or logs. Do not remove the redundant redaction layers (`redact.ts`, `state.ts`, `signals.ts`).
- Cloud cost guards: sandboxes default to a 30 min TTL, owned sandboxes are capped, and `sandboxes.json` is written before creation.
- Adding a new agent: driver in `src/ingest/discover.ts`, parser using `common.ts` helpers plus `categories.ts`/`redact.ts`, entry in `BINARIES`/`SCRIPTS` in `presence.ts`, `BRAND` in `src/shared/events.ts`, logo in `assets/logos/<agent>.svg` (using `currentColor`), fixtures, and `src/install/agents.ts` if it supports MCP/skills.
- PRs: keep them focused, fill in the PR template, attach before/after screenshots at desktop and phone width for UI changes.

## Planning & Documentation

- `.planning/codebase/`: codebase map (`ARCHITECTURE.md`, `CONCERNS.md`, `CONVENTIONS.md`, `INTEGRATIONS.md`, `STACK.md`, `STRUCTURE.md`, `TESTING.md`). Read the relevant file before larger changes and update it when the described structure changes.
- `.planning/`: further GSD planning artifacts (project, roadmap, phases) go here as the fork evolves.
- `README.md` and `CONTRIBUTING.md`: upstream user and contributor docs.
- `CLAUDE.md`: imports this file and adds Claude Code specifics only.
