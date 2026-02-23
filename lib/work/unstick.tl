-- lib/work/unstick.tl: reset issues stuck in "doing" state
--
-- deterministic script that queries issues labeled "doing",
-- checks when the label was applied, and resets stale ones
-- (>24h) back to "todo" with a comment.
--
-- CLI: cosmic unstick.tl <output_file>
-- reads WORK_REPO from environment.

local child = require("cosmic.child")
local cio = require("cosmic.io")
local json = require("cosmic.json")

local STALE_HOURS = 24

-- query issues labeled "doing" with their label timeline events
local QUERY = [[
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    issues(first: 100, after: $cursor, states: OPEN, labels: ["doing"]) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number
        title
        url
        timelineItems(itemTypes: [LABELED_EVENT], last: 50) {
          nodes {
            ... on LabeledEvent {
              createdAt
              label { name }
            }
          }
        }
      }
    }
  }
}
]]

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {stderr = 1})
  if not h then
    return false, err or "spawn failed", -1
  end
  local ok, out, code = h:read()
  return ok, out, code
end

-- parse ISO 8601 timestamp to unix epoch (UTC)
local function parse_iso8601(s: string): number
  local y, m, d, h, min, sec = s:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then return 0 end
  -- os.time interprets as local time; we need UTC.
  -- compute offset and adjust.
  local utc_t: os.DateTable = {
    year = tonumber(y) as integer,
    month = tonumber(m) as integer,
    day = tonumber(d) as integer,
    hour = tonumber(h) as integer,
    min = tonumber(min) as integer,
    sec = tonumber(sec) as integer,
  }
  local t = os.time(utc_t)
  -- find the offset between local and UTC
  local local_dt = os.date("*t", t) as os.DateTable
  local utc_dt = os.date("!*t", t) as os.DateTable
  local offset = os.time(local_dt) - os.time(utc_dt)
  return t - offset
end

