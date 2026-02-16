-- skills/pick/tools/count-open-prs.tl: count open PRs on a repo
--
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

return {
  name = "count_open_prs",
  description = "Count the number of open pull requests on a GitHub repository. Returns a number.",
  input_schema = {
    type = "object",
    properties = {
      repo = {type = "string", description = "GitHub repository (owner/repo)"},
    },
    required = {"repo"},
  },
  execute = function(input: {string: any}): string
    local repo = input.repo as string
    if not repo or repo == "" then
      return "error: repo argument required"
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
