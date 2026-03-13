-- lib/eval/score.tl: compute quality_factor and composite score
--
-- quality_factor is a weighted geometric mean of judge dimension scores.
-- composite score rewards completing tasks correctly, with high quality,
-- using fewer resources.
--
-- quality_factor = minimality^0.30 * readability^0.25 * robustness^0.25 * efficiency^0.20
-- composite = task_success * quality_factor / cost_factor
--
-- if correctness fails (gate), quality_factor = 0.
-- if any dimension is 0, quality_factor = 0.

local json = require("cosmic.json")

local record ScoreModule
  WEIGHTS: {string: number}
  quality_factor: function(scores: {string: number}): number
  composite: function(task_success: number, quality: number, tokens: number, budget: number): number
  parse_judge: function(raw: string): {string: any}
  score_task: function(judge_json: string, tokens: number, budget: number): {string: number}
end

local M: ScoreModule = {}

M.WEIGHTS = {
  minimality = 0.30,
  readability = 0.25,
  robustness = 0.25,
  efficiency = 0.20,
}

function M.quality_factor(scores: {string: number}): number
  if not scores then return 0 end
  local result = 1.0
  for dim, weight in pairs(M.WEIGHTS) do
    local val = scores[dim]
    if not val or val <= 0 then return 0 end
    result = result * (val ^ weight)
  end
  return result
end

function M.composite(task_success: number, quality: number, tokens: number, budget: number): number
  if task_success == 0 then return 0 end
  if quality <= 0 then return 0 end
  if budget <= 0 then return 0 end
  local cost_factor = tokens / budget
  if cost_factor <= 0 then return 0 end
  return task_success * quality / cost_factor
end

function M.parse_judge(raw: string): {string: any}
  if not raw or raw == "" then return nil end
  local ok, result = pcall(json.decode, raw)
  if not ok then return nil end
  return result as {string: any}
end

function M.score_task(judge_json: string, tokens: number, budget: number): {string: number}
  local parsed = M.parse_judge(judge_json)
  if not parsed then
    return {quality_factor = 0, composite = 0}
  end

  local correctness = parsed["correctness"] as string
  if correctness ~= "pass" then
    return {quality_factor = 0, composite = 0}
  end

  local scores: {string: number} = {
    minimality = (parsed["minimality"] as number) or 0,
    readability = (parsed["readability"] as number) or 0,
    robustness = (parsed["robustness"] as number) or 0,
    efficiency = (parsed["efficiency"] as number) or 0,
  }

  local qf = M.quality_factor(scores)
  local comp = M.composite(1, qf, tokens, budget)

  return {
    quality_factor = qf,
    composite = comp,
    minimality = scores.minimality,
    readability = scores.readability,
    robustness = scores.robustness,
    efficiency = scores.efficiency,
  }
end

return M
