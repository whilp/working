-- lib/build/test_lint.tl: test lint tool record structure

local lint = require("lib.build.lint")

-- validate tool record structure
assert(lint.name == "lint", "expected name='lint', got " .. tostring(lint.name))
assert(type(lint.description) == "string", "description must be string")
assert(type(lint.input_schema) == "table", "input_schema must be table")
assert(lint.input_schema.type == "object", "input_schema.type must be 'object'")
assert(type(lint.execute) == "function", "execute must be function")

-- validate input schema
local props = lint.input_schema.properties as {string: any}
assert(props.files, "input_schema must have 'files' property")
local files_prop = props.files as {string: any}
assert(files_prop.type == "array", "files property must be array type")

-- test error handling
local result = lint.execute({})
assert(result:match("^error:"), "execute with missing files should return error")

print("pass: lib/build/test_lint.tl")
