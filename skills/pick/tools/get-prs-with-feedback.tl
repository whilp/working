-- skills/pick/tools/get-prs-with-feedback.tl: list open PRs with review feedback
--
-- returns PRs where reviewDecision is CHANGES_REQUESTED, including their
-- review comments and details. uses graphql with explicit owner/name to
-- avoid gh CLI local repo context issues.
-- reads WORK_REPO from environment to limit scope.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local json = require("cosmic.json")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
      stderr = 1,
    })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

local QUERY = [[
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    pullRequests(first: 50, states: OPEN, orderBy: {field: UPDATED_AT, direction: ASC}) {
      nodes {
        number
        title
        url
        headRefName
        reviewDecision
        updatedAt
        body
        reviews(last: 20) {
          nodes {
            author { login }
            body
            state
            submittedAt
          }
        }
        comments(last: 20) {
          nodes {
            author { login }
            body
            createdAt
          }
        }
      }
    }
  }
}
]]

local repo = os.getenv("WORK_REPO") or ""

local function parse_repo(r: string): string, string
  local owner, name = r:match("^([^/]+)/([^/]+)$")
  return owner, name
end

return {
  name = "get_prs_with_feedback",
  description = "List open pull requests that have CHANGES_REQUESTED review status, including their review comments. Returns a JSON array of PRs with feedback details. Operates on the repo set by WORK_REPO environment variable.",
  input_schema = {
    type = "object",
    properties = {},
  },
  _parse_repo = parse_repo,
  execute = function(_: {string: any}): string
    if repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local owner, name = parse_repo(repo)
    if not owner or not name then
      return "error: WORK_REPO must be owner/name format"
    end

    local ok, out, code = run({
        "gh", "api", "graphql",
        "-f", "query=" .. QUERY,
        "-f", "owner=" .. owner,
        "-f", "name=" .. name,
      })
    if not ok then
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    local resp = json.decode(out or "{}") as {string: any}
    if not resp or not resp.data then
      local errors = resp and resp.errors as {any}
      if errors and #errors > 0 then
        local first = errors[1] as {string: any}
        return "error: graphql: " .. tostring(first.message or "unknown")
      end
      return "error: failed to parse graphql response"
    end

    local data = resp.data as {string: any}
    local repository = data.repository as {string: any}
    local prs_conn = repository.pullRequests as {string: any}
    local nodes = prs_conn.nodes as {any}

    local filtered: {any} = {}
    for _, node_any in ipairs(nodes) do
      local pr = node_any as {string: any}
      if pr.reviewDecision == "CHANGES_REQUESTED" then
        -- reshape reviews
        local reviews_conn = pr.reviews as {string: any}
        local review_nodes = reviews_conn and reviews_conn.nodes as {any} or {}
        local reviews: {any} = {}
        for _, r_any in ipairs(review_nodes) do
          local r = r_any as {string: any}
          local author = r.author as {string: any}
          reviews[#reviews + 1] = {
            author = author and author.login or nil,
            body = r.body,
            state = r.state,
            submittedAt = r.submittedAt,
          }
        end

        -- reshape comments
        local comments_conn = pr.comments as {string: any}
        local comment_nodes = comments_conn and comments_conn.nodes as {any} or {}
        local comments: {any} = {}
        for _, c_any in ipairs(comment_nodes) do
          local c = c_any as {string: any}
          local author = c.author as {string: any}
          comments[#comments + 1] = {
            author = author and author.login or nil,
            body = c.body,
            createdAt = c.createdAt,
          }
        end

        filtered[#filtered + 1] = {
          number = pr.number,
          title = pr.title,
          body = pr.body,
          url = pr.url,
          headRefName = pr.headRefName,
          reviewDecision = pr.reviewDecision,
          updatedAt = pr.updatedAt,
          reviews = reviews,
          comments = comments,
        }
      end
    end

    return (json.encode(filtered))
  end,
}
