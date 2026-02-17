-- skills/act/tools/comment-issue.tl: comment on a GitHub issue
--
-- reads WORK_REPO from environment to limit scope.
-- takes issue number instead of URL.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local cio = require("cosmic.io")
local fs = require("cosmic.fs")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
      stderr = 1,
    })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

local repo = os.getenv("WORK_REPO") or ""

return {
  name = "comment_issue",
  description = "Post a comment on a GitHub issue or pull request by number.",
  input_schema = {
    type = "object",
    properties = {
      issue_number = {type = "number", description = "Issue or PR number"},
      body = {type = "string", description = "Comment body (markdown)"},
    },
    required = {"issue_number", "body"},
  },
  execute = function(input: {string: any}): string
    local issue_number = input.issue_number as number
    local body = input.body as string

    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end
    if not issue_number then
      return "error: issue_number required"
    end
    if not body or body == "" then
      return "error: body required"
    end

    local ref = repo .. "#" .. tostring(math.floor(issue_number))

    local tmp = os.tmpname()
    cio.barf(tmp, body)

    local ok, out, code = run({"gh", "issue", "comment", ref, "--body-file", tmp})
    fs.unlink(tmp)

    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end
    return "ok"
  end,
}
