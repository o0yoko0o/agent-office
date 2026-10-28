# Codebase Concerns

**Analysis Date:** 2026-10-28

## Tech Debt

**Broad platform surface:**
- Issue: local agents, five remote modes, MCP, service installation and browser control share one executable.
- Impact: provider changes can affect startup, polling and control behavior across many modules.
- Fix approach: preserve provider boundaries and add focused contract tests before cross-cutting refactors.

**Hand-written protocol parsing:**
- Issue: CLI flags, JSON/config formats and remote shell commands are implemented without schema libraries.
- Impact: malformed or new upstream input can fail at runtime.
- Fix approach: keep boundary validation centralized and add regression tests for each format.

## Known Bugs

**Untested boat runtime:**
- Symptoms: README identifies boat support as built from documentation but untested on a real VM.
- Trigger: using `--boat` against a live boat environment.
- Workaround: use documented Vercel, Daytona, Railway or SSH integrations.
- Root cause: provider implementation has no confirmed live-environment coverage.

## Security Considerations

**Browser control surface:**
- Risk: control can start processes and pass credentials, so host/origin/cookie checks are security-critical.
- Current mitigation: loopback gating, Host validation, no CORS, CSP, one-time unlock links and rotating auth state in `src/server/http.ts` and `src/control/auth.ts`.
- Recommendations: preserve these checks in every new route and extend negative tests for origin/Host bypasses.

**Credential handling:**
- Risk: platform and agent keys must not enter logs, command arguments or generated docs.
- Current mitigation: key store and remote handoff code centralize handling in `src/control/keys.ts` and cloud adapters.
- Recommendations: keep secret scans and fake-only tests in CI; never add real values to fixtures.

## Performance Bottlenecks

**Transcript and remote polling:**
- Problem: many local sessions or remote sandboxes increase filesystem and provider polling work.
- Measurement: no benchmark data was found in the repository.
- Cause: watcher/polling model in `src/ingest/` and `src/remote/`.
- Improvement path: measure first, then tune backoff, batching and subscription lifetimes.

## Fragile Areas

**HTTP/control integration:**
- Why fragile: `src/server/http.ts` dispatches static, SSE, health, unlock and control routes with security-sensitive ordering.
- Common failures: route ordering, auth state changes and event-client cleanup regressions.
- Safe modification: extend `test/control.http.test.mjs` and keep control disabled in demo/non-loopback modes.
- Test coverage: HTTP/control suites exist; browser-level coverage is not evident.

**Remote adapters:**
- Why fragile: provider APIs and CLI output are external and can change independently.
- Common failures: expired logins, missing binaries, remote shell differences and stale sessions.
- Safe modification: update provider fake tests and document live-runtime status.
- Test coverage: provider-focused suites exist, but live boat coverage is missing.

## Scaling Limits

**Single local process/event stream:**
- Current capacity: intended for a user's local agent set; no explicit capacity target found.
- Limit: memory, SSE backlog and provider polling increase with sessions/remotes.
- Symptoms at limit: dropped slow clients or delayed updates.
- Scaling path: measure, bound subscriptions and separate remote polling if real usage requires it.

## Dependencies at Risk

**Optional `@lydell/node-pty`:**
- Risk: beta-version optional dependency and platform-specific native behavior.
- Impact: local interactive control may be unavailable or differ by OS.
- Migration plan: keep the injected PTY boundary and provide a tested fallback/upgrade path before changing versions.

## Test Coverage Gaps

**Live integrations and browser flows:**
- What's not tested: real provider sessions, boat runtime and full browser control journeys.
- Risk: external API or UI regressions can pass local fake-backed tests.
- Priority: Medium.
- Difficulty to test: requires credentials, live sandboxes and platform-specific environments.

---

*Concerns audit: 2026-10-28*
*Update as issues are fixed or new ones discovered*
