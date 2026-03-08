-- extract-do-notes.tl: extract learnings from a timed-out do session.
--
-- reads the session database and git diff to produce a notes file
-- that the next do attempt can use to avoid repeating mistakes.
--
-- usage: cosmic extract-do-notes.tl <session_db> <repo_dir> <output_file>

local sql = require("cosmo.lsqlite3")
local cio = require("cosmic.io")

local args = arg as {string}
if #args < 3 then
  io.stderr:write("usage: extract-do-notes.tl <session_db> <repo_dir> <output_file>\n")
  os.exit(1)
end

local db_path = args[1]
local repo_dir = args[2]
local output_path = args[3]

-- open session database
local db = sql.open(db_path)
if not db then
  io.stderr:write("error: cannot open " .. db_path .. "\n")
  os.exit(1)
end

-- collect assistant text blocks (learnings, observations)
local texts: {string} = {}
db:exec([[
   SELECT cb.content
   FROM content_blocks cb
   JOIN messages m ON cb.message_id = m.id
   WHERE m.role = 'assistant'
     AND cb.block_type = 'text'
     AND cb.content IS NOT NULL
     AND cb.content != ''
   ORDER BY m.created_at ASC, cb.seq ASC
]], function(_: any, _ncols: integer, values: {string}, _names: {string}): integer
    table.insert(texts, values[1])
    return 0
  end)

-- collect tool errors (is_error = 1)
local errors: {string} = {}
db:exec([[
   SELECT cb.tool_name, cb.content
   FROM content_blocks cb
   JOIN messages m ON cb.message_id = m.id
   WHERE cb.block_type = 'tool_result'
     AND cb.is_error = 1
     AND cb.content IS NOT NULL
     AND cb.content != ''
   ORDER BY m.created_at ASC, cb.seq ASC
]], function(_: any, _ncols: integer, values: {string}, _names: {string}): integer
    local tool = values[1] or "unknown"
    local content = values[2]
    if #content > 500 then
      content = content:sub(1, 500) .. "\n... (truncated)"
    end
    table.insert(errors, "- `" .. tool .. "`: " .. content)
    return 0
  end)

db:close()

-- get git diff (uncommitted changes)
local diff = ""
local handle = io.popen("git -C " .. repo_dir .. " diff HEAD 2>/dev/null")
if handle then
  diff = handle:read("*a") or ""
  handle:close()
end

-- get git status
local status = ""
local status_handle = io.popen(
  "git -C " .. repo_dir .. " status --short 2>/dev/null"
)
if status_handle then
  status = status_handle:read("*a") or ""
  status_handle:close()
end

-- build the notes file
local parts: {string} = {}
table.insert(parts, "# Do Phase Timeout Notes")
table.insert(parts, "")
table.insert(parts, "The previous do attempt timed out. " ..
  "Use these notes to continue efficiently.")
table.insert(parts, "Do NOT repeat the same approach " ..
  "if it led to errors below.")
table.insert(parts, "")

if #errors > 0 then
  table.insert(parts, "## Errors Encountered")
  table.insert(parts, "")
  for _, e in ipairs(errors) do
    table.insert(parts, e)
  end
  table.insert(parts, "")
end

-- include last few assistant observations (most valuable learnings)
if #texts > 0 then
  table.insert(parts, "## Key Observations from Previous Attempt")
  table.insert(parts, "")
  -- take last 5 text blocks — most recent learnings
  local start_idx = math.max(1, #texts - 4)
  for i = start_idx, #texts do
    table.insert(parts, texts[i])
    table.insert(parts, "")
  end
end

if status ~= "" then
  table.insert(parts, "## Uncommitted Changes")
  table.insert(parts, "")
  table.insert(parts, "The previous attempt left these " ..
    "uncommitted changes in the working tree:")
  table.insert(parts, "")
  table.insert(parts, "```")
  table.insert(parts, status)
  table.insert(parts, "```")
  table.insert(parts, "")
  table.insert(parts, "Review these changes — they may be " ..
    "correct and just need committing,")
  table.insert(parts, "or they may need formatting/type " ..
    "fixes before committing.")
  table.insert(parts, "")
end

if diff ~= "" then
  -- truncate very large diffs
  if #diff > 5000 then
    diff = diff:sub(1, 5000) ..
    "\n... (truncated, run `git diff` to see full)"
  end
  table.insert(parts, "## Diff")
  table.insert(parts, "")
  table.insert(parts, "```diff")
  table.insert(parts, diff)
  table.insert(parts, "```")
end

local content = table.concat(parts, "\n")
cio.barf(output_path, content)

io.stderr:write("  extracted do notes to " .. output_path .. "\n")
