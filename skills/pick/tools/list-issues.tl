-- skills/pick/tools/list-issues.tl: fetch open todo issues from a github repo
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
  name = "list_issues",
  description = "Fetch open issues labeled 'todo' from a GitHub repository. Pass owner/repo as the repo argument.",
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

    local ok, out, code = run({
      "gh", "issue", "list",
      "--repo", repo,
      "--label", "todo",
      "--state", "open",
      "--json", "number,title,body,url,labels,createdAt",
      "--limit", "100",
    })
    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    local issues = json.decode(out or "[]")
    if not issues then
      return "error: failed to parse issues json"
    end

    return (json.encode(issues))
  end,
}
