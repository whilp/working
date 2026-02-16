-- skills/pick/tools/ensure-labels.tl: ensure required labels exist on a repo
--
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")

return {
   name = "ensure_labels",
   description = "Ensure required work labels (todo, doing, done, failed) exist on a GitHub repository.",
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

      local labels = {"todo", "doing", "done", "failed"}
      for _, label in ipairs(labels) do
         local h = child.spawn({"gh", "label", "create", label, "--repo", repo, "--force"})
         h:wait()
      end

      return "ok"
   end,
}
