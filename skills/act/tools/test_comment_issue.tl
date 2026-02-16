#!/usr/bin/env cosmic
-- test_comment_issue.tl: tests for comment-issue tool

local tool = require("skills.act.tools.comment-issue")

local function test_tool_record()
  assert(tool.name == "comment_issue", "name should be comment_issue: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.issue_number, "should have issue_number property")
  assert(props.body, "should have body property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["issue_number"], "issue_number should be required")
  assert(req_set["body"], "body should be required")
  assert(tool.execute, "should have execute function")
  print("✓ comment_issue tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({issue_number = 1, body = "hello"})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ comment_issue rejects missing WORK_REPO")
end
test_missing_env()

local function test_missing_issue_number()
  local result = tool.execute({body = "hello"})
  -- env check comes first
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ comment_issue rejects missing env before issue_number")
end
test_missing_issue_number()

print("\nAll comment_issue tests passed!")
