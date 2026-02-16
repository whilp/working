#!/usr/bin/env cosmic
-- test_get_pr_feedback.tl: tests for get-pr-feedback tool

local tool = require("skills.iterate.tools.get-pr-feedback")

local function test_tool_record()
  assert(tool.name == "get_pr_feedback", "name should be get_pr_feedback: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.repo, "should have repo property")
  assert(props.pr_number, "should have pr_number property")
  local req = schema.required as {string}
  local has_repo = false
  local has_pr_number = false
  for _, r in ipairs(req) do
    if r == "repo" then has_repo = true end
    if r == "pr_number" then has_pr_number = true end
  end
  assert(has_repo, "repo should be required")
  assert(has_pr_number, "pr_number should be required")
  assert(tool.execute, "should have execute function")
  print("✓ get_pr_feedback tool record is valid")
end
test_tool_record()

local function test_missing_repo()
  local result = tool.execute({pr_number = 1})
  assert(result == "error: repo argument required", "should error on missing repo: " .. result)
  print("✓ get_pr_feedback rejects missing repo")
end
test_missing_repo()

local function test_empty_repo()
  local result = tool.execute({repo = "", pr_number = 1})
  assert(result == "error: repo argument required", "should error on empty repo: " .. result)
  print("✓ get_pr_feedback rejects empty repo")
end
test_empty_repo()

local function test_missing_pr_number()
  local result = tool.execute({repo = "owner/repo"})
  assert(result == "error: pr_number argument required", "should error on missing pr_number: " .. result)
  print("✓ get_pr_feedback rejects missing pr_number")
end
test_missing_pr_number()

print("\nAll get_pr_feedback tests passed!")
