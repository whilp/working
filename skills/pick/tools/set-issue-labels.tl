-- skills/pick/tools/set-issue-labels.tl: add/remove labels on an issue
--
-- reads WORK_REPO from environment to limit scope.
-- takes issue number instead of URL.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
      stderr = 1,
    })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

local repo = os.getenv("WORK_REPO") or ""

return {
  name = "set_issue_labels",
  description = "Add and/or remove labels on a GitHub issue by number.",
  input_schema = {
    type = "object",
    properties = {
      issue_number = {type = "number", description = "Issue or PR number"},
      add = {type = "array", items = {type = "string"}, description = "Labels to add"},
      remove = {type = "array", items = {type = "string"}, description = "Labels to remove"},
    },
    required = {"issue_number"},
  },
  execute = function(input: {string: any}): string
    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local issue_number = input.issue_number as number
    if not issue_number then
      return "error: issue_number required"
    end

    local num = tostring(math.floor(issue_number))
    local argv: {string} = {"gh", "issue", "edit", num, "--repo", repo}

    local add = input.add as {string}
    if add then
      for _, label in ipairs(add) do
        table.insert(argv, "--add-label")
        table.insert(argv, label)
      end
    end

    local remove = input.remove as {string}
    if remove then
      for _, label in ipairs(remove) do
        table.insert(argv, "--remove-label")
        table.insert(argv, label)
      end
    end

    local ok, out, code = run(argv)
    if not ok then
      if code == 4 then
        return "error: gh access denied (exit 4): " .. (out or "")
      end
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end
    return "ok"
  end,
}
