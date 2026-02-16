-- skills/pick/tools/ensure-labels.tl: ensure required labels exist on a repo
--
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local unix = require("cosmo.unix")

local function run(argv: {string}): boolean | string, string, number
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
  name = "ensure_labels",
  description = "Ensure required work labels (todo, doing, done, failed) exist on a GitHub repository.",
  input_schema = {
    type = "object",
    properties = {
      repo = {type = "string", description = "GitHub repository (owner/repo)"},
    },
    required = {"repo"},
  },
  execute = function(input: {string: any}): string
    local repo = input.repo as string
    if not repo or repo == "" then
      return "error: repo argument required"
    end

    local labels = {"todo", "doing", "done", "failed"}
    local errors: {string} = {}
    for _, label in ipairs(labels) do
      local ok, out = run({"gh", "label", "create", label, "--repo", repo, "--force"})
      if not ok then
        table.insert(errors, label .. ": " .. (out or ""))
      end
    end

    if #errors > 0 then
      return "errors: " .. table.concat(errors, "; ")
    end
    return "ok"
  end,
}
