-- lib/eval/judge-task.tl: run the judge on a completed eval task
--
-- invokes ah with the judge skill to score the agent's work.
-- reads task expectations and actual results, writes score.json.
--
-- usage: cosmic lib/eval/judge-task.tl <task_dir> <result_dir> <ah_binary> <output_file>

local child = require("cosmic.child")
local cio = require("cosmic.io")
local json = require("cosmic.json")
local score_mod = require("lib.eval.score")

local task_dir = arg[1]
local result_dir = arg[2]
local ah_binary = arg[3]
local output_file = arg[4]

if not task_dir or not result_dir or not ah_binary or not output_file then
  io.stderr:write("usage: cosmic lib/eval/judge-task.tl <task_dir> <result_dir> <ah_binary> <output_file>\n")
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

local function write_error(msg: string)
  local encoded = json.encode({quality_factor = 0, composite = 0, error = msg})
  cio.barf(output_file, encoded)
end

-- read task expectations
local expect_file = task_dir .. "/expect.md"
local expect = cio.slurp(expect_file)
if not expect or expect == "" then
  io.stderr:write("error: missing or empty " .. expect_file .. "\n")
  os.exit(1)
end

-- read result metadata for token budget
local result_file = result_dir .. "/result.json"
local result_raw = cio.slurp(result_file)
local max_tokens: number = 50000
if result_raw and result_raw ~= "" then
  local ok_parse, parsed = pcall(json.decode, result_raw)
  if ok_parse and parsed then
    local r = parsed as {string: any}
    if r["max_tokens"] then max_tokens = r["max_tokens"] as number end
  end
end

-- prepare judge workspace
local judge_dir = result_dir .. "/judge"
run({"mkdir", "-p", judge_dir})

-- copy task files into judge workspace for the judge agent
run({"cp", task_dir .. "/prompt.md", judge_dir .. "/prompt.md"})
run({"cp", expect_file, judge_dir .. "/expect.md"})

local diff_src = result_dir .. "/diff.txt"
local has_diff, _, _ = run({"test", "-f", diff_src})
if has_diff then
  run({"cp", diff_src, judge_dir .. "/diff.txt"})
end

-- run judge via ah
local judge_output = judge_dir .. "/score.json"
local judge_argv: {string} = {
  "timeout", "120",
  ah_binary, "-n",
  "-m", "sonnet",
  "--sandbox",
  "--skill-file", "eval/judge.md",
  "--must-produce", judge_output,
  "--max-tokens", "20000",
  "--db", judge_dir .. "/session.db",
  "--unveil", judge_dir .. ":rwc",
  "--unveil", result_dir .. "/repo:r",
}

local h_ah, err_ah = child.spawn(judge_argv, {stderr = 1})
if not h_ah then
  io.stderr:write("error: judge spawn failed: " .. (err_ah or "") .. "\n")
  write_error("judge spawn failed")
  os.exit(1)
end

local ok_ah, _, code_ah = h_ah:read()
if not ok_ah then
  io.stderr:write("error: judge failed (exit " .. tostring(code_ah) .. ")\n")
  write_error("judge failed")
  os.exit(1)
end

-- read judge output and compute scores
local judge_raw = cio.slurp(judge_output)
if not judge_raw or judge_raw == "" then
  io.stderr:write("error: judge produced no output\n")
  write_error("no judge output")
  os.exit(1)
end

-- estimate tokens used (from result.json if available)
local tokens_used: number = max_tokens
if result_raw and result_raw ~= "" then
  local ok_r, parsed_r = pcall(json.decode, result_raw)
  if ok_r and parsed_r then
    local r = parsed_r as {string: any}
    if r["tokens_used"] then tokens_used = r["tokens_used"] as number end
  end
end

local scores = score_mod.score_task(judge_raw, tokens_used, max_tokens)

-- build output with scores and judge metadata
local output: {string: any} = {}
for k, v in pairs(scores) do
  output[k] = v
end
output["tokens"] = tokens_used

local judge_parsed = score_mod.parse_judge(judge_raw)
if judge_parsed then
  output["correctness"] = judge_parsed["correctness"]
  if judge_parsed["reasoning"] then
    output["reasoning"] = judge_parsed["reasoning"]
  end
end

local encoded = json.encode(output)
cio.barf(output_file, encoded)
print("quality_factor=" .. tostring(scores["quality_factor"]) .. " composite=" .. tostring(scores["composite"]))
