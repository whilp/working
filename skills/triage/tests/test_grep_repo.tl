#!/usr/bin/env cosmic
-- test_grep_repo.tl: tests for grep-repo tool

local tool = require("skills.triage.tools.grep-repo")

local function test_tool_record()
  assert(tool.name == "grep_repo", "name should be grep_repo: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.pattern, "should have pattern property")
  assert(props.path, "should have path property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["pattern"], "pattern should be required")
  assert(tool.execute, "should have execute function")
  print("✓ grep_repo tool record is valid")
end
test_tool_record()

local function test_empty_pattern()
  local result = tool.execute({pattern = ""})
  assert(result == "error: pattern required", "should error on empty pattern: " .. result)
  print("✓ grep_repo rejects empty pattern")
end
test_empty_pattern()

local function test_missing_pattern()
  local result = tool.execute({})
  assert(result == "error: pattern required", "should error on missing pattern: " .. result)
  print("✓ grep_repo rejects missing pattern")
end
test_missing_pattern()

local function test_path_traversal()
  local result = tool.execute({pattern = "test", path = "../../etc"})
  assert(result == "error: path must not contain '..'", "should reject path traversal: " .. result)
  print("✓ grep_repo rejects path traversal")
end
test_path_traversal()

print("\nAll grep_repo tests passed!")
