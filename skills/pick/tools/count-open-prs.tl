-- skills/pick/tools/count-open-prs.tl: count open PRs on a repo
--
-- uses graphql with explicit owner/name to avoid gh CLI local repo
-- context issues. reads WORK_REPO from environment to limit scope.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local json = require("cosmic.json")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
      stderr = 1,
    })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

local QUERY = [[
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: OPEN) {
      totalCount
    }
  }
}
]]

return {
  name = "count_open_prs",
  description = "Count the number of open pull requests on the target repository (set by WORK_REPO). Returns a number.",
  input_schema = {
    type = "object",
    properties = {},
  },
  execute = function(_: {string: any}): string
    local live_repo = os.getenv("WORK_REPO") or ""
    if live_repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local owner, name = live_repo:match("^([^/]+)/([^/]+)$")
    if not owner or not name then
      return "error: WORK_REPO must be owner/name format"
    end

    io.stderr:write("count_open_prs: querying " .. owner .. "/" .. name .. "\n")

    local ok, out, code = run({
        "gh", "api", "graphql",
        "-f", "query=" .. QUERY,
        "-f", "owner=" .. owner,
        "-f", "name=" .. name,
      })
    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    local resp = json.decode(out or "{}") as {string: any}
    if not resp or not resp.data then
      local errors = resp and resp.errors as {any}
      if errors and #errors > 0 then
        local first = errors[1] as {string: any}
        return "error: graphql: " .. tostring(first.message or "unknown")
      end
      return "error: failed to parse graphql response"
    end

    local data = resp.data as {string: any}
    local repository = data.repository as {string: any}
    local prs_conn = repository.pullRequests as {string: any}
    local count = prs_conn.totalCount as number

    return tostring(math.floor(count))
  end,
}
