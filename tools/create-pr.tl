-- tools/create-pr.tl: create a GitHub pull request
--
-- reads WORK_REPO from environment to limit scope.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local cio = require("cosmic.io")
local fs = require("cosmic.fs")

local repo = os.getenv("WORK_REPO") or ""

return {
  name = "create_pr",
  description = "Create a pull request on the target repository (set by WORK_REPO). Returns the PR URL on success.",
  input_schema = {
    type = "object",
    properties = {
      branch = {type = "string", description = "Head branch name"},
      title = {type = "string", description = "PR title"},
      body = {type = "string", description = "PR body (markdown)"},
    },
    required = {"branch", "title", "body"},
  },
  execute = function(input: {string: any}): string
    local branch = input.branch as string
    local title = input.title as string
    local body = input.body as string

    if repo == "" then return "error: WORK_REPO environment variable not set" end
    if not branch or branch == "" then return "error: branch required" end
    if not title or title == "" then return "error: title required" end

    local tmp = os.tmpname()
    cio.barf(tmp, body or "")

    local h, err = child.spawn({
        "gh", "pr", "create",
        "--repo", repo,
        "--head", branch,
        "--title", title,
        "--body-file", tmp,
      }, {stderr = 1})
    fs.unlink(tmp)
    if not h then
      return "error: gh failed: " .. (err or "spawn failed")
    end
    local ok, out, code = h:read()

    if not ok then
      if out and out:find("already exists") then
        return "ok: pr already exists"
      end
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end
    return "ok: " .. (out or ""):gsub("%s+$", "")
  end,
}
