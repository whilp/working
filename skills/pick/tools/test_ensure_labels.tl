#!/usr/bin/env cosmic
-- test_ensure_labels.tl: tests for ensure-labels tool

local tool = require("skills.pick.tools.ensure-labels")

local function test_tool_record()
  assert(tool.name == "ensure_labels", "name should be ensure_labels: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.repo, "should have repo property")
  local req = schema.required as {string}
  assert(req[1] == "repo", "repo should be required")
  assert(tool.execute, "should have execute function")
  print("✓ ensure_labels tool record is valid")
end
test_tool_record()

local function test_missing_repo()
  local result = tool.execute({})
  assert(result == "error: repo argument required", "should error on missing repo: " .. result)
  print("✓ ensure_labels rejects missing repo")
end
test_missing_repo()

local function test_empty_repo()
  local result = tool.execute({repo = ""})
  assert(result == "error: repo argument required", "should error on empty repo: " .. result)
  print("✓ ensure_labels rejects empty repo")
end
test_empty_repo()

print("\nAll ensure_labels tests passed!")
