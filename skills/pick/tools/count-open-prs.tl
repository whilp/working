-- skills/pick/tools/count-open-prs.tl: count open PRs on a repo
--
-- module tool: returns a Tool record for ah to load via -t

local json = require("cosmic.json")

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
   execute = function(input: {string:any}): string
      local repo = input.repo as string
      if not repo or repo == "" then
         return "error: repo argument required"
      end

      local p = io.popen("gh pr list --repo " .. repo .. " --state open --json number 2>&1")
      if not p then
         return "error: failed to run gh"
      end

      local out = p:read("*a")
      local ok = p:close() as boolean
      if not ok then
         return "error: gh failed: " .. (out or "")
      end

      local prs = json.decode(out) as {any}
      if not prs then
         return "error: failed to parse PR list"
      end

      return tostring(#prs)
   end,
}
