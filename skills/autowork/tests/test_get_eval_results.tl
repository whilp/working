#!/usr/bin/env cosmic
-- test_get_eval_results.tl: tests for get-eval-results tool

local tool = require("skills.autowork.tools.get-eval-results")

local function test_tool_record()
  assert(tool.name == "get_eval_results", "name should be get_eval_results: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.results_file, "should have results_file property")
  assert(props.limit, "should have limit property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["results_file"], "results_file should be required")
  assert(tool.execute, "should have execute function")
  print("✓ get_eval_results tool record is valid")
end
test_tool_record()

local function test_missing_results_file()
  local result = tool.execute({})
  assert(result == "error: results_file required", "should error on missing file: " .. result)
  print("✓ rejects missing results_file")
end
test_missing_results_file()

local function test_empty_results_file()
  local result = tool.execute({results_file = ""})
  assert(result == "error: results_file required", "should error on empty file: " .. result)
  print("✓ rejects empty results_file")
end
test_empty_results_file()

local function test_nonexistent_file()
  local result = tool.execute({results_file = "/tmp/nonexistent-eval-results-12345.tsv"})
  assert(result == "no results yet", "should return no results for missing file: " .. result)
  print("✓ handles nonexistent file")
end
test_nonexistent_file()

print("\nAll get_eval_results tests passed!")
