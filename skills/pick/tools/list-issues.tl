-- skills/pick/tools/list-issues.tl: fetch open issues from a github repo
--
-- returns issues that are either labeled "todo" or filed by repo collaborators.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local unix = require("cosmo.unix")
local json = require("cosmic.json")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
    env = unix.environ() as {string},
    stderr = 1,
  })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

local COLLABORATOR_ASSOCIATIONS: {string: boolean} = {
  OWNER = true,
  MEMBER = true,
  COLLABORATOR = true,
}

local QUERY = [[
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    issues(first: 100, after: $cursor, states: OPEN, orderBy: {field: CREATED_AT, direction: ASC}) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number
        title
        body
        url
        authorAssociation
        createdAt
        author { login }
        labels(first: 20) { nodes { name } }
      }
    }
  }
}
]]

return {
  name = "list_issues",
  description = "Fetch open issues from a GitHub repository that are either labeled 'todo' or filed by repo collaborators (owner/member/collaborator). Pass owner/repo as the repo argument.",
  input_schema = {
    type = "object",
    properties = {
      repo = {type = "string", description = "GitHub repository (owner/repo)"},
    },
    required = {"repo"},
  },
  execute = function(input: {string: any}): string
    local repo = input.repo as string
    if not repo or repo == "" then
      return "error: repo argument required"
    end

    local owner, name = repo:match("^([^/]+)/([^/]+)$")
    if not owner or not name then
      return "error: repo must be owner/name format"
    end

    local all_issues: {any} = {}
    local cursor: string = ""
    local has_cursor = false

    for _ = 1, 10 do -- max 10 pages (1000 issues)
      local argv: {string} = {
        "gh", "api", "graphql",
        "-f", "query=" .. QUERY,
        "-f", "owner=" .. owner,
        "-f", "name=" .. name,
      }
      if has_cursor then
        argv[#argv + 1] = "-f"
        argv[#argv + 1] = "cursor=" .. cursor
      end

      local ok, out, code = run(argv)
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
      local issues_conn = repository.issues as {string: any}
      local nodes = issues_conn.nodes as {any}

      for _, node_any in ipairs(nodes) do
        local node = node_any as {string: any}
        local labels_conn = node.labels as {string: any}
        local label_nodes = labels_conn.nodes as {any}

        -- check if issue has todo label
        local has_todo = false
        local label_list: {any} = {}
        for _, ln_any in ipairs(label_nodes) do
          local ln = ln_any as {string: any}
          local lname = ln.name as string
          label_list[#label_list + 1] = {name = lname}
          if lname == "todo" then
            has_todo = true
          end
        end

        -- check if author is a collaborator
        local assoc = node.authorAssociation as string
        local is_collaborator = COLLABORATOR_ASSOCIATIONS[assoc] or false

        if has_todo or is_collaborator then
          local author_obj = node.author as {string: any}
          all_issues[#all_issues + 1] = {
            number = node.number,
            title = node.title,
            body = node.body,
            url = node.url,
            createdAt = node.createdAt,
            labels = label_list,
            authorAssociation = assoc,
            author = author_obj and author_obj.login or nil,
          }
        end
      end

      local page_info = issues_conn.pageInfo as {string: any}
      if not (page_info.hasNextPage as boolean) then
        break
      end
      cursor = page_info.endCursor as string
      has_cursor = true
    end

    return (json.encode(all_issues))
  end,
}
