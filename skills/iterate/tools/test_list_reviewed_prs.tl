#!/usr/bin/env cosmic
-- test_list_reviewed_prs.tl: tests for list-reviewed-prs tool

local tool = require("skills.iterate.tools.list-reviewed-prs")

local function test_tool_record()
  assert(tool.name == "list_reviewed_prs", "name should be list_reviewed_prs: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.repo, "should have repo property")
  local req = schema.required as {string}
  assert(req[1] == "repo", "repo should be required")
  assert(tool.execute, "should have execute function")
  print("✓ list_reviewed_prs tool record is valid")
end
test_tool_record()

local function test_missing_repo()
  local result = tool.execute({})
  assert(result == "error: repo argument required", "should error on missing repo: " .. result)
  print("✓ list_reviewed_prs rejects missing repo")
end
test_missing_repo()

local function test_empty_repo()
  local result = tool.execute({repo = ""})
  assert(result == "error: repo argument required", "should error on empty repo: " .. result)
  print("✓ list_reviewed_prs rejects empty repo")
end
test_empty_repo()

print("\nAll list_reviewed_prs tests passed!")
