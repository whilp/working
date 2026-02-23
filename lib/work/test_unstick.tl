#!/usr/bin/env cosmic
-- lib/work/test_unstick.tl: tests for lib/work/unstick.tl
--
-- validates exports, input validation, and helper functions.
-- does not call external commands (gh).

local unstick = require("lib.work.unstick")

local function test_exports()
  assert(unstick.execute, "should export execute function")
  assert(type(unstick.execute) == "function", "execute should be a function")
  assert(unstick.parse_iso8601, "should export parse_iso8601 function")
  assert(type(unstick.parse_iso8601) == "function", "parse_iso8601 should be a function")
  assert(unstick.find_doing_labeled_at, "should export find_doing_labeled_at function")
  assert(type(unstick.find_doing_labeled_at) == "function", "find_doing_labeled_at should be a function")
  assert(unstick.STALE_HOURS == 24, "STALE_HOURS should be 24")
  print("✓ unstick.tl exports expected functions and constants")
end
test_exports()

local function test_missing_env()
  -- WORK_REPO is cleared by the test runner
  local result = unstick.execute("/dev/null")
  assert(result == "error: WORK_REPO environment variable not set",
    "should error on missing env: " .. result)
  print("✓ unstick.tl rejects missing WORK_REPO")
end
test_missing_env()

local function test_parse_iso8601()
  local epoch = unstick.parse_iso8601("2025-01-01T00:00:00Z")
  assert(epoch > 0, "should parse valid ISO 8601 timestamp")
  -- 2025-01-01 00:00:00 UTC = 1735689600
  assert(epoch == 1735689600, "expected 1735689600, got " .. tostring(epoch))
  print("✓ parse_iso8601 parses valid timestamp")
end
test_parse_iso8601()

local function test_parse_iso8601_invalid()
  local epoch = unstick.parse_iso8601("not-a-date")
  assert(epoch == 0, "should return 0 for invalid timestamp")
  print("✓ parse_iso8601 returns 0 for invalid input")
end
test_parse_iso8601_invalid()

local function test_find_doing_labeled_at()
  -- simulate a node with doing label events
  local node = {
    timelineItems = {
      nodes = {
        {createdAt = "2025-01-01T10:00:00Z", label = {name = "doing"}},
        {createdAt = "2025-01-02T10:00:00Z", label = {name = "doing"}},
        {createdAt = "2025-01-01T15:00:00Z", label = {name = "todo"}},
      },
    },
  }
  local result = unstick.find_doing_labeled_at(node as {string: any})
  assert(result == "2025-01-02T10:00:00Z",
    "should return latest doing event: " .. result)
  print("✓ find_doing_labeled_at returns latest doing event")
end
test_find_doing_labeled_at()

local function test_find_doing_labeled_at_none()
  local node = {
    timelineItems = {
      nodes = {
        {createdAt = "2025-01-01T10:00:00Z", label = {name = "todo"}},
      },
    },
  }
  local result = unstick.find_doing_labeled_at(node as {string: any})
  assert(result == "", "should return empty string when no doing events")
  print("✓ find_doing_labeled_at returns empty for no doing events")
end
test_find_doing_labeled_at_none()

local function test_find_doing_labeled_at_empty()
  local node = {
    timelineItems = {
      nodes = {},
    },
  }
  local result = unstick.find_doing_labeled_at(node as {string: any})
  assert(result == "", "should return empty string for empty timeline")
  print("✓ find_doing_labeled_at returns empty for empty timeline")
end
test_find_doing_labeled_at_empty()

local function test_cli_missing_args()
  local ok = os.execute("cosmic lib/work/unstick.tl 2>/dev/null")
  assert(not ok, "should exit non-zero with missing args")
  print("✓ unstick.tl CLI rejects missing arguments")
end
test_cli_missing_args()

local function test_cli_missing_env()
  local ok = os.execute(
    "WORK_REPO= cosmic lib/work/unstick.tl /tmp/test_out 2>/dev/null"
  )
  assert(not ok, "should exit non-zero with missing WORK_REPO")
  print("✓ unstick.tl CLI rejects missing WORK_REPO")
end
test_cli_missing_env()

print("\nAll unstick.tl tests passed!")
