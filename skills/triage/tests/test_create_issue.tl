#!/usr/bin/env cosmic
-- test_create_issue.tl: tests for create-issue tool

local tool = require("skills.triage.tools.create-issue")

local function test_tool_record()
  assert(tool.name == "create_issue", "name should be create_issue: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.title, "should have title property")
  assert(props.body, "should have body property")
  assert(props.labels, "should have labels property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["title"], "title should be required")
  assert(req_set["body"], "body should be required")
  assert(tool.execute, "should have execute function")
  print("✓ create_issue tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({title = "t", body = "b"})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ create_issue rejects missing WORK_REPO")
end
test_missing_env()

local function test_missing_title()
  local result = tool.execute({body = "b"})
  -- env check comes first
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ create_issue rejects missing env before title")
end
test_missing_title()

print("\nAll create_issue tests passed!")
