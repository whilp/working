-- skills/pick/tools/get-prs-with-feedback.tl: list open PRs needing attention
--
-- returns PRs that are blocked and need work: either reviewDecision is
-- CHANGES_REQUESTED, or CI checks are failing. for PRs labeled needs-review
-- (already addressed, waiting for reviewer): skips if only checks are failing,
-- and skips if the latest CHANGES_REQUESTED review predates the last commit
-- (we already pushed a fix). includes the PR if the review postdates the last
-- commit (new feedback from reviewer). each returned PR includes a "reason"
-- field: "changes_requested", "checks_failing", or
-- "changes_requested,checks_failing".
-- uses graphql with explicit owner/name to avoid gh CLI local repo context
-- issues. reads WORK_REPO from environment to limit scope.
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
        labels(first: 20) {
          nodes {
            name
          }
        }
        commits(last: 1) {
          nodes {
            commit {
              committedDate
              statusCheckRollup {
                state
              }
            }
          }
        }
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

local function parse_repo(r: string): string, string
  local owner, name = r:match("^([^/]+)/([^/]+)$")
  return owner, name
end

return {
  name = "get_prs_with_feedback",
  description = "List open pull requests that need attention: CHANGES_REQUESTED review status or failing CI checks. For PRs labeled needs-review, compares the latest CHANGES_REQUESTED review timestamp against the last commit — only includes the PR if the review is newer (new feedback from reviewer). Operates on the repo set by WORK_REPO environment variable.",
  input_schema = {
    type = "object",
    properties = {},
  },
  _parse_repo = parse_repo,
  execute = function(_: {string: any}): string
    -- read env at call time to avoid stale module-level capture
    local live_repo = os.getenv("WORK_REPO") or ""
    if live_repo == "" then
      return "error: WORK_REPO environment variable not set"
    end

    local owner, name = parse_repo(live_repo)
    if not owner or not name then
      return "error: WORK_REPO must be owner/name format: " .. live_repo
    end

    io.stderr:write("get_prs_with_feedback: querying " .. owner .. "/" .. name .. "\n")

    local ok, out, code = run({
        "gh", "api", "graphql",
        "-f", "query=" .. QUERY,
        "-f", "owner=" .. owner,
        "-f", "name=" .. name,
      })
    if not ok then
      if code == 4 then
        return "error: gh access denied (exit 4): " .. (out or "")
      end
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
      -- skip PRs labeled needs-review (already addressed, waiting for reviewer)
      local has_needs_review = false
      local has_changes_requested = false
      local labels_conn = pr.labels as {string: any}
      if labels_conn then
        local label_nodes = labels_conn.nodes as {any} or {}
        for _, l_any in ipairs(label_nodes) do
          local l = l_any as {string: any}
          if l.name == "needs-review" then
            has_needs_review = true
            break
          end
        end
      end

      if pr.reviewDecision == "CHANGES_REQUESTED" then
        has_changes_requested = true
      end

      -- check CI status from last commit; also capture committedDate
      local has_checks_failing = false
      local last_commit_date: string = ""
      local commits_conn = pr.commits as {string: any}
      if commits_conn then
        local commit_nodes = commits_conn.nodes as {any} or {}
        if #commit_nodes > 0 then
          local last_commit_node = commit_nodes[#commit_nodes] as {string: any}
          local commit_obj = last_commit_node.commit as {string: any}
          if commit_obj then
            last_commit_date = (commit_obj.committedDate as string) or ""
            local rollup = commit_obj.statusCheckRollup as {string: any}
            if rollup then
              local state = rollup.state as string
              if state == "FAILURE" or state == "ERROR" then
                has_checks_failing = true
              end
            end
          end
        end
      end

      -- find the latest CHANGES_REQUESTED review timestamp
      local latest_cr_date: string = ""
      if has_changes_requested then
        local reviews_conn = pr.reviews as {string: any}
        local review_nodes = reviews_conn and reviews_conn.nodes as {any} or {}
        for _, r_any in ipairs(review_nodes) do
          local r = r_any as {string: any}
          if r.state == "CHANGES_REQUESTED" then
            local submitted = (r.submittedAt as string) or ""
            if submitted > latest_cr_date then
              latest_cr_date = submitted
            end
          end
        end
      end

      -- needs-review means "we pushed fixes, waiting for reviewer".
      -- when both needs-review and CHANGES_REQUESTED are set, compare
      -- the latest CHANGES_REQUESTED review against the last commit.
      -- if the review predates the commit, we already addressed it — skip.
      -- if the review postdates the commit, it's new feedback — include.
      local dominated_by_needs_review = false
      if has_needs_review then
        if not has_changes_requested then
          -- only signal is checks_failing; skip (transient after our push)
          dominated_by_needs_review = true
        elseif latest_cr_date ~= "" and last_commit_date ~= ""
        and latest_cr_date <= last_commit_date then
          -- review predates our fix commit; already addressed
          dominated_by_needs_review = true
        end
      end

      if (has_changes_requested or has_checks_failing)
      and not dominated_by_needs_review then
        -- build reason string
        local reasons: {string} = {}
        if has_changes_requested then
          reasons[#reasons + 1] = "changes_requested"
        end
        if has_checks_failing then
          reasons[#reasons + 1] = "checks_failing"
        end
        local reason = table.concat(reasons, ",")

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
          reason = reason,
          reviews = reviews,
          comments = comments,
        }
      end
    end

    return (json.encode(filtered))
  end,
}
