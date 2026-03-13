-- lib/eval/run-task.tl: run a single eval task
--
-- sets up a clean environment from a task definition, runs ah with
-- the task prompt, captures results (diff, tokens, time).
--
-- usage: cosmic lib/eval/run-task.tl <task_dir> <ah_binary> <output_dir>
--
-- task_dir must contain:
--   prompt.md   — task description
--   repo.bundle — git bundle of starting repo state (optional)
--
-- output_dir will contain:
--   repo/       — task repo after agent ran
--   diff.txt    — git diff of changes
--   session.db  — ah session database
--   result.json — tokens, time, exit code

local child = require("cosmic.child")
local cio = require("cosmic.io")
local json = require("cosmic.json")

local task_dir = arg[1]
local ah_binary = arg[2]
local output_dir = arg[3]

if not task_dir or not ah_binary or not output_dir then
  io.stderr:write("usage: cosmic lib/eval/run-task.tl <task_dir> <ah_binary> <output_dir>\n")
  os.exit(1)
end

local function run(argv: {string}): boolean, string, number
  local h, err = child.spawn(argv, {stderr = 1})
  if not h then
    return false, err or "spawn failed", -1
  end
  local ok, out, code = h:read()
  return ok as boolean, out, code
end

-- validate task directory
local prompt_file = task_dir .. "/prompt.md"
local bundle_file = task_dir .. "/repo.bundle"

local prompt = cio.slurp(prompt_file)
if not prompt or prompt == "" then
  io.stderr:write("error: missing or empty " .. prompt_file .. "\n")
  os.exit(1)
end

-- create output directory
run({"mkdir", "-p", output_dir})

-- set up repo from bundle (if bundle exists)
local repo_dir = output_dir .. "/repo"
local has_bundle, _, _ = run({"test", "-f", bundle_file})

if has_bundle then
  local ok_clone, out_clone, _ = run({"git", "clone", bundle_file, repo_dir})
  if not ok_clone then
    io.stderr:write("error: git clone failed: " .. (out_clone or "") .. "\n")
    os.exit(1)
  end
else
  run({"mkdir", "-p", repo_dir})
  run({"git", "init", repo_dir})
end

-- record start time
local start = os.time()

-- read token budget from config if available
local config_file = task_dir .. "/config.json"
local max_tokens: number = 50000
local timeout_secs: number = 300
local config_raw = cio.slurp(config_file)
if config_raw and config_raw ~= "" then
  local ok_cfg, config = pcall(json.decode, config_raw)
  if ok_cfg and config then
    local cfg = config as {string: any}
    if cfg["max_tokens"] then max_tokens = cfg["max_tokens"] as number end
    if cfg["timeout"] then timeout_secs = cfg["timeout"] as number end
  end
end

-- run ah with task prompt
local session_db = output_dir .. "/session.db"
local ah_argv: {string} = {
  "timeout", tostring(timeout_secs),
  ah_binary, "-n",
  "-m", "sonnet",
  "--sandbox",
  "--max-tokens", tostring(max_tokens),
  "--db", session_db,
  "--unveil", repo_dir .. ":rwcx",
  "--unveil", output_dir .. ":rwc",
}

-- write prompt to temp file for stdin
local prompt_tmp = os.tmpname()
cio.barf(prompt_tmp, prompt)

local h_ah, err_ah = child.spawn(ah_argv, {stderr = 1, stdin = prompt_tmp})
os.remove(prompt_tmp)

local exit_code: number = -1
if not h_ah then
  io.stderr:write("error: ah spawn failed: " .. (err_ah or "") .. "\n")
else
  local ok_ah, _, code_ah = h_ah:read()
  if ok_ah then
    exit_code = 0
  else
    exit_code = code_ah or 1
  end
end

-- record end time
local elapsed = os.time() - start

-- capture diff
local diff_file = output_dir .. "/diff.txt"
local ok_diff, out_diff, _ = run({"git", "-C", repo_dir, "diff", "HEAD~1..HEAD"})
if ok_diff and out_diff then
  cio.barf(diff_file, out_diff)
else
  local ok2, out2, _ = run({"git", "-C", repo_dir, "diff"})
  if ok2 and out2 then cio.barf(diff_file, out2) end
end

-- write result metadata
local result = {
  task = task_dir,
  exit_code = exit_code,
  elapsed_s = elapsed,
  max_tokens = max_tokens,
  timeout = timeout_secs,
}
local encoded = json.encode(result)
cio.barf(output_dir .. "/result.json", encoded)

-- summary
local status = exit_code == 0 and "success" or "exit_" .. tostring(exit_code)
print("task=" .. task_dir .. " status=" .. status .. " elapsed=" .. tostring(elapsed) .. "s")
os.exit(exit_code == 0 and 0 or 1)
