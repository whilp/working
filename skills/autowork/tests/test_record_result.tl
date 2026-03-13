#!/usr/bin/env cosmic
-- test_record_result.tl: tests for record-result tool

local tool = require("skills.autowork.tools.record-result")

local function test_tool_record()
  assert(tool.name == "record_result", "name should be record_result: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.results_file, "should have results_file property")
  assert(props.commit, "should have commit property")
  assert(props.composite, "should have composite property")
  assert(props.pass_rate, "should have pass_rate property")
  assert(props.mean_quality, "should have mean_quality property")
  assert(props.mean_tokens, "should have mean_tokens property")
  assert(props.status, "should have status property")
  assert(props.description, "should have description property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["results_file"], "results_file should be required")
  assert(req_set["commit"], "commit should be required")
  assert(req_set["composite"], "composite should be required")
  assert(req_set["status"], "status should be required")
  assert(req_set["description"], "description should be required")
  assert(tool.execute, "should have execute function")
  print("✓ record_result tool record is valid")
end
test_tool_record()

local function test_missing_results_file()
  local result = tool.execute({commit = "abc", composite = 0.7, pass_rate = 0.8, mean_quality = 0.7, mean_tokens = 30000, status = "keep", description = "test"})
  assert(result == "error: results_file required", "should error: " .. result)
  print("✓ rejects missing results_file")
end
test_missing_results_file()

local function test_missing_commit()
  local result = tool.execute({results_file = "/tmp/test.tsv", composite = 0.7, pass_rate = 0.8, mean_quality = 0.7, mean_tokens = 30000, status = "keep", description = "test"})
  assert(result == "error: commit required", "should error: " .. result)
  print("✓ rejects missing commit")
end
test_missing_commit()

local function test_missing_status()
  local result = tool.execute({results_file = "/tmp/test.tsv", commit = "abc", composite = 0.7, pass_rate = 0.8, mean_quality = 0.7, mean_tokens = 30000, description = "test"})
  assert(result == "error: status required", "should error: " .. result)
  print("✓ rejects missing status")
end
test_missing_status()

local function test_missing_description()
  local result = tool.execute({results_file = "/tmp/test.tsv", commit = "abc", composite = 0.7, pass_rate = 0.8, mean_quality = 0.7, mean_tokens = 30000, status = "keep"})
  assert(result == "error: description required", "should error: " .. result)
  print("✓ rejects missing description")
end
test_missing_description()

print("\nAll record_result tests passed!")
