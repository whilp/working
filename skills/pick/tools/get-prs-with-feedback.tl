-- skills/pick/tools/get-prs-with-feedback.tl: list open PRs with review feedback
--
-- returns PRs where reviewDecision is CHANGES_REQUESTED, including their
-- review comments and details. combines listing and feedback into one call.
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
  name = "get_prs_with_feedback",
  description = "List open pull requests that have CHANGES_REQUESTED review status, including their review comments. Returns a JSON array of PRs with feedback details. Operates on the repo set by WORK_REPO environment variable.",
  input_schema = {
    type = "object",
    properties = {},
  },
  execute = function(_: {string: any}): string
    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local ok, out, code = run({
      "gh", "pr", "list",
      "--repo", repo,
      "--state", "open",
      "--json", "number,title,url,headRefName,reviewDecision,updatedAt,body",
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
        -- fetch review comments for this PR
        local num = pr.number as number
        local rok, rout, rcode = run({
          "gh", "pr", "view",
          tostring(math.floor(num)),
          "--repo", repo,
          "--json", "number,title,body,headRefName,reviews,comments,reviewDecision,url,updatedAt",
        })
        if rok then
          local detail = json.decode(rout or "{}") as {string: any}
          if detail then
            filtered[#filtered + 1] = detail
          else
            filtered[#filtered + 1] = pr
          end
        else
          -- fall back to list data if view fails
          pr._feedback_error = "gh pr view failed (exit " .. tostring(rcode) .. ")"
          filtered[#filtered + 1] = pr
        end
      end
    end

    return (json.encode(filtered))
  end,
}
