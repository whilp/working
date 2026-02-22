-- skills/reflect/tools/get-workflow-runs.tl: get workflow runs in a date range
--
-- fetches action runs and downloads logs and artifacts.
-- reads WORK_REPO from environment to limit scope.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local json = require("cosmic.json")

local repo = os.getenv("WORK_REPO") or ""

return {
  name = "get_workflow_runs",
  description = "Get GitHub Actions workflow runs in a date range, downloading their logs and artifacts. Operates on the repo set by WORK_REPO. Returns JSON array of runs with metadata.",
  input_schema = {
    type = "object",
    properties = {
      since = {type = "string", description = "Start date (YYYY-MM-DD)"},
      until_ = {type = "string", description = "End date inclusive (YYYY-MM-DD)"},
      output_dir = {type = "string", description = "Directory to download logs and artifacts into"},
      workflow = {type = "string", description = "Filter by workflow name (optional)"},
    },
    required = {"since", "until_", "output_dir"},
  },
  execute = function(input: {string: any}): string
    local since = input.since as string
    local until_ = input.until_ as string
    local output_dir = input.output_dir as string
    local workflow = input.workflow as string

    if repo == "" then return "error: WORK_REPO environment variable not set" end
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
      return "error: WORK_REPO must be owner/name format"
    end

    -- create output directory
    local h, err = child.spawn({"mkdir", "-p", output_dir}, {stderr = 1})
    if not h then
      return "error: mkdir failed: " .. (err or "spawn failed")
    end
    local ok_mkdir, err_mkdir, _ = h:read()
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

    local h_list, err_list = child.spawn(list_argv, {stderr = 1})
    if not h_list then
      return "error: gh run list failed: " .. (err_list or "spawn failed")
    end
    local ok_list, out_list, code_list = h_list:read()
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

      local h_dir = child.spawn({"mkdir", "-p", run_dir}, {stderr = 1})
      if h_dir then h_dir:read() end

      -- download logs
      local log_file = run_dir .. "/log.txt"
      local h_log = child.spawn({
          "gh", "run", "view", run_id,
          "--repo", repo,
          "--log",
        }, {stderr = 1})
      if h_log then
        local ok_log, out_log, code_log = h_log:read()
        if ok_log then
          local cio = require("cosmic.io")
          cio.barf(log_file, out_log or "")
          r["log_file"] = log_file
        else
          r["log_error"] = "exit " .. tostring(code_log) .. ": " .. (out_log or "")
        end
      else
        r["log_error"] = "spawn failed"
      end

      -- download artifacts
      local artifact_dir = run_dir .. "/artifacts"
      local h_art = child.spawn({
          "gh", "run", "download", run_id,
          "--repo", repo,
          "--dir", artifact_dir,
        }, {stderr = 1})
      if h_art then
        local ok_art, out_art, code_art = h_art:read()
        if ok_art then
          r["artifact_dir"] = artifact_dir
        else
          -- no artifacts is common, not an error
          r["artifact_note"] = "exit " .. tostring(code_art) .. ": " .. (out_art or "")
        end
      else
        r["artifact_note"] = "spawn failed"
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
