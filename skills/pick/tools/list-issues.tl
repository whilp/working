-- skills/pick/tools/list-issues.tl: fetch open todo issues from a github repo
--
-- module tool: returns a Tool record for ah to load via -t

local json = require("cosmic.json")

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
   execute = function(input: {string:any}): string
      local repo = input.repo as string
      if not repo or repo == "" then
         return "error: repo argument required"
      end

      local cmd = table.concat({
         "gh", "issue", "list",
         "--repo", repo,
         "--label", "todo",
         "--state", "open",
         "--json", "number,title,body,url,labels,createdAt",
         "--limit", "100",
      }, " ")

      local p = io.popen(cmd .. " 2>&1")
      if not p then
         return "error: failed to run gh"
      end

      local out = p:read("*a")
      local ok = p:close() as boolean
      if not ok then
         return "error: gh failed: " .. (out or "")
      end

      local issues = json.decode(out)
      if not issues then
         return "error: failed to parse issues json"
      end

      return json.encode(issues)
   end,
}
