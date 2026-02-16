#!/usr/bin/env cosmic
-- test_get_prs_with_feedback.tl: tests for get-prs-with-feedback tool

local tool = require("skills.pick.tools.get-prs-with-feedback")

local function test_tool_record()
  assert(tool.name == "get_prs_with_feedback", "name should be get_prs_with_feedback: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.repo, "should have repo property")
  local req = schema.required as {string}
  assert(req[1] == "repo", "repo should be required")
  assert(tool.execute, "should have execute function")
  print("✓ get_prs_with_feedback tool record is valid")
end
test_tool_record()

local function test_missing_repo()
  local result = tool.execute({})
  assert(result == "error: repo argument required", "should error on missing repo: " .. result)
  print("✓ get_prs_with_feedback rejects missing repo")
end
test_missing_repo()

local function test_empty_repo()
  local result = tool.execute({repo = ""})
  assert(result == "error: repo argument required", "should error on empty repo: " .. result)
  print("✓ get_prs_with_feedback rejects empty repo")
end
test_empty_repo()

print("\nAll get_prs_with_feedback tests passed!")
