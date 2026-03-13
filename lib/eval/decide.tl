-- lib/eval/decide.tl: keep/discard decision logic
--
-- implements the autoresearch-inspired ratchet:
-- - improvements must exceed noise threshold
-- - complexity additions must earn their place via complexity_tax
-- - simplifications at equal performance are always kept
-- - equal performance + more complexity is always discarded

local record DecideModule
  NOISE_THRESHOLD: number
  BASE_TAX: number
  complexity_tax: function(delta: number): number
  decide: function(new_score: number, best_score: number, complexity_delta: number): string, string
end

local M: DecideModule = {}

M.NOISE_THRESHOLD = 0.005
M.BASE_TAX = 0.01

function M.complexity_tax(delta: number): number
  return M.BASE_TAX * math.log(1 + math.abs(delta))
end

function M.decide(new_score: number, best_score: number, complexity_delta: number): string, string
  local diff = new_score - best_score

  if diff > M.NOISE_THRESHOLD then
    if complexity_delta <= 0 then
      return "keep", "better and simpler"
    end
    local tax = M.complexity_tax(complexity_delta)
    if diff > tax then
      return "keep", "improvement justifies complexity"
    end
    return "discard", "improvement too small for complexity cost"
  elseif math.abs(diff) <= M.NOISE_THRESHOLD then
    if complexity_delta < 0 then
      return "keep", "simpler at equal performance"
    end
    return "discard", "equal performance with more complexity"
  else
    return "discard", "worse"
  end
end

return M
