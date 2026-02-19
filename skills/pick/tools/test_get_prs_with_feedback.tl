#!/usr/bin/env cosmic
-- test_get_prs_with_feedback.tl: tests for get-prs-with-feedback tool

local tool = require("skills.pick.tools.get-prs-with-feedback")

local function test_tool_record()
  assert(tool.name == "get_prs_with_feedback", "name should be get_prs_with_feedback: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  assert(tool.execute, "should have execute function")
  print("✓ get_prs_with_feedback tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ get_prs_with_feedback rejects missing WORK_REPO")
end
test_missing_env()

local function test_parse_repo()
  local parse = (tool as {string: any})._parse_repo as function(string): string, string
  assert(parse, "should expose _parse_repo for testing")

  local owner, name = parse("whilp/cosmic")
  assert(owner == "whilp", "owner should be whilp: " .. tostring(owner))
  assert(name == "cosmic", "name should be cosmic: " .. tostring(name))
  print("✓ parse_repo splits owner/name correctly")

  local o2, n2 = parse("invalid")
  assert(o2 == nil, "should return nil for invalid format")
  assert(n2 == nil, "should return nil for invalid format")
  print("✓ parse_repo rejects invalid format")

  local o3, n3 = parse("")
  assert(o3 == nil, "should return nil for empty string")
  assert(n3 == nil, "should return nil for empty string")
  print("✓ parse_repo rejects empty string")

  local o4, n4 = parse("a/b/c")
  assert(o4 == nil, "should reject extra slashes: " .. tostring(o4))
  assert(n4 == nil, "should reject extra slashes: " .. tostring(n4))
  print("✓ parse_repo rejects extra slashes")
end
test_parse_repo()

local function test_invalid_repo_format()
  -- set WORK_REPO to an invalid format to test validation
  local orig = os.getenv("WORK_REPO")
  -- can't unset env in lua, but we already tested empty above
  -- test with a bad format via the exported parse function
  local parse = (tool as {string: any})._parse_repo as function(string): string, string
  local o1, n1 = parse("just-owner")
  assert(o1 == nil, "should reject owner without name")
  assert(n1 == nil, "should reject owner without name")
  print("✓ parse_repo rejects owner without name")

  local o2, n2 = parse("/name")
  assert(o2 == nil or o2 == "", "should reject missing owner: " .. tostring(o2))
  print("✓ parse_repo rejects missing owner")
end
test_invalid_repo_format()

print("\nAll get_prs_with_feedback tests passed!")
