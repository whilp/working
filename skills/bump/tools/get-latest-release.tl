-- skills/bump/tools/get-latest-release.tl: get the latest release of a GitHub repo
--
-- queries the latest release via gh api and returns tag name and asset download URL.
-- module tool: returns a Tool record for ah to load via -t

local run = require("lib.gh.run")

return {
  name = "get_latest_release",
  description = "Get the latest release tag and asset download URL for a GitHub repository.",
  input_schema = {
    type = "object",
    properties = {
      repo = {type = "string", description = "Repository in owner/repo format (e.g. whilp/ah)"},
      asset_name = {type = "string", description = "Name of the release asset to find (e.g. ah or cosmic-lua)"},
    },
    required = {"repo", "asset_name"},
  },
  execute = function(input: {string: any}): string
    local repo = input.repo as string
    if not repo or repo == "" then
      return "error: repo required"
    end

    local asset_name = input.asset_name as string
    if not asset_name or asset_name == "" then
      return "error: asset_name required"
    end

    local token = os.getenv("GH_TOKEN")
    if not token or token == "" then
      return "error: GH_TOKEN environment variable not set"
    end

    local argv: {string} = {
      "gh", "api",
      "repos/" .. repo .. "/releases/latest",
      "--jq", '.tag_name as $tag | .assets[] | select(.name == $asset) | $tag + " " + .browser_download_url',
      "--arg", "asset", asset_name,
    }

    local ok, out, code = run(argv)
    if not ok then
      if code == 4 then
        return "error: gh access denied (exit 4): " .. (out or "")
      end
      return "error: gh failed (exit " .. tostring(code) .. "): " .. (out or "")
    end

    local output = (out or ""):gsub("%s+$", "")
    if output == "" then
      return "error: asset " .. asset_name .. " not found in latest release of " .. repo
    end

    local tag, url = output:match("^(%S+)%s+(%S+)$")
    if not tag or not url then
      return "error: unexpected output format: " .. output
    end

    return "tag=" .. tag .. " url=" .. url
  end,
}
