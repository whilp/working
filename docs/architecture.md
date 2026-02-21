# architecture

## loops

- `docs/work.md` — work loop (pick → clone → plan → do → push → check → act)
- `docs/reflect.md` — reflect loop (fetch → analyze → publish)

## tool modules

tool modules are teal (.tl) files in `skills/*/tools/`. each file returns a table:

```
{
  name: string,
  description: string,
  input_schema: { type: "object", properties: {...}, required: {...} },
  execute: function(input: {string: any}): string
}
```

tools are loaded by `ah` via `--tool name=path.tl`. the agent calls them by name during a session.

all tools shell out to `gh` CLI. input validation happens before any subprocess is spawned.

## dependencies

**cosmic** — teal/lua runtime. fetched as a binary in the Makefile. used for: running .tl files, type checking (`--check-types`), formatting (`--format`), test execution (`--test`), test reporting (`--report`).

**ah** — agent harness. fetched as a binary in the Makefile. runs agent sessions with skills, tools, and sandbox constraints.

both are pinned by URL and sha256 in `deps/*.mk` files, included by the Makefile. binaries depend on their `.mk` file — changing it triggers re-fetch.

## ci

`make ci` runs four checks in the github actions workflow:
1. `check-types` — teal type checking on all non-test .tl files
2. `check-format` — formatting check on all non-test .tl files
3. `check-length` — file length lint, fails if any tracked file exceeds its limit
4. `test` — runs all test_*.tl files via `cosmic --test`, reports via `cosmic --report`

## file length ratchet

`lib/build/lint.tl` checks all tracked files against a 500-line default limit. files that need higher limits are listed in the `OVERRIDES` table with explicit line counts. this prevents files from growing unbounded.

- `make check-length` — run the lint check on all git-tracked files
- to tighten the ratchet: shrink a file, then manually lower (or remove) its override in `lib/build/lint.tl`
