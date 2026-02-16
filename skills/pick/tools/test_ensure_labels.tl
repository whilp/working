#!/usr/bin/env cosmic
-- test_ensure_labels.tl: tests for ensure-labels tool

local tool = require("skills.pick.tools.ensure-labels")

local function test_tool_record()
  assert(tool.name == "ensure_labels", "name should be ensure_labels: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  assert(tool.execute, "should have execute function")
  print("✓ ensure_labels tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ ensure_labels rejects missing WORK_REPO")
end
test_missing_env()

print("\nAll ensure_labels tests passed!")
