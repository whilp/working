-- skills/pick/tools/count-open-prs.tl: count open PRs on a repo
--
-- reads WORK_REPO from environment to limit scope.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local unix = require("cosmo.unix")
local json = require("cosmic.json")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
    env = unix.environ() as {string},
    stderr = 1,
  })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

local repo = os.getenv("WORK_REPO") or ""

return {
  name = "count_open_prs",
  description = "Count the number of open pull requests on the target repository (set by WORK_REPO). Returns a number.",
  input_schema = {
    type = "object",
    properties = {},
  },
  execute = function(_: {string: any}): string
    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local ok, out, code = run({"gh", "pr", "list", "--repo", repo, "--state", "open", "--json", "number"})
    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    local prs = json.decode(out or "[]") as {any}
    if not prs then
      return "error: failed to parse PR list"
    end

    return tostring(#prs)
  end,
}