local function fetch_doing_issues(owner: string, name: string): {any}, string
  local all_issues: {any} = {}
  local cursor: string = ""
  local has_cursor = false

  for _ = 1, 10 do
    local argv: {string} = {
      "gh", "api", "graphql",
      "-f", "query=" .. QUERY,
      "-f", "owner=" .. owner,
      "-f", "name=" .. name,
    }
    if has_cursor then
      argv[#argv + 1] = "-f"
      argv[#argv + 1] = "cursor=" .. cursor
    end

    local ok, out, code = run(argv)
    if not ok then
      if code == 4 then
        return {}, "error: gh access denied (exit 4): " .. (out or "")
      end
      return {}, "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    local resp = json.decode(out or "{}") as {string: any}
    if not resp or not resp.data then
      return {}, "error: failed to parse graphql response"
    end

    local data = resp.data as {string: any}
    local repository = data.repository as {string: any}
    local issues_conn = repository.issues as {string: any}
    local nodes = issues_conn.nodes as {any}

    for _, node_any in ipairs(nodes) do
      all_issues[#all_issues + 1] = node_any
    end

    local page_info = issues_conn.pageInfo as {string: any}
    if not (page_info.hasNextPage as boolean) then
      break
    end
    cursor = page_info.endCursor as string
    has_cursor = true
  end

  return all_issues, nil
end

local function find_doing_labeled_at(node: {string: any}): string
  local timeline = node.timelineItems as {string: any}
  local tl_nodes = timeline.nodes as {any}
  local latest = ""
  for _, ev_any in ipairs(tl_nodes) do
    local ev = ev_any as {string: any}
    local label = ev.label as {string: any}
    if label and (label.name as string) == "doing" then
      local created = ev.createdAt as string
      if created > latest then
        latest = created
      end
    end
  end
  return latest
end

local function comment_issue(repo: string, issue_number: number, body: string): boolean, string
  local tmp = os.tmpname()
  cio.barf(tmp, body)
  local ok, out, code = run({
      "gh", "issue", "comment", tostring(issue_number),
      "--repo", repo,
      "--body-file", tmp,
    })
  os.remove(tmp)
  if not ok then
    return false, "gh failed (exit " .. tostring(code) .. "): " .. (out or "")
  end
  return true, nil
end

local function set_labels(repo: string, issue_number: number, add: {string}, remove_labels: {string}): boolean, string
  local argv: {string} = {"gh", "issue", "edit", tostring(issue_number), "--repo", repo}
  for _, label in ipairs(add) do
    table.insert(argv, "--add-label")
    table.insert(argv, label)
  end
  for _, label in ipairs(remove_labels) do
    table.insert(argv, "--remove-label")
    table.insert(argv, label)
  end
  local ok, out, code = run(argv)
  if not ok then
    return false, "gh failed (exit " .. tostring(code) .. "): " .. (out or "")
  end
  return true, nil
end

local function execute(output_file: string): string
  local repo = os.getenv("WORK_REPO") or ""
  if repo == "" then
    return "error: WORK_REPO environment variable not set"
  end

  local owner, name = repo:match("^([^/]+)/([^/]+)$")
  if not owner or not name then
    return "error: WORK_REPO must be owner/name format"
  end

  local issues, fetch_err = fetch_doing_issues(owner, name)
  if fetch_err then
    return fetch_err
  end

  local now = os.time(os.date("!*t") as os.DateTable)
  -- adjust for UTC offset (same approach as parse_iso8601)
  local sample_local = os.date("*t", now) as os.DateTable
  local sample_utc = os.date("!*t", now) as os.DateTable
  local offset = os.time(sample_local) - os.time(sample_utc)
  now = now - offset

  local stale_seconds = STALE_HOURS * 3600
  local reset: {any} = {}

  for _, node_any in ipairs(issues) do
    local node = node_any as {string: any}
    local num = math.floor(node.number as number)
    local title = node.title as string
    local labeled_at = find_doing_labeled_at(node)

    if labeled_at == "" then
      -- no doing label event found; treat as stale
      labeled_at = "unknown"
    end

    local age_seconds: number = 0
    if labeled_at ~= "unknown" then
      local labeled_epoch = parse_iso8601(labeled_at)
      age_seconds = now - labeled_epoch
    else
      age_seconds = stale_seconds + 1 -- force stale
    end

    if age_seconds > stale_seconds then
      local hours = math.floor(age_seconds / 3600)
      local body = "Resetting from `doing` to `todo`: issue has been in `doing` state for "
      .. tostring(hours) .. "h (threshold: " .. tostring(STALE_HOURS) .. "h). "
      .. "This allows the work loop to pick it up again."

      local ok, err = comment_issue(repo, num, body)
      if not ok then
        io.stderr:write("comment #" .. tostring(num) .. " failed: " .. (err or "") .. "\n")
      end

      ok, err = set_labels(repo, num, {"todo"}, {"doing"})
      if not ok then
        io.stderr:write("labels #" .. tostring(num) .. " failed: " .. (err or "") .. "\n")
      end

      reset[#reset + 1] = {
        number = num,
        title = title,
        labeled_at = labeled_at,
        age_hours = hours,
      }
    end
  end

  local result = json.encode({
      repo = repo,
      doing_count = #issues,
      reset_count = #reset,
      reset = reset,
    })

  cio.barf(output_file, result)
  return "ok: reset " .. tostring(#reset) .. " of " .. tostring(#issues) .. " doing issues"
end

-- CLI entry point
local is_main = arg and (arg[0] or ""):find("/unstick%.tl$")
if is_main then
  if #arg < 1 then
    io.stderr:write("usage: cosmic unstick.tl <output_file>\n")
    os.exit(1)
  end
  local result = execute(arg[1])
  if result:match("^error:") then
    io.stderr:write(result .. "\n")
    os.exit(1)
  end
  print(result)
end

return {
  execute = execute,
  parse_iso8601 = parse_iso8601,
  find_doing_labeled_at = find_doing_labeled_at,
  STALE_HOURS = STALE_HOURS,
}
