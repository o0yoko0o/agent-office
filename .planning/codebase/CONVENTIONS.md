# Coding Conventions

**Analysis Date:** 2026-10-28

## Naming Patterns

**Files:** lowercase descriptive module names, with `index.ts` for subsystem composition.

**Functions:** camelCase; async functions use normal names; constructors/factories are explicit, e.g. `createControlPlane`.

**Variables:** camelCase; constants use upper snake case, e.g. `DEFAULT_PORT` and `SECURITY_HEADERS`.

**Types:** PascalCase interfaces and aliases; interfaces do not use an `I` prefix; `import type` is common.

## Code Style

**Formatting:** TypeScript ESM, semicolons, double-quoted strings in observed source, explicit return/type annotations at boundaries.

**Linting:** no dedicated lint script/config was found in `package.json`; `npm run typecheck` is the available static check.

## Import Organization

**Order:** Node built-ins/types first where practical, then local relative imports; type-only imports are explicit.

**Grouping:** modules generally keep imports at the top and use relative `.ts` specifiers.

**Path Aliases:** no alias scheme was observed; relative paths are used.

## Error Handling

**Patterns:** validate command/API input early; throw descriptive errors; catch at HTTP/CLI boundaries.

**Custom errors:** subsystem-specific classes/types exist, including control errors in `src/control/types.ts`.

**Async:** `async`/`await` is preferred; cleanup and disposal are explicit.

## Logging

**Framework:** Node console/streams and injected logger callbacks rather than a logging dependency.

**Patterns:** log at service/process boundaries; scrub remote/control messages before presenting them.

## Comments

**When to comment:** explain security constraints, lifecycle assumptions and why a platform workaround exists.

**JSDoc/TSDoc:** public interfaces and non-obvious options use inline documentation.

**TODO comments:** no formal TODO tracking convention was established by inspection; preserve existing wording and link an issue when adding one.

## Function Design

**Size:** functions are decomposed by subsystem responsibility; prefer small helpers for parsing, validation and serialization.

**Parameters:** options objects are used for server/control constructors with many settings.

**Return values:** explicit returns and typed promises; disposable resources expose cleanup methods.

## Module Design

**Exports:** named exports and types are preferred; `index.ts` modules assemble public subsystem APIs.

**Barrel files:** use `index.ts` selectively for subsystem composition; keep provider-specific logic in its own module.

---

*Convention analysis: 2026-10-28*
*Update when patterns change*
