-- skills/iterate/tools/get-pr-feedback.tl: get review comments for a PR
--
-- returns the PR details including reviews and comments.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local unix = require("cosmo.unix")

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
  name = "get_pr_feedback",
  description = "Get review comments and feedback for a specific pull request. Returns JSON with reviews, comments, and review decision.",
  input_schema = {
    type = "object",
    properties = {
      repo = {type = "string", description = "GitHub repository (owner/repo)"},
      pr_number = {type = "number", description = "Pull request number"},
    },
    required = {"repo", "pr_number"},
  },
  execute = function(input: {string: any}): string
    local repo = input.repo as string
    local pr_number = input.pr_number as number
    if not repo or repo == "" then
      return "error: repo argument required"
    end
    if not pr_number then
      return "error: pr_number argument required"
    end

    local ok, out, code = run({
      "gh", "pr", "view",
      tostring(math.floor(pr_number)),
      "--repo", repo,
      "--json", "number,title,body,headRefName,reviews,comments,reviewDecision,url",
    })
    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    return out or ""
  end,
}
