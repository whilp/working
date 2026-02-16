#!/usr/bin/env cosmic
-- tools/list-issues.tl: fetch open todo issues from a github repo
--
-- usage: list-issues.tl <owner/repo>
-- stdout: json array of issues

local json = require("cosmic.json")

local repo = arg[1]
if not repo or repo == "" then
   io.stderr:write("usage: list-issues.tl <owner/repo>\n")
   os.exit(1)
end

local cmd = table.concat({
   "gh", "issue", "list",
   "--repo", repo,
   "--label", "todo",
   "--state", "open",
   "--json", "number,title,body,url,labels,createdAt",
   "--limit", "100",
}, " ")

local p = io.popen(cmd .. " 2>&1")
if not p then
   io.stderr:write("failed to run gh\n")
   os.exit(1)
end

local out = p:read("*a")
local ok = p:close() as boolean
if not ok then
   io.stderr:write("gh failed: " .. (out or "") .. "\n")
   os.exit(1)
end

-- validate it's json
local issues = json.decode(out)
if not issues then
   io.stderr:write("failed to parse issues json\n")
   os.exit(1)
end

io.write((json.encode(issues)))
