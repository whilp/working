-- skills/triage/tools/grep-repo.tl: search files in the target repo
--
-- runs grep on o/repo/ to search for patterns in the codebase.
-- constrains searches to o/repo/ only.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")

local repo_dir = "o/repo"

return {
  name = "grep_repo",
  description = "Search for a pattern in the target repository using grep. Returns matching lines with file paths and line numbers.",
  input_schema = {
    type = "object",
    properties = {
      pattern = {type = "string", description = "Search pattern (extended regex)"},
      path = {type = "string", description = "Optional subdirectory or file path within the repo to search"},
    },
    required = {"pattern"},
  },
  execute = function(input: {string: any}): string
    local pattern = input.pattern as string
    if not pattern or pattern == "" then
      return "error: pattern required"
    end

    local search_path = repo_dir
    local sub = input.path as string
    if sub and sub ~= "" then
      -- reject path traversal
      if sub:match("%.%.") then
        return "error: path must not contain '..'"
      end
      search_path = repo_dir .. "/" .. sub
    end

    local _h, _err = child.spawn({
        "grep", "-rn", "-E",
        "--include=*.tl",
        "--include=*.lua",
        "--include=*.md",
        "--include=*.yml",
        "--include=*.yaml",
        "--include=*.json",
        "--include=Makefile",
        "--include=*.mk",
        "-e", pattern,
        search_path,
      }, {stderr = 1})
    if not _h then
      return "error: grep failed: " .. (_err or "spawn failed")
    end
    local ok, out, code = _h:read()

    if not ok then
      if code == 1 then
        return "no matches found"
      end
      return "error: grep failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    -- truncate long output
    local result = out or ""
    local max_len = 10000
    if #result > max_len then
      result = result:sub(1, max_len) .. "\n... (truncated)"
    end

    return result
  end,
}
