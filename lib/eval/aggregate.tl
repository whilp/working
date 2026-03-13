-- lib/eval/aggregate.tl: aggregate per-task eval scores
--
-- reads score files from a results directory, computes aggregate metrics:
-- pass_rate, mean_quality, mean_tokens, composite_score.
--
-- usage: cosmic lib/eval/aggregate.tl <results_dir> <output_file>

local json = require("cosmic.json")
local cio = require("cosmic.io")

local record AggregateModule
  aggregate: function(scores: {{string: any}}): {string: number}
end

local M: AggregateModule = {}

function M.aggregate(scores: {{string: any}}): {string: number}
  if not scores or #scores == 0 then
    return {
      pass_rate = 0,
      mean_quality = 0,
      mean_tokens = 0,
      mean_composite = 0,
      task_count = 0,
    }
  end

  local n = #scores
  local passes = 0
  local total_quality = 0.0
  local total_tokens = 0.0
  local total_composite = 0.0

  for _, s in ipairs(scores) do
    local qf = (s["quality_factor"] as number) or 0
    local comp = (s["composite"] as number) or 0
    local tokens = (s["tokens"] as number) or 0
    local pass = (s["correctness"] as string) == "pass"

    if pass then passes = passes + 1 end
    total_quality = total_quality + qf
    total_tokens = total_tokens + tokens
    total_composite = total_composite + comp
  end

  return {
    pass_rate = passes / n,
    mean_quality = total_quality / n,
    mean_tokens = total_tokens / n,
    mean_composite = total_composite / n,
    task_count = n,
  }
end

-- script mode: read score files from results dir, write aggregate
if arg and arg[1] then
  local results_dir = arg[1]
  local output_file = arg[2]

  if not output_file then
    io.stderr:write("usage: cosmic lib/eval/aggregate.tl <results_dir> <output_file>\n")
    os.exit(1)
  end

  local child = require("cosmic.child")
  local h, err = child.spawn({"find", results_dir, "-name", "score.json", "-type", "f"}, {stderr = 1})
  if not h then
    io.stderr:write("error: find failed: " .. (err or "spawn failed") .. "\n")
    os.exit(1)
  end
  local ok, out, _ = h:read()
  if not ok then
    io.stderr:write("error: find failed\n")
    os.exit(1)
  end

  local scores: {{string: any}} = {}
  for path in (out or ""):gmatch("[^\n]+") do
    local raw = cio.slurp(path)
    if raw and raw ~= "" then
      local parsed = json.decode(raw) as {string: any}
      if parsed then
        scores[#scores + 1] = parsed
      end
    end
  end

  local result = M.aggregate(scores)
  local encoded = json.encode(result)
  cio.barf(output_file, encoded)
  print("pass_rate=" .. result.pass_rate .. " mean_quality=" .. result.mean_quality .. " mean_composite=" .. result.mean_composite .. " tasks=" .. result.task_count)
end

return M
