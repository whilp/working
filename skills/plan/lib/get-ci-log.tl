-- skills/plan/lib/get-ci-log.tl: fetch CI failure logs for a commit
--
-- given a repo and commit sha, finds failing check runs and downloads
-- their logs. used by the ci-log make target to pre-fetch logs before
-- the plan agent starts.
--
-- reads WORK_REPO from environment.
-- CLI: cosmic get-ci-log.tl <sha> <output_file>
-- module tool: returns a Tool record

local child = require("cosmic.child")

local repo = os.getenv("WORK_REPO") or ""

local function execute(input: {string: any}): string
  local sha = input.sha as string
  local output_file = input.output_file as string

  if repo == "" then return "error: WORK_REPO environment variable not set" end
  if not sha or sha == "" then return "error: sha required" end
  if not output_file or output_file == "" then return "error: output_file required" end

  -- fetch check runs for this commit
  local _h_checks, _err_checks = child.spawn({
      "gh", "api", "repos/" .. repo .. "/commits/" .. sha .. "/check-runs",
      "--jq", ".check_runs[] | select(.conclusion == \"failure\") | .id",
    }, {stderr = 1})
  if not _h_checks then
    return "error: gh failed: " .. (_err_checks or "spawn failed")
  end
  local ok_checks, out_checks, code_checks = _h_checks:read()
  if not ok_checks then
    if code_checks == 4 then
      return "error: gh access denied (exit 4): " .. (out_checks or "")
    end
    return "error: gh check-runs failed (exit " .. tostring(code_checks) .. "): " .. (out_checks or "")
  end

  -- collect failing run IDs
  local run_ids: {string} = {}
  for id in (out_checks or ""):gmatch("[^\n]+") do
    local trimmed = id:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      run_ids[#run_ids + 1] = trimmed
    end
  end

  if #run_ids == 0 then
    local cio = require("cosmic.io")
    cio.barf(output_file, "")
    return "no failing check runs found"
  end

  -- for each failing check run, find the workflow run and download logs
  local logs: {string} = {}
  local seen_runs: {string: boolean} = {}

  for _, check_id in ipairs(run_ids) do
    local _h_detail, _err_detail = child.spawn({
        "gh", "api", "repos/" .. repo .. "/check-runs/" .. check_id,
        "--jq", ".details_url",
      }, {stderr = 1})
    local ok_detail, out_detail, _: boolean | string, string, number
    if not _h_detail then
      ok_detail = false
      out_detail = _err_detail or "spawn failed"
    else
      ok_detail, out_detail, _ = _h_detail:read()
    end
    if ok_detail and out_detail then
      local run_id = out_detail:match("/runs/(%d+)")
      if run_id and not seen_runs[run_id] then
        seen_runs[run_id] = true
        local _h_log, _err_log = child.spawn({
            "gh", "run", "view", run_id,
            "--repo", repo,
            "--log",
          }, {stderr = 1})
        local ok_log, out_log, _2: boolean | string, string, number
        if not _h_log then
          ok_log = false
          out_log = _err_log or "spawn failed"
        else
          ok_log, out_log, _2 = _h_log:read()
        end
        if ok_log and out_log then
          logs[#logs + 1] = out_log
        end
      end
    end
  end

  local result = table.concat(logs, "\n")
  local cio = require("cosmic.io")
  cio.barf(output_file, result)

  return "wrote " .. tostring(#result) .. " bytes to " .. output_file .. " from " .. tostring(#run_ids) .. " failing check(s)"
end

-- CLI entry point: cosmic get-ci-log.tl <sha> <output_file>
if arg and #arg >= 2 then
  local result = execute({sha = arg[1], output_file = arg[2]})
  if result:match("^error:") then
    io.stderr:write(result .. "\n")
    os.exit(1)
  end
  print(result)
end

return {
  name = "get_ci_log",
  description = "Fetch CI failure logs for a commit. Returns the full log output from failing check runs. Operates on the repo set by WORK_REPO.",
  input_schema = {
    type = "object",
    properties = {
      sha = {type = "string", description = "Commit SHA to check"},
      output_file = {type = "string", description = "Path to write log output"},
    },
    required = {"sha", "output_file"},
  },
  execute = execute,
}
