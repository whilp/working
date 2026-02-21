#!/usr/bin/env cosmic
-- test_create_pr.tl: tests for create-pr tool

local tool = require("tools.create-pr")

local function test_tool_record()
  assert(tool.name == "create_pr", "name should be create_pr: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.branch, "should have branch property")
  assert(props.title, "should have title property")
  assert(props.body, "should have body property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["branch"], "branch should be required")
  assert(req_set["title"], "title should be required")
  assert(req_set["body"], "body should be required")
  assert(tool.execute, "should have execute function")
  print("✓ create_pr tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({branch = "b", title = "t", body = "b"})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ create_pr rejects missing WORK_REPO")
end
test_missing_env()

print("\nAll create_pr tests passed!")
