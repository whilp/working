-- skills/act/tools/create-pr.tl: create a GitHub pull request
--
-- module tool: returns a Tool record for ah to load via -t

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

      -- write body to temp file to avoid shell escaping issues
      local tmp_body = os.tmpname()
      local fb = io.open(tmp_body, "w")
      if not fb then
         return "error: could not create temp file"
      end
      fb:write(body or "")
      fb:close()

      -- escape single quotes in title for shell
      local safe_title = title:gsub("'", "'\\''")

      local cmd = "gh pr create --repo '" .. repo .. "' --head '" .. branch .. "' --title '" .. safe_title .. "' --body-file '" .. tmp_body .. "' 2>&1"
      local p = io.popen(cmd)
      if not p then
         os.remove(tmp_body)
         return "error: failed to run gh"
      end

      local out = p:read("*a")
      local ok = p:close() as boolean
      os.remove(tmp_body)

      if not ok then
         if out and out:find("already exists") then
            return "ok: pr already exists"
         end
         return "error: gh failed: " .. (out or "")
      end

      return "ok: " .. (out or ""):gsub("%s+$", "")
   end,
}
