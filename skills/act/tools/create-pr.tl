-- skills/act/tools/create-pr.tl: create a GitHub pull request
--
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local cio = require("cosmic.io")
local fs = require("cosmic.fs")
local unix = require("cosmo.unix")

local function run(argv: {string}): boolean, string, number
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
   name = "create_pr",
   description = "Create a pull request on a GitHub repository. Returns the PR URL on success.",
   input_schema = {
      type = "object",
      properties = {
         repo = {type = "string", description = "GitHub repository (owner/repo)"},
         branch = {type = "string", description = "Head branch name"},
         title = {type = "string", description = "PR title"},
         body = {type = "string", description = "PR body (markdown)"},
      },
      required = {"repo", "branch", "title", "body"},
   },
   execute = function(input: {string:any}): string
      local repo = input.repo as string
      local branch = input.branch as string
      local title = input.title as string
      local body = input.body as string

      if not repo or repo == "" then return "error: repo required" end
      if not branch or branch == "" then return "error: branch required" end
      if not title or title == "" then return "error: title required" end

      local fd, tmp = fs.mkstemp("/tmp/pr-body-XXXXXX")
      if not fd then
         return "error: could not create temp file"
      end
      unix.close(fd)
      cio.barf(tmp, body or "")

      local ok, out, code = run({
         "gh", "pr", "create",
         "--repo", repo,
         "--head", branch,
         "--title", title,
         "--body-file", tmp,
      })
      fs.unlink(tmp)

      if not ok then
         if out and out:find("already exists") then
            return "ok: pr already exists"
         end
         return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
      end
      return "ok: " .. (out or ""):gsub("%s+$", "")
   end,
}
