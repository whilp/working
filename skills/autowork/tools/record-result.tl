-- skills/autowork/tools/record-result.tl: append to eval results log
--
-- appends a single experiment result to results.tsv.
-- creates the file with a header if it doesn't exist.

local cio = require("cosmic.io")

local HEADER = "commit\tcomposite\tpass_rate\tmean_quality\tmean_tokens\tstatus\tdescription"

return {
  name = "record_result",
  description = "Append an experiment result to the results log (results.tsv). Creates the file with header if it doesn't exist.",
  input_schema = {
    type = "object",
    properties = {
      results_file = {type = "string", description = "Path to results.tsv"},
      commit = {type = "string", description = "Git commit SHA (short)"},
      composite = {type = "number", description = "Composite eval score"},
      pass_rate = {type = "number", description = "Task pass rate (0.0-1.0)"},
      mean_quality = {type = "number", description = "Mean quality factor"},
      mean_tokens = {type = "number", description = "Mean tokens per task"},
      status = {type = "string", description = "keep, discard, or baseline"},
      description = {type = "string", description = "Short description of the change"},
    },
    required = {"results_file", "commit", "composite", "pass_rate", "mean_quality", "mean_tokens", "status", "description"},
  },
  execute = function(input: {string: any}): string
    local results_file = input.results_file as string
    if not results_file or results_file == "" then
      return "error: results_file required"
    end

    local commit = input.commit as string
    if not commit or commit == "" then return "error: commit required" end

    local composite = input.composite as number
    if not composite then return "error: composite required" end

    local pass_rate = input.pass_rate as number
    if not pass_rate then return "error: pass_rate required" end

    local mean_quality = input.mean_quality as number
    if not mean_quality then return "error: mean_quality required" end

    local mean_tokens = input.mean_tokens as number
    if not mean_tokens then return "error: mean_tokens required" end

    local status = input.status as string
    if not status or status == "" then return "error: status required" end

    local description = input.description as string
    if not description or description == "" then return "error: description required" end

    -- check if file exists and has header
    local existing = cio.slurp(results_file)
    local content: string
    if not existing or existing == "" then
      content = HEADER .. "\n"
    else
      content = existing
      if not content:match("\n$") then
        content = content .. "\n"
      end
    end

    -- append row
    local row = string.format("%s\t%.4f\t%.4f\t%.4f\t%.0f\t%s\t%s",
      commit, composite, pass_rate, mean_quality, mean_tokens, status, description)
    content = content .. row .. "\n"

    cio.barf(results_file, content)
    return "ok"
  end,
}
