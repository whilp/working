#!/usr/bin/env cosmic
-- test_set_issue_labels.tl: tests for act/set-issue-labels tool

local tool = require("skills.act.tools.set-issue-labels")

local function test_tool_record()
  assert(tool.name == "set_issue_labels", "name should be set_issue_labels: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.issue_number, "should have issue_number property")
  assert(props.add, "should have add property")
  assert(props.remove, "should have remove property")
  local req = schema.required as {string}
  assert(req[1] == "issue_number", "issue_number should be required")
  assert(tool.execute, "should have execute function")
  print("✓ act/set_issue_labels tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({issue_number = 1})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ act/set_issue_labels rejects missing WORK_REPO")
end
test_missing_env()

print("\nAll act/set_issue_labels tests passed!")
