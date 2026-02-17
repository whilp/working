# conventions

## language

tool modules are written in teal (.tl), a typed lua dialect. cosmic compiles and runs them.

## tool module pattern

every tool file follows the same structure:

```teal
local child = require("cosmic.child")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
    stderr = 1,
  })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

return {
  name = "tool_name",
  description = "what the tool does",
  input_schema = {
    type = "object",
    properties = { ... },
    required = { ... },
  },
  execute = function(input: {string: any}): string
    -- validate inputs first
    -- call run() to shell out
    -- return result string
  end,
}
```

key patterns:
- `run()` helper wraps `child.spawn` with stderr merging.
- validate all required inputs before spawning any subprocess. return `"error: ..."` strings on failure.
- `execute` always returns a single string. errors are communicated as string prefixed with `"error: "`.
- tools that write temp files use `fs.mkstemp`, then `fs.unlink` after use.

## naming

- tool files use kebab-case: `list-issues.tl`, `create-pr.tl`.
- tool names (in the returned table) use snake_case: `list_issues`, `create_pr`.
- test files use `test_` prefix with snake_case: `test_list_issues.tl`.

## testing

every tool .tl file has a corresponding `test_*.tl` in the same directory.

tests validate:
- **tool record structure** — name, description, input_schema shape, execute function present.
- **input validation** — missing and empty required fields return the correct error string.

tests do not call external commands (no `gh` CLI). they exercise only the validation paths.

test files are plain teal scripts. they use `assert()` and `print("✓ ...")` for reporting. each ends with a summary print.

run all tests: `make test`. run one test:

```bash
TL_PATH='?.tl;?/init.tl;/zip/.lua/?.tl;/zip/.lua/?/init.tl;/zip/.lua/types/?.d.tl;/zip/.lua/types/?/init.d.tl' o/bin/cosmic skills/pick/tools/test_list_issues.tl
```

the Makefile uses `cosmic --test` to run each test and `cosmic --report` to summarize results.

## skills

skill prompts live in `skills/*/SKILL.md`. each has YAML frontmatter (`name`, `description`) and markdown instructions for the agent.

skills define:
- environment assumptions (where files are, what's provided)
- step-by-step instructions
- required output files and their format
- constraints (what's forbidden)

## commits

commit messages are lowercase, imperative. first line is a short summary. body explains why, not what.

## error handling

tool execute functions return error strings, never throw. the pattern is:

```teal
if not value or value == "" then
  return "error: field required"
end
```

subprocess failures include the exit code:

```teal
return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
```
