-- skills/triage/tools/create-issue.tl: create a GitHub issue
--
-- reads WORK_REPO from environment to limit scope.
-- module tool: returns a Tool record for ah to load via -t

local cio = require("cosmic.io")
local fs = require("cosmic.fs")
local run = require("lib.gh.run")

local repo = os.getenv("WORK_REPO") or ""

return {
  name = "create_issue",
  description = "Create a new GitHub issue in the target repository. Returns the issue URL on success.",
  input_schema = {
    type = "object",
    properties = {
      title = {type = "string", description = "Issue title"},
      body = {type = "string", description = "Issue body (markdown)"},
      labels = {type = "array", items = {type = "string"}, description = "Labels to apply"},
    },
    required = {"title", "body"},
  },
  execute = function(input: {string: any}): string
    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local title = input.title as string
    local body = input.body as string

    if not title or title == "" then return "error: title required" end
    if not body or body == "" then return "error: body required" end

    local tmp = os.tmpname()
    cio.barf(tmp, body)

    local argv: {string} = {
      "gh", "issue", "create",
      "--repo", repo,
      "--title", title,
      "--body-file", tmp,
    }

    local labels = input.labels as {string}
    if labels then
      for _, label in ipairs(labels) do
        table.insert(argv, "--label")
        table.insert(argv, label)
      end
    end

    local ok, out, code = run(argv)
    fs.unlink(tmp)

    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end
    return "ok: " .. (out or ""):gsub("%s+$", "")
  end,
}
