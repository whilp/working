-- skills/pick/tools/ensure-labels.tl: ensure required labels exist on a repo
--
-- reads WORK_REPO from environment to limit scope.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")

local repo = os.getenv("WORK_REPO") or ""

return {
  name = "ensure_labels",
  description = "Ensure required labels exist on the target repository (set by WORK_REPO). Defaults to work labels (todo, doing, done, failed, needs-review) if no labels specified.",
  input_schema = {
    type = "object",
    properties = {
      labels = {type = "array", items = {type = "string"}, description = "Labels to ensure exist (default: todo, doing, done, failed)"},
    },
  },
  execute = function(input: {string: any}): string
    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local custom = input.labels as {string}
    local labels: {string} = (custom and #custom > 0) and custom or {"todo", "doing", "done", "failed", "needs-review"}
    local errors: {string} = {}
    for _, label in ipairs(labels) do
      local h, err = child.spawn({"gh", "label", "create", label, "--repo", repo, "--force"}, {stderr = 1})
      if not h then
        table.insert(errors, label .. ": " .. (err or "spawn failed"))
        goto continue
      end
      local ok, out, code = h:read()
      if not ok then
        local msg: string
        if code == 4 then
          msg = label .. ": access denied (exit 4): " .. (out or "")
        else
          msg = label .. ": " .. (out or "")
        end
        table.insert(errors, msg)
      end
      ::continue::
    end

    if #errors > 0 then
      return "errors: " .. table.concat(errors, "; ")
    end
    return "ok"
  end,
}
