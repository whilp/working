-- lib/gh/run.tl: shared gh subprocess helper
--
-- spawns a child process and returns its output.
-- used by all gh tool modules.

local child = require("cosmic.child")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
      stderr = 1,
    })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

return run
