-- lib/eval/decide-experiment.tl: run keep/discard decision for an experiment
--
-- compares new eval score to best score, applies complexity tax,
-- appends result to results.tsv, writes decision.json.
--
-- usage: cosmic lib/eval/decide-experiment.tl <new_score> <best_score> <diff_lines> <commit> <description> <results_tsv> <decision_json>

local json = require("cosmic.json")
local cio = require("cosmic.io")
local decide = require("lib.eval.decide")

local new_score = tonumber(arg[1])
local best_score = tonumber(arg[2])
local diff_lines = tonumber(arg[3]) or 0
local commit = arg[4] or "unknown"
local description = arg[5] or "unknown"
local results_tsv = arg[6]
local decision_json = arg[7]

if not new_score or not best_score or not results_tsv or not decision_json then
  io.stderr:write("usage: cosmic lib/eval/decide-experiment.tl <new_score> <best_score> <diff_lines> <commit> <description> <results_tsv> <decision_json>\n")
  os.exit(1)
end

local verdict, reason = decide.decide(new_score, best_score, diff_lines)

-- write decision
local result = {
  verdict = verdict,
  reason = reason,
  new_score = new_score,
  best_score = best_score,
  complexity_delta = diff_lines,
  commit = commit,
  description = description,
}
local encoded = json.encode(result)
cio.barf(decision_json, encoded)

-- append to results log
local status = verdict
local existing = cio.slurp(results_tsv)
local content: string
if not existing or existing == "" then
  content = "commit\tcomposite\tpass_rate\tmean_quality\tmean_tokens\tstatus\tdescription\n"
else
  content = existing
  if not content:match("\n$") then
    content = content .. "\n"
  end
end
local row = string.format("%s\t%.4f\t\t\t\t%s\t%s", commit, new_score, status, description)
content = content .. row .. "\n"
cio.barf(results_tsv, content)

print("verdict=" .. verdict .. " reason=" .. reason)
print("new=" .. tostring(new_score) .. " best=" .. tostring(best_score) .. " delta=" .. tostring(diff_lines))
