#!/usr/bin/env cosmic
-- test_get_workflow_runs.tl: tests for get-workflow-runs tool

local tool = require("skills.reflect.tools.get-workflow-runs")

local function test_tool_record()
  assert(tool.name == "get_workflow_runs", "name should be get_workflow_runs: " .. tostring(tool.name))
  assert(tool.description and #tool.description > 0, "should have description")
  assert(tool.input_schema, "should have input_schema")
  local schema = tool.input_schema as {string: any}
  assert(schema.type == "object", "schema type should be object")
  local props = schema.properties as {string: any}
  assert(props.since, "should have since property")
  assert(props.until_, "should have until_ property")
  assert(props.output_dir, "should have output_dir property")
  assert(props.workflow, "should have workflow property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["since"], "since should be required")
  assert(req_set["until_"], "until_ should be required")
  assert(req_set["output_dir"], "output_dir should be required")
  assert(tool.execute, "should have execute function")
  print("✓ get_workflow_runs tool record is valid")
end
test_tool_record()

local function test_missing_env()
  local result = tool.execute({since = "2025-01-01", until_ = "2025-01-02", output_dir = "/tmp/test"})
  assert(result == "error: WORK_REPO environment variable not set", "should error on missing env: " .. result)
  print("✓ get_workflow_runs rejects missing WORK_REPO")
end
test_missing_env()

print("\nAll get_workflow_runs tests passed!")
