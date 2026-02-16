-- skills/pick/tools/set-issue-labels.tl: add/remove labels on an issue
--
-- module tool: returns a Tool record for ah to load via -t

return {
   name = "set_issue_labels",
   description = "Add and/or remove labels on a GitHub issue. Pass the issue URL and lists of labels to add/remove.",
   input_schema = {
      type = "object",
      properties = {
         issue_url = {type = "string", description = "Full GitHub issue URL"},
         add = {type = "array", items = {type = "string"}, description = "Labels to add"},
         remove = {type = "array", items = {type = "string"}, description = "Labels to remove"},
      },
      required = {"issue_url"},
   },
   execute = function(input: {string:any}): string
      local url = input.issue_url as string
      if not url or url == "" then
         return "error: issue_url required"
      end

      local cmd = "gh issue edit '" .. url .. "'"

      local add = input.add as {string}
      if add then
         for _, label in ipairs(add) do
            cmd = cmd .. " --add-label '" .. label .. "'"
         end
      end

      local remove = input.remove as {string}
      if remove then
         for _, label in ipairs(remove) do
            cmd = cmd .. " --remove-label '" .. label .. "'"
         end
      end

      local p = io.popen(cmd .. " 2>&1")
      if not p then
         return "error: failed to run gh"
      end

      local out = p:read("*a")
      local ok = p:close() as boolean
      if not ok then
         return "error: gh failed: " .. (out or "")
      end

      return "ok"
   end,
}
