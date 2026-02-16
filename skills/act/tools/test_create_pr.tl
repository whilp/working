#!/usr/bin/env cosmic
-- test_create_pr.tl: tests for create-pr tool

local tool = require("skills.act.tools.create-pr")

local function test_tool_record()
  assert(tool.name == "create_pr", "name should be create_pr: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.repo, "should have repo property")
  assert(props.branch, "should have branch property")
  assert(props.title, "should have title property")
  assert(props.body, "should have body property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["repo"], "repo should be required")
  assert(req_set["branch"], "branch should be required")
  assert(req_set["title"], "title should be required")
  assert(req_set["body"], "body should be required")
  assert(tool.execute, "should have execute function")
  print("✓ create_pr tool record is valid")
end
test_tool_record()

local function test_missing_repo()
  local result = tool.execute({branch = "b", title = "t", body = "b"})
  assert(result == "error: repo required", "should error on missing repo: " .. result)
  print("✓ create_pr rejects missing repo")
end
test_missing_repo()

local function test_empty_repo()
  local result = tool.execute({repo = "", branch = "b", title = "t", body = "b"})
  assert(result == "error: repo required", "should error on empty repo: " .. result)
  print("✓ create_pr rejects empty repo")
end
test_empty_repo()

local function test_missing_branch()
  local result = tool.execute({repo = "owner/repo", title = "t", body = "b"})
  assert(result == "error: branch required", "should error on missing branch: " .. result)
  print("✓ create_pr rejects missing branch")
end
test_missing_branch()

local function test_empty_branch()
  local result = tool.execute({repo = "owner/repo", branch = "", title = "t", body = "b"})
  assert(result == "error: branch required", "should error on empty branch: " .. result)
  print("✓ create_pr rejects empty branch")
end
test_empty_branch()

local function test_missing_title()
  local result = tool.execute({repo = "owner/repo", branch = "b", body = "b"})
  assert(result == "error: title required", "should error on missing title: " .. result)
  print("✓ create_pr rejects missing title")
end
test_missing_title()

local function test_empty_title()
  local result = tool.execute({repo = "owner/repo", branch = "b", title = "", body = "b"})
  assert(result == "error: title required", "should error on empty title: " .. result)
  print("✓ create_pr rejects empty title")
end
test_empty_title()

print("\nAll create_pr tests passed!")
