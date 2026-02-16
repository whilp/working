#!/usr/bin/env cosmic
-- test_set_issue_labels.tl: tests for pick/set-issue-labels tool

local tool = require("skills.pick.tools.set-issue-labels")

local function test_tool_record()
  assert(tool.name == "set_issue_labels", "name should be set_issue_labels: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.issue_url, "should have issue_url property")
  assert(props.add, "should have add property")
  assert(props.remove, "should have remove property")
  local req = schema.required as {string}
  assert(req[1] == "issue_url", "issue_url should be required")
  assert(tool.execute, "should have execute function")
  print("✓ pick/set_issue_labels tool record is valid")
end
test_tool_record()

local function test_missing_issue_url()
  local result = tool.execute({})
  assert(result == "error: issue_url required", "should error on missing issue_url: " .. result)
  print("✓ pick/set_issue_labels rejects missing issue_url")
end
test_missing_issue_url()

local function test_empty_issue_url()
  local result = tool.execute({issue_url = ""})
  assert(result == "error: issue_url required", "should error on empty issue_url: " .. result)
  print("✓ pick/set_issue_labels rejects empty issue_url")
end
test_empty_issue_url()

print("\nAll pick/set_issue_labels tests passed!")
