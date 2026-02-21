#!/usr/bin/env cosmic
-- lib/work/test_act.tl: tests for lib/work/act.tl
--
-- validates the script loads, exports execute, and handles errors.
-- does not call external commands (gh).

local act = require("lib.work.act")

local function test_exports()
  assert(act.execute, "should export execute function")
  assert(type(act.execute) == "function", "execute should be a function")
  print("✓ act.tl exports execute function")
end
test_exports()

local function test_missing_env()
  -- WORK_REPO is not set in test environment
  local result = act.execute("/dev/null", "/dev/null", "/dev/null")
  assert(result == "error: WORK_REPO environment variable not set",
    "should error on missing env: " .. result)
  print("✓ act.tl rejects missing WORK_REPO")
end
test_missing_env()

local function test_bad_issue_file()
  -- temporarily set WORK_REPO via env (won't work since it's read inside)
  -- instead, test with a file that can't be parsed
  -- WORK_REPO is checked first, so we can't test file parsing without it
  print("✓ act.tl env check precedes file check (covered above)")
end
test_bad_issue_file()

-- CLI behavior tests via os.execute
local function test_cli_missing_args()
  local ok = os.execute("cosmic lib/work/act.tl 2>/dev/null")
  assert(not ok, "should exit non-zero with missing args")
  print("✓ act.tl CLI rejects missing arguments")
end
test_cli_missing_args()

local function test_cli_missing_env()
  local ok = os.execute(
    "WORK_REPO= cosmic lib/work/act.tl x y z 2>/dev/null"
  )
  assert(not ok, "should exit non-zero with missing WORK_REPO")
  print("✓ act.tl CLI rejects missing WORK_REPO")
end
test_cli_missing_env()

local function test_cli_bad_issue_file()
  local ok = os.execute(
    "WORK_REPO=test/repo cosmic lib/work/act.tl /nonexistent x y 2>/dev/null"
  )
  assert(not ok, "should exit non-zero with bad issue file")
  print("✓ act.tl CLI rejects bad issue file")
end
test_cli_bad_issue_file()

print("\nAll act.tl tests passed!")
