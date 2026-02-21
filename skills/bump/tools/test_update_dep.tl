#!/usr/bin/env cosmic
-- test_update_dep.tl: tests for update-dep tool

local tool = require("skills.bump.tools.update-dep")

local function test_tool_record()
  assert(tool.name == "update_dep", "name should be update_dep: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.dep, "should have dep property")
  assert(props.url, "should have url property")
  assert(props.sha, "should have sha property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["dep"], "dep should be required")
  assert(req_set["url"], "url should be required")
  assert(tool.execute, "should have execute function")
  print("✓ update_dep tool record is valid")
end
test_tool_record()

local function test_missing_dep()
  local result = tool.execute({url = "https://example.com/file"})
  assert(result == "error: dep required", "should error on missing dep: " .. result)
  print("✓ update_dep rejects missing dep")
end
test_missing_dep()

local function test_empty_dep()
  local result = tool.execute({dep = "", url = "https://example.com/file"})
  assert(result == "error: dep required", "should error on empty dep: " .. result)
  print("✓ update_dep rejects empty dep")
end
test_empty_dep()

local function test_invalid_dep()
  local result = tool.execute({dep = "invalid", url = "https://example.com/file"})
  assert(result == "error: invalid dep: invalid (must be ah or cosmic)", "should error on invalid dep: " .. result)
  print("✓ update_dep rejects invalid dep")
end
test_invalid_dep()

local function test_missing_url()
  local result = tool.execute({dep = "ah"})
  assert(result == "error: url required", "should error on missing url: " .. result)
  print("✓ update_dep rejects missing url")
end
test_missing_url()

local function test_empty_url()
  local result = tool.execute({dep = "ah", url = ""})
  assert(result == "error: url required", "should error on empty url: " .. result)
  print("✓ update_dep rejects empty url")
end
test_empty_url()

print("\nAll update_dep tests passed!")
