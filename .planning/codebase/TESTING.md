# Testing Patterns

**Analysis Date:** 2026-10-28

## Test Framework

**Runner:**
- Node.js built-in test runner (`node --test`)
- No Jest/Vitest configuration detected

**Assertion Library:**
- Node built-in `assert` APIs

**Run Commands:**
```bash
npm test                         # build then run all test/*.test.mjs
npm run typecheck                # TypeScript static check
node --test test/cli.test.mjs    # run one suite directly
```

## Test File Organization

**Location:** separate `test/` tree, not beside source files.

**Naming:** subsystem-oriented names such as `control.http.test.mjs`, `ingest.agents.test.mjs` and `demo.test.mjs`.

**Structure:**
```text
test/
  cli.test.mjs
  control.*.test.mjs
  ingest.*.test.mjs
  demo.test.mjs
  *.fakes.mjs
```

## Test Structure

**Suite Organization:** tests use Node `test()` blocks with direct setup, execution and assertions; shared fake modules live in dedicated files.

**Patterns:** temporary directories, fake providers and explicit cleanup are used for filesystem/process-heavy behavior.

## Mocking

**Framework:** hand-written fakes and dependency injection, not a mocking framework.

**What to Mock:** cloud providers, sessions, PTYs, filesystem boundaries and external process behavior.

**What NOT to Mock:** pure parsing/state logic where the real module is deterministic.

## Fixtures and Factories

**Test Data:** reusable fakes are in `test/control.cloud.fakes.mjs` and `test/control.session-fakes.mjs`.

**Location:** fixture helpers stay under `test/` and are imported by related suites.

## Coverage

**Requirements:** no coverage threshold or coverage script was found.

**Configuration:** test command uses a 120-second timeout and forced process exit.

## Test Types

**Unit tests:** parser, state, ingest and helper behavior in focused files.

**Integration tests:** HTTP, WebSocket/SSE, control, service and cloud flows using fakes.

**E2E tests:** no separate browser E2E suite was detected; site behavior is built but not separately automated here.

## Common Patterns

**Async Testing:** async `test()` callbacks await server/session operations and then assert results.

**Error Testing:** invalid inputs and provider failures are asserted directly with Node assertion helpers.

**Adding tests:** update the nearest subsystem suite and run `npm test`; use fakes rather than real cloud credentials.

---

*Testing analysis: 2026-10-28*
*Update when test tooling or organization changes*
