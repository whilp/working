#!/usr/bin/env cosmic
-- test_decide.tl: tests for lib/eval/decide.tl

local decide = require("lib.eval.decide")

local function test_thresholds()
  assert(decide.NOISE_THRESHOLD == 0.005, "noise threshold should be 0.005")
  assert(decide.BASE_TAX == 0.01, "base tax should be 0.01")
  print("✓ thresholds are correct")
end
test_thresholds()

local function test_complexity_tax_zero()
  local tax = decide.complexity_tax(0)
  assert(tax == 0, "zero delta should give zero tax: " .. tostring(tax))
  print("✓ complexity_tax returns 0 for zero delta")
end
test_complexity_tax_zero()

local function test_complexity_tax_positive()
  local tax = decide.complexity_tax(50)
  -- 0.01 * ln(51) = 0.01 * 3.932 = 0.03932
  assert(tax > 0.03 and tax < 0.05, "tax for delta=50 should be ~0.039: " .. tostring(tax))
  print("✓ complexity_tax scales logarithmically with delta")
end
test_complexity_tax_positive()

local function test_complexity_tax_negative()
  -- uses abs(delta), so negative gives same result
  local pos = decide.complexity_tax(50)
  local neg = decide.complexity_tax(-50)
  assert(math.abs(pos - neg) < 0.0001, "tax should be symmetric: " .. tostring(pos) .. " vs " .. tostring(neg))
  print("✓ complexity_tax is symmetric (uses abs)")
end
test_complexity_tax_negative()

local function test_better_and_simpler()
  local verdict, reason = decide.decide(0.80, 0.72, -5)
  assert(verdict == "keep", "better+simpler should keep: " .. verdict)
  assert(reason:find("better"), "reason should mention better: " .. reason)
  print("✓ keep when better and simpler")
end
test_better_and_simpler()

local function test_better_justifies_complexity()
  local verdict, reason = decide.decide(0.80, 0.72, 10)
  assert(verdict == "keep", "big improvement should justify complexity: " .. verdict)
  assert(reason:find("justif"), "reason should mention justifies: " .. reason)
  print("✓ keep when improvement justifies complexity")
end
test_better_justifies_complexity()

local function test_better_too_small_for_complexity()
  -- tiny improvement with huge complexity addition
  local verdict, reason = decide.decide(0.726, 0.72, 200)
  assert(verdict == "discard", "tiny improvement + huge complexity should discard: " .. verdict)
  assert(reason:find("too small"), "reason should mention too small: " .. reason)
  print("✓ discard when improvement too small for complexity")
end
test_better_too_small_for_complexity()

local function test_equal_and_simpler()
  local verdict, reason = decide.decide(0.72, 0.72, -10)
  assert(verdict == "keep", "equal+simpler should keep: " .. verdict)
  assert(reason:find("simpler"), "reason should mention simpler: " .. reason)
  print("✓ keep when equal performance and simpler")
end
test_equal_and_simpler()

local function test_equal_and_more_complex()
  local verdict, reason = decide.decide(0.72, 0.72, 10)
  assert(verdict == "discard", "equal+complex should discard: " .. verdict)
  assert(reason:find("equal"), "reason should mention equal: " .. reason)
  print("✓ discard when equal performance with more complexity")
end
test_equal_and_more_complex()

local function test_worse()
  local verdict, reason = decide.decide(0.60, 0.72, -10)
  assert(verdict == "discard", "worse should discard: " .. verdict)
  assert(reason:find("worse"), "reason should mention worse: " .. reason)
  print("✓ discard when worse")
end
test_worse()

local function test_noise_boundary()
  -- within noise threshold (diff = 0.004 < 0.005)
  local verdict, _ = decide.decide(0.724, 0.72, 0)
  assert(verdict == "discard", "within noise with zero delta should discard: " .. verdict)
  print("✓ noise boundary correctly handled")
end
test_noise_boundary()

local function test_just_above_noise()
  local verdict, _ = decide.decide(0.7261, 0.72, 0)
  -- diff = 0.0061, above noise threshold
  assert(verdict == "keep", "just above noise with zero delta should keep: " .. verdict)
  print("✓ just above noise threshold keeps")
end
test_just_above_noise()

print("\nAll decide tests passed!")
