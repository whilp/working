-- skills/plan/lib/test_get_ci_log.tl: tests for get-ci-log tool

local tool = require("skills.plan.lib.get-ci-log")

-- tool record structure
assert(tool.name == "get_ci_log", "name must be get_ci_log")
assert(tool.description and tool.description ~= "", "description required")
assert(tool.input_schema, "input_schema required")
assert(tool.input_schema.type == "object", "schema type must be object")
assert(tool.input_schema.properties.sha, "sha property required")
assert(tool.input_schema.properties.output_file, "output_file property required")
assert(tool.execute, "execute function required")
print("✓ tool record structure")

-- required field: sha
local r1 = tool.execute({sha = "", output_file = "/tmp/test.txt"})
assert(r1:match("^error:"), "empty sha should error: " .. r1)
print("✓ empty sha returns error")

-- required field: output_file
local r2 = tool.execute({sha = "abc123", output_file = ""})
assert(r2:match("^error:"), "empty output_file should error: " .. r2)
print("✓ empty output_file returns error")

-- required field: WORK_REPO (not set in test env)
local r3 = tool.execute({sha = "abc123", output_file = "/tmp/test.txt"})
assert(r3:match("^error:.*WORK_REPO"), "missing WORK_REPO should error: " .. r3)
print("✓ missing WORK_REPO returns error")

print("\n4 checks: 4 passed")
