#!/usr/bin/env cosmic
-- test_aggregate.tl: tests for lib/eval/aggregate.tl

local aggregate = require("lib.eval.aggregate")

local function test_empty()
  local result = aggregate.aggregate({})
  assert(result.pass_rate == 0, "empty should give 0 pass_rate")
  assert(result.mean_quality == 0, "empty should give 0 mean_quality")
  assert(result.mean_composite == 0, "empty should give 0 mean_composite")
  assert(result.task_count == 0, "empty should give 0 task_count")
  print("✓ aggregate handles empty input")
end
test_empty()

local function test_nil()
  local result = aggregate.aggregate(nil)
  assert(result.task_count == 0, "nil should give 0 task_count")
  print("✓ aggregate handles nil input")
end
test_nil()

local function test_single_pass()
  local scores = {
    {correctness = "pass", quality_factor = 0.82, composite = 1.37, tokens = 30000},
  }
  local result = aggregate.aggregate(scores)
  assert(result.pass_rate == 1.0, "single pass should give 1.0 pass_rate: " .. tostring(result.pass_rate))
  assert(math.abs(result.mean_quality - 0.82) < 0.01, "mean_quality should be 0.82: " .. tostring(result.mean_quality))
  assert(result.task_count == 1, "should have 1 task")
  print("✓ aggregate handles single passing task")
end
test_single_pass()

local function test_single_fail()
  local scores = {
    {correctness = "fail", quality_factor = 0, composite = 0, tokens = 40000},
  }
  local result = aggregate.aggregate(scores)
  assert(result.pass_rate == 0, "single fail should give 0 pass_rate: " .. tostring(result.pass_rate))
  assert(result.mean_quality == 0, "mean_quality should be 0: " .. tostring(result.mean_quality))
  assert(result.task_count == 1, "should have 1 task")
  print("✓ aggregate handles single failing task")
end
test_single_fail()

local function test_mixed()
  local scores = {
    {correctness = "pass", quality_factor = 0.90, composite = 1.50, tokens = 20000},
    {correctness = "pass", quality_factor = 0.70, composite = 1.00, tokens = 40000},
    {correctness = "fail", quality_factor = 0, composite = 0, tokens = 50000},
  }
  local result = aggregate.aggregate(scores)
  local expected_pass_rate = 2 / 3
  assert(math.abs(result.pass_rate - expected_pass_rate) < 0.01, "pass_rate should be 2/3: " .. tostring(result.pass_rate))
  local expected_mean_quality = (0.90 + 0.70 + 0) / 3
  assert(math.abs(result.mean_quality - expected_mean_quality) < 0.01, "mean_quality: " .. tostring(result.mean_quality))
  local expected_mean_tokens = (20000 + 40000 + 50000) / 3
  assert(math.abs(result.mean_tokens - expected_mean_tokens) < 1, "mean_tokens: " .. tostring(result.mean_tokens))
  assert(result.task_count == 3, "should have 3 tasks")
  print("✓ aggregate handles mixed pass/fail tasks")
end
test_mixed()

print("\nAll aggregate tests passed!")
