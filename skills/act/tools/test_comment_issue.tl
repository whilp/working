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
  assert(props.issue_url, "should have issue_url property")
  assert(props.body, "should have body property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["issue_url"], "issue_url should be required")
  assert(req_set["body"], "body should be required")
  assert(tool.execute, "should have execute function")
  print("✓ comment_issue tool record is valid")
end
test_tool_record()

local function test_missing_issue_url()
  local result = tool.execute({body = "hello"})
  assert(result == "error: issue_url required", "should error on missing issue_url: " .. result)
  print("✓ comment_issue rejects missing issue_url")
end
test_missing_issue_url()

local function test_empty_issue_url()
  local result = tool.execute({issue_url = "", body = "hello"})
  assert(result == "error: issue_url required", "should error on empty issue_url: " .. result)
  print("✓ comment_issue rejects empty issue_url")
end
test_empty_issue_url()

local function test_missing_body()
  local result = tool.execute({issue_url = "https://github.com/owner/repo/issues/1"})
  assert(result == "error: body required", "should error on missing body: " .. result)
  print("✓ comment_issue rejects missing body")
end
test_missing_body()

local function test_empty_body()
  local result = tool.execute({issue_url = "https://github.com/owner/repo/issues/1", body = ""})
  assert(result == "error: body required", "should error on empty body: " .. result)
  print("✓ comment_issue rejects empty body")
end
test_empty_body()

print("\nAll comment_issue tests passed!")
