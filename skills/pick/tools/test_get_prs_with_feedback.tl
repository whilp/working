#!/usr/bin/env cosmic
-- test_get_prs_with_feedback.tl: tests for get-prs-with-feedback tool

local tool = require("skills.pick.tools.get-prs-with-feedback")

local function test_tool_record()
  assert(tool.name == "get_prs_with_feedback", "name should be get_prs_with_feedback: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  assert(tool.execute, "should have execute function")
  print("✓ get_prs_with_feedback tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ get_prs_with_feedback rejects missing WORK_REPO")
end
test_missing_env()

print("\nAll get_prs_with_feedback tests passed!")
