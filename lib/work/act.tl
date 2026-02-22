-- lib/work/act.tl: execute actions from the check phase
--
-- deterministic script that reads issue.json and actions.json,
-- executes each action via gh CLI, transitions labels, and
-- writes act.json.
--
-- CLI: cosmic act.tl <issue_file> <actions_file> <output_file>
-- reads WORK_REPO from environment.

local child = require("cosmic.child")
local cio = require("cosmic.io")
local json = require("cosmic.json")

local function read_json(path: string): any, string
  local content = cio.slurp(path)
  if not content then
    return nil, "error: could not read " .. path
  end
  local ok, result = pcall(json.decode, content)
  if not ok then
    return nil, "error: could not parse " .. path
  end
  return result, nil
end

local function comment_issue(repo: string, issue_number: number, body: string): boolean, string
  local tmp = os.tmpname()
  cio.barf(tmp, body)
  local _h_comment, _err_comment = child.spawn({
      "gh", "issue", "comment", tostring(issue_number),
      "--repo", repo,
      "--body-file", tmp,
    }, {stderr = 1})
  os.remove(tmp)
  if not _h_comment then
    return false, "gh failed: " .. (_err_comment or "spawn failed")
  end
  local ok, out, code = _h_comment:read()
  if not ok then
    return false, "gh failed (exit " .. tostring(code) .. "): " .. (out or "")
  end
  return true, nil
end

local function create_pr(repo: string, branch: string, title: string, body: string): boolean, string
  local tmp = os.tmpname()
  cio.barf(tmp, body)
  local _h_pr, _err_pr = child.spawn({
      "gh", "pr", "create",
      "--repo", repo,
      "--head", branch,
      "--title", title,
      "--body-file", tmp,
    }, {stderr = 1})
  os.remove(tmp)
  if not _h_pr then
    return false, "gh failed: " .. (_err_pr or "spawn failed")
  end
  local ok, out, code = _h_pr:read()
  if not ok then
    if out and out:find("already exists") then
      return true, nil
    end
    return false, "gh failed (exit " .. tostring(code) .. "): " .. (out or "")
  end
  return true, nil
end

local function set_labels(repo: string, issue_number: number, add: {string}, remove: {string}): boolean, string
  local argv: {string} = {"gh", "issue", "edit", tostring(issue_number), "--repo", repo}
  for _, label in ipairs(add or {}) do
    table.insert(argv, "--add-label")
    table.insert(argv, label)
  end
  for _, label in ipairs(remove or {}) do
    table.insert(argv, "--remove-label")
    table.insert(argv, label)
  end
  local _h_labels, _err_labels = child.spawn(argv, {stderr = 1})
  if not _h_labels then
    return false, "gh failed: " .. (_err_labels or "spawn failed")
  end
  local ok, out, code = _h_labels:read()
  if not ok then
    return false, "gh failed (exit " .. tostring(code) .. "): " .. (out or "")
  end
  return true, nil
end

local function execute(issue_file: string, actions_file: string, output_file: string): string
  local repo = os.getenv("WORK_REPO") or ""
  if repo == "" then
    return "error: WORK_REPO environment variable not set"
  end

  local issue_data, issue_err = read_json(issue_file)
  if not issue_data then
    return issue_err
  end
  local issue = issue_data as {string: any}

  local actions_data, actions_err = read_json(actions_file)
  if not actions_data then
    return actions_err
  end
  local check = actions_data as {string: any}

  local item_type = (issue.type as string) or "issue"
  local issue_number = math.floor(issue.number as number)
  local branch = issue.branch as string
  local verdict = (check.verdict as string) or "fail"
  local actions = (check.actions as {any}) or {}

  local executed = 0
  local failed = 0

  for _, raw_action in ipairs(actions) do
    local action = raw_action as {string: any}
    local action_type = action.action as string

    if action_type == "comment_issue" then
      local ok, err = comment_issue(repo, issue_number, (action.body as string) or "")
      executed = executed + 1
      if not ok then
        io.stderr:write("comment_issue failed: " .. (err or "") .. "\n")
        failed = failed + 1
      end
    elseif action_type == "create_pr" then
      if item_type == "pr" then
        -- skip: PR already exists
      else
        local body = (action.body as string) or ""
        local closes = "Closes #" .. tostring(issue_number)
        if not body:find(closes, 1, true) then
          body = body .. "\n\n" .. closes
        end
        local ok, err = create_pr(repo, branch, (action.title as string) or "", body)
        executed = executed + 1
        if not ok then
          io.stderr:write("create_pr failed: " .. (err or "") .. "\n")
          failed = failed + 1
        end
      end
    else
      io.stderr:write("unknown action type: " .. tostring(action_type) .. "\n")
    end
  end

  -- transition labels
  local label: string
  if item_type == "pr" then
    set_labels(repo, issue_number, {"needs-review"}, {})
    label = "needs-review"
  elseif verdict == "pass" and failed == 0 then
    set_labels(repo, issue_number, {"done"}, {"doing"})
    label = "done"
  else
    set_labels(repo, issue_number, {"failed"}, {"doing"})
    label = "failed"
  end

  local result = json.encode({
      type = item_type,
      verdict = verdict,
      actions_executed = executed,
      actions_failed = failed,
      label = label,
    })

  cio.barf(output_file, result)
  return "ok: wrote " .. output_file
end

-- CLI entry point: only run when invoked directly (not via require)
local is_main = arg and (arg[0] or ""):find("/act%.tl$")
if is_main then
  if #arg < 3 then
    io.stderr:write("usage: cosmic act.tl <issue_file> <actions_file> <output_file>\n")
    os.exit(1)
  end
  local result = execute(arg[1], arg[2], arg[3])
  if result:match("^error:") then
    io.stderr:write(result .. "\n")
    os.exit(1)
  end
  print(result)
end

return {
  execute = execute,
}
