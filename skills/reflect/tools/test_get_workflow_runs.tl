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
  assert(props.repo, "should have repo property")
  assert(props.since, "should have since property")
  assert(props.until_, "should have until_ property")
  assert(props.output_dir, "should have output_dir property")
  assert(props.workflow, "should have workflow property")
  local req = schema.required as {string}
  local req_set: {string: boolean} = {}
  for _, r in ipairs(req) do req_set[r] = true end
  assert(req_set["repo"], "repo should be required")
  assert(req_set["since"], "since should be required")
  assert(req_set["until_"], "until_ should be required")
  assert(req_set["output_dir"], "output_dir should be required")
  assert(tool.execute, "should have execute function")
  print("✓ get_workflow_runs tool record is valid")
end
test_tool_record()

local function test_missing_repo()
  local result = tool.execute({since = "2025-01-01", until_ = "2025-01-02", output_dir = "/tmp/test"})
  assert(result == "error: repo required", "should error on missing repo: " .. result)
  print("✓ get_workflow_runs rejects missing repo")
end
test_missing_repo()

local function test_empty_repo()
  local result = tool.execute({repo = "", since = "2025-01-01", until_ = "2025-01-02", output_dir = "/tmp/test"})
  assert(result == "error: repo required", "should error on empty repo: " .. result)
  print("✓ get_workflow_runs rejects empty repo")
end
test_empty_repo()

local function test_missing_since()
  local result = tool.execute({repo = "owner/repo", until_ = "2025-01-02", output_dir = "/tmp/test"})
  assert(result == "error: since required", "should error on missing since: " .. result)
  print("✓ get_workflow_runs rejects missing since")
end
test_missing_since()

local function test_empty_since()
  local result = tool.execute({repo = "owner/repo", since = "", until_ = "2025-01-02", output_dir = "/tmp/test"})
  assert(result == "error: since required", "should error on empty since: " .. result)
  print("✓ get_workflow_runs rejects empty since")
end
test_empty_since()

local function test_missing_until()
  local result = tool.execute({repo = "owner/repo", since = "2025-01-01", output_dir = "/tmp/test"})
  assert(result == "error: until_ required", "should error on missing until_: " .. result)
  print("✓ get_workflow_runs rejects missing until_")
end
test_missing_until()

local function test_empty_until()
  local result = tool.execute({repo = "owner/repo", since = "2025-01-01", until_ = "", output_dir = "/tmp/test"})
  assert(result == "error: until_ required", "should error on empty until_: " .. result)
  print("✓ get_workflow_runs rejects empty until_")
end
test_empty_until()

local function test_missing_output_dir()
  local result = tool.execute({repo = "owner/repo", since = "2025-01-01", until_ = "2025-01-02"})
  assert(result == "error: output_dir required", "should error on missing output_dir: " .. result)
  print("✓ get_workflow_runs rejects missing output_dir")
end
test_missing_output_dir()

local function test_empty_output_dir()
  local result = tool.execute({repo = "owner/repo", since = "2025-01-01", until_ = "2025-01-02", output_dir = ""})
  assert(result == "error: output_dir required", "should error on empty output_dir: " .. result)
  print("✓ get_workflow_runs rejects empty output_dir")
end
test_empty_output_dir()

local function test_bad_since_format()
  local result = tool.execute({repo = "owner/repo", since = "2025/01/01", until_ = "2025-01-02", output_dir = "/tmp/test"})
  assert(result == "error: since must be YYYY-MM-DD format", "should error on bad since format: " .. result)
  print("✓ get_workflow_runs rejects bad since format")
end
test_bad_since_format()

local function test_bad_until_format()
  local result = tool.execute({repo = "owner/repo", since = "2025-01-01", until_ = "Jan 2", output_dir = "/tmp/test"})
  assert(result == "error: until_ must be YYYY-MM-DD format", "should error on bad until_ format: " .. result)
  print("✓ get_workflow_runs rejects bad until_ format")
end
test_bad_until_format()

local function test_bad_repo_format()
  local result = tool.execute({repo = "noslash", since = "2025-01-01", until_ = "2025-01-02", output_dir = "/tmp/test"})
  assert(result == "error: repo must be owner/name format", "should error on bad repo format: " .. result)
  print("✓ get_workflow_runs rejects bad repo format")
end
test_bad_repo_format()

local function test_bad_repo_extra_slash()
  local result = tool.execute({repo = "a/b/c", since = "2025-01-01", until_ = "2025-01-02", output_dir = "/tmp/test"})
  assert(result == "error: repo must be owner/name format", "should error on extra slash: " .. result)
  print("✓ get_workflow_runs rejects repo with extra slashes")
end
test_bad_repo_extra_slash()

print("\nAll get_workflow_runs tests passed!")
