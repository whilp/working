-- tools/comment-issue.tl: comment on a GitHub issue
--
-- reads WORK_REPO from environment to limit scope.
-- takes issue number instead of URL.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local cio = require("cosmic.io")
local fs = require("cosmic.fs")

local repo = os.getenv("WORK_REPO") or ""

local function parse_issue_number(input: any, expected_repo: string): number, string
  if type(input) == "number" then
    return math.floor(input as number), nil
  end
  if type(input) == "string" then
    local s = input as string
    -- owner/repo#N
    local r, n = s:match("^([%w%-_%.]+/[%w%-_%.]+)#(%d+)$")
    if r and n then
      if r ~= expected_repo then
        return nil, "error: repo mismatch: got " .. r .. ", expected " .. expected_repo
      end
      return tonumber(n), nil
    end
    -- #N
    local hn = s:match("^#(%d+)$")
    if hn then
      return tonumber(hn), nil
    end
    -- bare number string
    local bn = s:match("^(%d+)$")
    if bn then
      return tonumber(bn), nil
    end
    return nil, "error: could not parse issue_number: " .. s
  end
  return nil, "error: issue_number must be a number or string, got " .. type(input)
end

local tool = {
  name = "comment_issue",
  description = "Post a comment on a GitHub issue or pull request by number.",
  input_schema = {
    type = "object",
    properties = {
      issue_number = {type = "number", description = "Issue or PR number (also accepts owner/repo#N, #N, or bare number string)"},
      body = {type = "string", description = "Comment body (markdown)"},
    },
    required = {"issue_number", "body"},
  },
  execute = function(input: {string: any}): string
    local body = input.body as string

    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local issue_number, parse_err = parse_issue_number(input.issue_number, repo)
    if not issue_number then
      return parse_err
    end
    if not body or body == "" then
      return "error: body required"
    end

    local num = tostring(issue_number)

    local tmp = os.tmpname()
    cio.barf(tmp, body)

    local h, err = child.spawn({"gh", "issue", "comment", num, "--repo", repo, "--body-file", tmp}, {stderr = 1})
    fs.unlink(tmp)
    if not h then
      return "error: gh failed: " .. (err or "spawn failed")
    end
    local ok, out, code = h:read()

    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end
    return "ok"
  end,
  _parse_issue_number = parse_issue_number,
}

return tool
