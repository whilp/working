-- skills/autowork/tools/get-eval-results.tl: read eval results log
--
-- reads the results.tsv file and returns recent experiment history.
-- the agent uses this to understand what has been tried and what worked.

local cio = require("cosmic.io")

return {
  name = "get_eval_results",
  description = "Read the eval results log (results.tsv) showing past experiments with scores and keep/discard decisions. Returns the last N entries.",
  input_schema = {
    type = "object",
    properties = {
      results_file = {type = "string", description = "Path to results.tsv file"},
      limit = {type = "number", description = "Max entries to return (default 20)"},
    },
    required = {"results_file"},
  },
  execute = function(input: {string: any}): string
    local results_file = input.results_file as string
    if not results_file or results_file == "" then
      return "error: results_file required"
    end

    local limit = (input.limit as number) or 20
    if limit <= 0 then limit = 20 end

    local content = cio.slurp(results_file)
    if not content or content == "" then
      return "no results yet"
    end

    -- split into lines, return last N
    local lines: {string} = {}
    for line in content:gmatch("[^\n]+") do
      lines[#lines + 1] = line
    end

    if #lines <= 1 then
      return content -- just header
    end

    -- keep header + last N data lines
    local header = lines[1]
    local n = #lines
    local start_idx = 2
    local skip = n - (limit as integer)
    if skip > start_idx then start_idx = skip + 1 end
    local result: {string} = {header}
    for i = start_idx, n do
      result[#result + 1] = lines[i]
    end

    return table.concat(result, "\n")
  end,
}
