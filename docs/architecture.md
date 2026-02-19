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
3. `check-length` — file length ratchet, fails if any .tl file exceeds its baseline in `.ratchet`
4. `test` — runs all test_*.tl files via `cosmic --test`, reports via `cosmic --report`

## file length ratchet

`.ratchet` records `path max_lines` for each .tl file. `check-length` fails CI if any file exceeds its baseline. this prevents files from growing unbounded.

- `make check-length` — run the ratchet check
- `make ratchet` — regenerate `.ratchet` from current file lengths (run after shrinking files)
