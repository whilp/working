-- skills/iterate/tools/list-reviewed-prs.tl: list open PRs with review feedback
--
-- returns PRs where reviewDecision is CHANGES_REQUESTED.
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
  name = "list_reviewed_prs",
  description = "List open pull requests that have CHANGES_REQUESTED review status. Returns a JSON array of PRs needing iteration.",
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
      "gh", "pr", "list",
      "--repo", repo,
      "--state", "open",
      "--json", "number,title,url,headRefName,reviewDecision,updatedAt",
    })
    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    local prs = json.decode(out or "[]") as {{string: any}}
    if not prs then
      return "error: failed to parse PR list"
    end

    local filtered: {any} = {}
    for _, pr in ipairs(prs) do
      if pr.reviewDecision == "CHANGES_REQUESTED" then
        filtered[#filtered + 1] = pr
      end
    end

    return (json.encode(filtered))
  end,
}
