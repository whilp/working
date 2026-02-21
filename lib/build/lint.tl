-- lib/build/lint.tl: lint all tracked files for line count violations
--
-- checks file length against a 500-line default limit with per-file overrides.
-- produces reporter-compatible output: pass:/fail: + diagnostics.
-- module tool: returns a Tool record for ah to load via -t

local record Diagnostic
  file: string
  line: integer
  col: integer
  rule: string
  message: string
end

-- hardcoded line count overrides
-- files not listed here use the default 500-line limit
local OVERRIDES: {string: integer} = {
  -- no overrides needed; all files currently under 500 lines
}

local DEFAULT_LIMIT = 500

local function count_lines(path: string): integer, string
  local f, err = io.open(path, "r")
  if not f then
    return 0, err or "failed to open file"
  end

  local count = 0
  for _ in f:lines() do
    count = count + 1
  end
  f:close()

  return count, ""
end

local function check_file_length(path: string, limits: {string: integer}, default: integer): Diagnostic
  local limit = limits[path] or default
  local actual, err = count_lines(path)

  if err ~= "" then
    return {
      file = path,
      line = 1,
      col = 1,
      rule = "length",
      message = "failed to read: " .. err,
    }
  end

  if actual > limit then
    return {
      file = path,
      line = 1,
      col = 1,
      rule = "length",
      message = tostring(actual) .. " lines > " .. tostring(limit) .. " max",
    }
  end

  return nil
end

local function lint_files(files: {string}): {Diagnostic}, integer
  local diagnostics: {Diagnostic} = {}
  local checked = 0

  for _, path in ipairs(files) do
    checked = checked + 1
    local diag = check_file_length(path, OVERRIDES, DEFAULT_LIMIT)
    if diag then
      diagnostics[#diagnostics + 1] = diag
    end
  end

  return diagnostics, checked
end

local function main(args: {string}): integer
  -- args[1] contains a single file path
  if #args < 1 or args[1] == "" then
    io.stderr:write("usage: cosmic lib/build/lint.tl '<file>'\n")
    return 1
  end

  local files: {string} = {args[1]}
  local diagnostics, checked = lint_files(files)

  if #diagnostics == 0 then
    print("pass: checked " .. tostring(checked) .. " files")
    return 0
  end

  print("fail: " .. tostring(#diagnostics) .. " issues")
  for _, diag in ipairs(diagnostics) do
    print(diag.file .. ":" .. tostring(diag.line) .. ":" .. tostring(diag.col) .. ": " .. diag.rule .. ": " .. diag.message)
  end

  return 1
end

-- CLI mode: if executed as script
if arg and #arg > 0 then
  os.exit(main(arg))
end

-- module mode: return tool record
return {
  name = "lint",
  description = "Check file length against a 500-line default limit with per-file overrides. Produces reporter-compatible diagnostics.",
  input_schema = {
    type = "object",
    properties = {
      files = {
        type = "array",
        items = {type = "string"},
        description = "List of file paths to check",
      },
    },
    required = {"files"},
  },
  execute = function(input: {string: any}): string
    local files_any = input.files
    if not files_any then
      return "error: files parameter required"
    end

    local files = files_any as {string}
    local diagnostics, checked = lint_files(files)

    if #diagnostics == 0 then
      return "pass: checked " .. tostring(checked) .. " files"
    end

    local result = "fail: " .. tostring(#diagnostics) .. " issues\n"
    for _, diag in ipairs(diagnostics) do
      result = result .. diag.file .. ":" .. tostring(diag.line) .. ":" .. tostring(diag.col) .. ": " .. diag.rule .. ": " .. diag.message .. "\n"
    end

    return result
  end,
}
