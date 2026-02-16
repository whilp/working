-- skills/act/tools/comment-issue.tl: comment on a GitHub issue
--
-- module tool: returns a Tool record for ah to load via -t

return {
   name = "comment_issue",
   description = "Post a comment on a GitHub issue.",
   input_schema = {
      type = "object",
      properties = {
         issue_url = {type = "string", description = "Full GitHub issue URL"},
         body = {type = "string", description = "Comment body (markdown)"},
      },
      required = {"issue_url", "body"},
   },
   execute = function(input: {string:any}): string
      local url = input.issue_url as string
      local body = input.body as string

      if not url or url == "" then
         return "error: issue_url required"
      end
      if not body or body == "" then
         return "error: body required"
      end

      -- write body to temp file to avoid shell escaping issues
      local tmp = os.tmpname()
      local f = io.open(tmp, "w")
      if not f then
         return "error: could not create temp file"
      end
      f:write(body)
      f:close()

      local p = io.popen("gh issue comment '" .. url .. "' --body-file '" .. tmp .. "' 2>&1")
      if not p then
         os.remove(tmp)
         return "error: failed to run gh"
      end

      local out = p:read("*a")
      local ok = p:close() as boolean
      os.remove(tmp)

      if not ok then
         return "error: gh failed: " .. (out or "")
      end

      return "ok"
   end,
}
