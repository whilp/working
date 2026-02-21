#!/usr/bin/env cosmic
-- test_get_latest_release.tl: tests for get-latest-release tool

local tool = require("skills.bump.tools.get-latest-release")

local function test_tool_record()
  assert(tool.name == "get_latest_release", "name should be get_latest_release: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.repo, "should have repo property")
  assert(props.asset_name, "should have asset_name property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["repo"], "repo should be required")
  assert(req_set["asset_name"], "asset_name should be required")
  assert(tool.execute, "should have execute function")
  print("✓ get_latest_release tool record is valid")
end
test_tool_record()

local function test_missing_repo()
  local result = tool.execute({asset_name = "ah"})
  assert(result == "error: repo required", "should error on missing repo: " .. result)
  print("✓ get_latest_release rejects missing repo")
end
test_missing_repo()

local function test_empty_repo()
  local result = tool.execute({repo = "", asset_name = "ah"})
  assert(result == "error: repo required", "should error on empty repo: " .. result)
  print("✓ get_latest_release rejects empty repo")
end
test_empty_repo()

local function test_missing_asset_name()
  local result = tool.execute({repo = "whilp/ah"})
  assert(result == "error: asset_name required", "should error on missing asset_name: " .. result)
  print("✓ get_latest_release rejects missing asset_name")
end
test_missing_asset_name()

local function test_empty_asset_name()
  local result = tool.execute({repo = "whilp/ah", asset_name = ""})
  assert(result == "error: asset_name required", "should error on empty asset_name: " .. result)
  print("✓ get_latest_release rejects empty asset_name")
end
test_empty_asset_name()

print("\nAll get_latest_release tests passed!")
