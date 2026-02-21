#!/usr/bin/env cosmic
-- test_close_issue.tl: tests for close-issue tool

local tool = require("skills.triage.tools.close-issue")

local function test_tool_record()
  assert(tool.name == "close_issue", "name should be close_issue: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.issue_number, "should have issue_number property")
  assert(props.reason, "should have reason property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["issue_number"], "issue_number should be required")
  assert(tool.execute, "should have execute function")
  print("✓ close_issue tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({issue_number = 1})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ close_issue rejects missing WORK_REPO")
end
test_missing_env()

local function test_missing_issue_number()
  local result = tool.execute({})
  -- env check comes first
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ close_issue rejects missing env before issue_number")
end
test_missing_issue_number()

print("\nAll close_issue tests passed!")
