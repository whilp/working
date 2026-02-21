#!/usr/bin/env cosmic
-- test_list_issues.tl: tests for list-issues tool

local tool = require("skills.pick.tools.list-issues")

local function test_tool_record()
  assert(tool.name == "list_issues", "name should be list_issues: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  assert(tool.execute, "should have execute function")
  print("✓ list_issues tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ list_issues rejects missing WORK_REPO")
end
test_missing_env()

print("\nAll list_issues tests passed!")
