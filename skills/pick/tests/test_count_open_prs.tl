#!/usr/bin/env cosmic
-- test_count_open_prs.tl: tests for count-open-prs tool

local tool = require("skills.pick.tools.count-open-prs")

local function test_tool_record()
  assert(tool.name == "count_open_prs", "name should be count_open_prs: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  assert(tool.execute, "should have execute function")
  print("✓ count_open_prs tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ count_open_prs rejects missing WORK_REPO")
end
test_missing_env()

print("\nAll count_open_prs tests passed!")
