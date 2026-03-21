-- skills/reflect/lib/analyze-runs.tl: launch sandboxed agents to analyze workflow runs
--
-- reads manifest.json from the fetch directory. spawns one ah agent per run.
-- each agent produces an analysis markdown file.
--
-- usage: cosmic skills/reflect/lib/analyze-runs.tl <fetch_dir> <analyze_dir> <ah_path>

local json = require("cosmic.json")
local child = require("cosmic.child")
local cio = require("cosmic.io")
local fs = require("cosmic.fs")

local fetch_dir = arg[1]
local analyze_dir = arg[2]
local ah = arg[3]

if not fetch_dir or not analyze_dir or not ah then
  io.stderr:write("usage: analyze-runs.tl <fetch_dir> <analyze_dir> <ah_path>\n")
  os.exit(1)
end

local manifest_path = fetch_dir .. "/manifest.json"
local manifest_raw = cio.slurp(manifest_path)
if not manifest_raw then
  io.stderr:write("error: cannot read " .. manifest_path .. "\n")
  os.exit(1)
end

local manifest = json.decode(manifest_raw) as {any}
if not manifest then
  io.stderr:write("error: cannot parse manifest\n")
  os.exit(1)
end

-- filter to runs that have logs
local runs: {{string: any}} = {}
for _, entry in ipairs(manifest) do
  local r = entry as {string: any}
  if r["log_file"] then
    runs[#runs + 1] = r
  end
end

print("  " .. tostring(#runs) .. " runs to analyze")
io.flush()

local failed = 0
local skipped = 0
for _, r in ipairs(runs) do
  local rid = tostring(r.databaseId as number)
  local out = analyze_dir .. "/" .. rid .. ".md"
  local run_dir = fetch_dir .. "/" .. rid
  local wf = r.workflowName as string or "?"
  local conclusion = r.conclusion as string or "?"

  -- skip if already analyzed
  if fs.isfile(out) then
    print("  -- " .. rid .. ": " .. wf .. " (skipped, already analyzed)")
    io.flush()
    skipped = skipped + 1
  else
    print("  -> " .. rid .. ": " .. wf .. " (" .. conclusion .. ")")
    io.flush()

    local meta = json.encode(r)
    local stdin_str = "PHASE=analyze-run RUN_DIR=" .. run_dir
    .. " RUN_META=" .. meta .. " OUTPUT_FILE=" .. out

    -- timeout 60s per run — these are sandboxed read-only analyses
    local h, err = child.spawn({
        "timeout", "60", ah,
        "-n", "-m", "sonnet",
        "--sandbox",
        "--skill", "reflect",
        "--must-produce", out,
        "--max-tokens", "80000",
        "--db", analyze_dir .. "/session-" .. rid .. ".db",
        "--unveil", run_dir .. ":r",
        "--unveil", analyze_dir .. ":rwc",
        "--unveil", ".:r",
      }, {stdin = stdin_str, stderr = 1})

    if not h then
      print("  !! " .. rid .. " spawn failed: " .. (err or ""))
      io.flush()
      failed = failed + 1
    else
      local ok, _, code = h:read()
      if not ok then
        print("  !! " .. rid .. " failed (exit " .. tostring(code) .. ")")
        io.flush()
        failed = failed + 1
      end
    end
  end
end

local analyzed = #runs - failed - skipped
print("  done: " .. tostring(analyzed) .. " analyzed, "
  .. tostring(skipped) .. " skipped, "
  .. tostring(failed) .. " failed"
  .. " (of " .. tostring(#runs) .. ")")
