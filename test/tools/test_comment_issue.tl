#!/usr/bin/env cosmic
-- test_comment_issue.tl: tests for comment-issue tool

local tool = require("tools.comment-issue")

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

-- parse_issue_number tests via exposed _parse_issue_number
local parse = tool._parse_issue_number as function(any, string): number, string

local function test_parse_bare_number()
  local n, err = parse(42, "whilp/working")
  assert(n == 42, "should return 42: " .. tostring(n))
  assert(not err, "should have no error: " .. tostring(err))
  print("✓ parse_issue_number handles bare number")
end
test_parse_bare_number()

local function test_parse_float_number()
  local n, err = parse(37.9, "whilp/working")
  assert(n == 37, "should floor to 37: " .. tostring(n))
  assert(not err, "should have no error: " .. tostring(err))
  print("✓ parse_issue_number floors float numbers")
end
test_parse_float_number()

local function test_parse_bare_string()
  local n, err = parse("37", "whilp/working")
  assert(n == 37, "should return 37: " .. tostring(n))
  assert(not err, "should have no error: " .. tostring(err))
  print("✓ parse_issue_number handles bare number string")
end
test_parse_bare_string()

local function test_parse_hash_format()
  local n, err = parse("#37", "whilp/working")
  assert(n == 37, "should return 37: " .. tostring(n))
  assert(not err, "should have no error: " .. tostring(err))
  print("✓ parse_issue_number handles #N format")
end
test_parse_hash_format()

local function test_parse_owner_repo_format()
  local n, err = parse("whilp/working#37", "whilp/working")
  assert(n == 37, "should return 37: " .. tostring(n))
  assert(not err, "should have no error: " .. tostring(err))
  print("✓ parse_issue_number handles owner/repo#N format")
end
test_parse_owner_repo_format()

local function test_parse_repo_mismatch()
  local n, err = parse("other/repo#37", "whilp/working")
  assert(not n, "should return nil for mismatched repo")
  assert(err and err:find("repo mismatch"), "should have repo mismatch error: " .. tostring(err))
  print("✓ parse_issue_number rejects mismatched repo")
end
test_parse_repo_mismatch()

local function test_parse_garbage_string()
  local n, err = parse("garbage", "whilp/working")
  assert(not n, "should return nil for garbage")
  assert(err and err:find("could not parse"), "should have parse error: " .. tostring(err))
  print("✓ parse_issue_number rejects garbage string")
end
test_parse_garbage_string()

local function test_parse_nil_input()
  local n, err = parse(nil, "whilp/working")
  assert(not n, "should return nil for nil input")
  assert(err and err:find("must be a number or string"), "should have type error: " .. tostring(err))
  print("✓ parse_issue_number rejects nil input")
end
test_parse_nil_input()

local function test_parse_boolean_input()
  local n, err = parse(true, "whilp/working")
  assert(not n, "should return nil for boolean input")
  assert(err and err:find("must be a number or string"), "should have type error: " .. tostring(err))
  print("✓ parse_issue_number rejects boolean input")
end
test_parse_boolean_input()

print("\nAll comment_issue tests passed!")
