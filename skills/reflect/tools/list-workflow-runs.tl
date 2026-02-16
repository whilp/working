-- skills/reflect/tools/list-workflow-runs.tl: list workflow runs in a date range
--
-- fetches action runs and optionally downloads logs and artifacts.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local unix = require("cosmo.unix")
local json = require("cosmic.json")

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
  name = "list_workflow_runs",
  description = "List GitHub Actions workflow runs in a date range and optionally download their logs and artifacts. Returns JSON array of runs with metadata.",
  input_schema = {
    type = "object",
    properties = {
      repo = {type = "string", description = "GitHub repository (owner/repo)"},
      since = {type = "string", description = "Start date (YYYY-MM-DD)"},
      until_ = {type = "string", description = "End date inclusive (YYYY-MM-DD)"},
      output_dir = {type = "string", description = "Directory to download logs and artifacts into"},
      workflow = {type = "string", description = "Filter by workflow name (optional)"},
    },
    required = {"repo", "since", "until_", "output_dir"},
  },
  execute = function(input: {string: any}): string
    local repo = input.repo as string
    local since = input.since as string
    local until_ = input.until_ as string
    local output_dir = input.output_dir as string
    local workflow = input.workflow as string

    if not repo or repo == "" then return "error: repo required" end
    if not since or since == "" then return "error: since required" end
    if not until_ or until_ == "" then return "error: until_ required" end
    if not output_dir or output_dir == "" then return "error: output_dir required" end

    -- validate date formats
    if not since:match("^%d%d%d%d%-%d%d%-%d%d$") then
      return "error: since must be YYYY-MM-DD format"
    end
    if not until_:match("^%d%d%d%d%-%d%d%-%d%d$") then
      return "error: until_ must be YYYY-MM-DD format"
    end

    local owner, name = repo:match("^([^/]+)/([^/]+)$")
    if not owner or not name then
      return "error: repo must be owner/name format"
    end

    -- create output directory
    local ok_mkdir, err_mkdir, _ = run({"mkdir", "-p", output_dir})
    if not ok_mkdir then
      return "error: mkdir failed: " .. (err_mkdir or "")
    end

    -- list runs in date range using --created filter
    local created_range = since .. ".." .. until_
    local list_argv: {string} = {
      "gh", "run", "list",
      "--repo", repo,
      "--created", created_range,
      "--limit", "200",
      "--json", "databaseId,displayTitle,conclusion,createdAt,event,headBranch,name,number,startedAt,status,updatedAt,url,workflowName,attempt",
    }
    if workflow and workflow ~= "" then
      list_argv[#list_argv + 1] = "--workflow"
      list_argv[#list_argv + 1] = workflow
    end

    local ok_list, out_list, code_list = run(list_argv)
    if not ok_list then
      return "error: gh run list failed (exit " .. tostring(code_list) .. "): " .. (out_list or "")
    end

    local runs = json.decode(out_list or "[]") as {any}
    if not runs then
      return "error: failed to parse run list"
    end

    -- download logs and artifacts for each run
    local results: {any} = {}
    for _, run_any in ipairs(runs) do
      local r = run_any as {string: any}
      local run_id = tostring(r.databaseId as number)
      local run_dir = output_dir .. "/" .. run_id

      run({"mkdir", "-p", run_dir})

      -- download logs
      local log_file = run_dir .. "/log.txt"
      local ok_log, out_log, code_log = run({
        "gh", "run", "view", run_id,
        "--repo", repo,
        "--log",
      })
      if ok_log then
        local cio = require("cosmic.io")
        cio.barf(log_file, out_log or "")
        r["log_file"] = log_file
      else
        r["log_error"] = "exit " .. tostring(code_log) .. ": " .. (out_log or "")
      end

      -- download artifacts
      local artifact_dir = run_dir .. "/artifacts"
      local ok_art, out_art, code_art = run({
        "gh", "run", "download", run_id,
        "--repo", repo,
        "--dir", artifact_dir,
      })
      if ok_art then
        r["artifact_dir"] = artifact_dir
      else
        -- no artifacts is common, not an error
        r["artifact_note"] = "exit " .. tostring(code_art) .. ": " .. (out_art or "")
      end

      results[#results + 1] = r
    end

    -- write manifest
    local manifest = json.encode(results)
    local cio = require("cosmic.io")
    cio.barf(output_dir .. "/manifest.json", manifest)

    return manifest
  end,
}
