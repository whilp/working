#!/usr/bin/env cosmic
-- test_score.tl: tests for lib/eval/score.tl

local score = require("lib.eval.score")

local function test_weights()
  assert(score.WEIGHTS.minimality == 0.30, "minimality weight should be 0.30")
  assert(score.WEIGHTS.readability == 0.25, "readability weight should be 0.25")
  assert(score.WEIGHTS.robustness == 0.25, "robustness weight should be 0.25")
  assert(score.WEIGHTS.efficiency == 0.20, "efficiency weight should be 0.20")

  local total: number = 0
  for _, w in pairs(score.WEIGHTS) do
    total = total + w
  end
  assert(math.abs(total - 1.0) < 0.001, "weights should sum to 1.0: " .. tostring(total))
  print("✓ weights are correct and sum to 1.0")
end
test_weights()

local function test_quality_factor_perfect()
  local scores = {minimality = 1.0, readability = 1.0, robustness = 1.0, efficiency = 1.0}
  local qf = score.quality_factor(scores)
  assert(math.abs(qf - 1.0) < 0.001, "perfect scores should give qf=1.0: " .. tostring(qf))
  print("✓ quality_factor returns 1.0 for perfect scores")
end
test_quality_factor_perfect()

local function test_quality_factor_zeros()
  local scores = {minimality = 0, readability = 0.8, robustness = 0.8, efficiency = 0.8}
  local qf = score.quality_factor(scores)
  assert(qf == 0, "zero dimension should give qf=0: " .. tostring(qf))
  print("✓ quality_factor returns 0 when any dimension is 0")
end
test_quality_factor_zeros()

local function test_quality_factor_nil()
  local qf = score.quality_factor(nil)
  assert(qf == 0, "nil scores should give qf=0: " .. tostring(qf))
  print("✓ quality_factor returns 0 for nil input")
end
test_quality_factor_nil()

local function test_quality_factor_mixed()
  local scores = {minimality = 0.9, readability = 0.8, robustness = 0.7, efficiency = 0.9}
  local qf = score.quality_factor(scores)
  -- 0.9^0.30 * 0.8^0.25 * 0.7^0.25 * 0.9^0.20
  -- = 0.9692 * 0.9457 * 0.9147 * 0.9791 = ~0.821
  assert(qf > 0.8 and qf < 0.85, "mixed scores should give qf ~0.82: " .. tostring(qf))
  print("✓ quality_factor computes correct weighted geometric mean")
end
test_quality_factor_mixed()

local function test_quality_factor_missing_dimension()
  local scores = {minimality = 0.9, readability = 0.8, robustness = 0.7}
  local qf = score.quality_factor(scores)
  assert(qf == 0, "missing dimension should give qf=0: " .. tostring(qf))
  print("✓ quality_factor returns 0 when dimension is missing")
end
test_quality_factor_missing_dimension()

local function test_composite_success()
  local c = score.composite(1, 0.82, 30000, 50000)
  -- 1 * 0.82 / (30000/50000) = 0.82 / 0.6 = 1.367
  assert(c > 1.3 and c < 1.4, "composite should be ~1.37: " .. tostring(c))
  print("✓ composite computes correct value for successful task")
end
test_composite_success()

local function test_composite_failure()
  local c = score.composite(0, 0.82, 30000, 50000)
  assert(c == 0, "failed task should give composite=0: " .. tostring(c))
  print("✓ composite returns 0 for failed task")
end
test_composite_failure()

local function test_composite_zero_budget()
  local c = score.composite(1, 0.82, 30000, 0)
  assert(c == 0, "zero budget should give composite=0: " .. tostring(c))
  print("✓ composite returns 0 for zero budget")
end
test_composite_zero_budget()

local function test_composite_zero_quality()
  local c = score.composite(1, 0, 30000, 50000)
  assert(c == 0, "zero quality should give composite=0: " .. tostring(c))
  print("✓ composite returns 0 for zero quality")
end
test_composite_zero_quality()

local function test_parse_judge_valid()
  local raw = '{"correctness":"pass","minimality":0.9,"readability":0.8,"robustness":0.7,"efficiency":0.9}'
  local parsed = score.parse_judge(raw)
  assert(parsed, "should parse valid JSON")
  assert((parsed["correctness"] as string) == "pass", "correctness should be pass")
  assert((parsed["minimality"] as number) == 0.9, "minimality should be 0.9")
  print("✓ parse_judge parses valid JSON")
end
test_parse_judge_valid()

local function test_parse_judge_empty()
  assert(score.parse_judge("") == nil, "empty string should return nil")
  assert(score.parse_judge(nil) == nil, "nil should return nil")
  print("✓ parse_judge returns nil for empty/nil input")
end
test_parse_judge_empty()

local function test_parse_judge_invalid()
  assert(score.parse_judge("not json") == nil, "invalid JSON should return nil")
  print("✓ parse_judge returns nil for invalid JSON")
end
test_parse_judge_invalid()

local function test_score_task_pass()
  local judge = '{"correctness":"pass","minimality":0.9,"readability":0.8,"robustness":0.7,"efficiency":0.9}'
  local result = score.score_task(judge, 30000, 50000)
  assert(result.quality_factor > 0.8, "qf should be >0.8: " .. tostring(result.quality_factor))
  assert(result.composite > 0, "composite should be >0: " .. tostring(result.composite))
  print("✓ score_task returns correct scores for passing task")
end
test_score_task_pass()

local function test_score_task_fail()
  local judge = '{"correctness":"fail","minimality":0.9,"readability":0.8,"robustness":0.7,"efficiency":0.9}'
  local result = score.score_task(judge, 30000, 50000)
  assert(result.quality_factor == 0, "qf should be 0 for failed task: " .. tostring(result.quality_factor))
  assert(result.composite == 0, "composite should be 0 for failed task: " .. tostring(result.composite))
  print("✓ score_task returns 0 for failed correctness gate")
end
test_score_task_fail()

local function test_score_task_nil_judge()
  local result = score.score_task(nil, 30000, 50000)
  assert(result.quality_factor == 0, "qf should be 0: " .. tostring(result.quality_factor))
  assert(result.composite == 0, "composite should be 0: " .. tostring(result.composite))
  print("✓ score_task returns 0 for nil judge output")
end
test_score_task_nil_judge()

print("\nAll score tests passed!")
