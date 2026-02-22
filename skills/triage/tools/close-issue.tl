-- skills/triage/tools/close-issue.tl: close a GitHub issue
--
-- reads WORK_REPO from environment to limit scope.
-- takes issue number instead of URL.
-- module tool: returns a Tool record for ah to load via -t

local run = require("lib.gh.run")

local repo = os.getenv("WORK_REPO") or ""

local valid_reasons: {string: boolean} = {
  completed = true,
  ["not planned"] = true,
}

return {
  name = "close_issue",
  description = "Close a GitHub issue with an optional reason.",
  input_schema = {
    type = "object",
    properties = {
      issue_number = {type = "number", description = "Issue number"},
      reason = {type = "string", description = "Close reason: completed or 'not planned' (default: 'not planned')"},
    },
    required = {"issue_number"},
  },
  execute = function(input: {string: any}): string
    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local issue_number = input.issue_number as number
    if not issue_number then
      return "error: issue_number required"
    end

    local reason = input.reason as string
    if not reason or reason == "" then
      reason = "not planned"
    end
    if not valid_reasons[reason] then
      return "error: invalid reason: " .. reason .. " (must be completed or 'not planned')"
    end

    local num = tostring(math.floor(issue_number))
    local argv: {string} = {"gh", "issue", "close", num, "--repo", repo, "--reason", reason}

    local ok, out, code = run(argv)
    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end
    return "ok"
  end,
}
