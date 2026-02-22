-- lib/gh/test_run.tl: test run module

local run = require("lib.gh.run")

assert(type(run) == "function", "run must be a function")

print("pass: lib/gh/test_run.tl")
