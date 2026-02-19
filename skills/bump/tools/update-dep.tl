-- skills/bump/tools/update-dep.tl: update a dependency version file
--
-- downloads an asset, computes sha256, and writes deps/<dep>.mk.
-- module tool: returns a Tool record for ah to load via -t

local child = require("cosmic.child")
local cio = require("cosmic.io")

local function run(argv: {string}): boolean | string, string, number
  local h, err = child.spawn(argv, {
      stderr = 1,
    })
  if not h then
    return false, err or "spawn failed", -1
  end
  return h:read()
end

local valid_deps: {string: boolean} = {
  ah = true,
  cosmic = true,
}

return {
  name = "update_dep",
  description = "Download a release asset, compute its SHA256, and update the deps/<dep>.mk file.",
  input_schema = {
    type = "object",
    properties = {
      dep = {type = "string", description = "Dependency name: ah or cosmic"},
      url = {type = "string", description = "Download URL for the release asset"},
      sha = {type = "string", description = "SHA256 hash (optional — computed from download if omitted)"},
    },
    required = {"dep", "url"},
  },
  execute = function(input: {string: any}): string
    local dep = input.dep as string
    if not dep or dep == "" then
      return "error: dep required"
    end
    if not valid_deps[dep] then
      return "error: invalid dep: " .. dep .. " (must be ah or cosmic)"
    end

    local url = input.url as string
    if not url or url == "" then
      return "error: url required"
    end

    local sha = input.sha as string
    if not sha or sha == "" then
      local tmp = os.tmpname()
      local ok, out, code = run({"curl", "-fsSL", "-o", tmp, url})
      if not ok then
        os.remove(tmp)
        return "error: download failed (exit " .. tostring(code) .. "): " .. (out or "")
      end
      local sha_ok, sha_out, sha_code = run({"sha256sum", tmp})
      os.remove(tmp)
      if not sha_ok then
        return "error: sha256sum failed (exit " .. tostring(sha_code) .. "): " .. (sha_out or "")
      end
      sha = (sha_out or ""):match("^(%S+)")
      if not sha or sha == "" then
        return "error: could not parse sha256sum output"
      end
    end

    local content = dep .. "_url := " .. url .. "\n" .. dep .. "_sha := " .. sha .. "\n"
    local path = "o/repo/deps/" .. dep .. ".mk"
    cio.barf(path, content)

    return "ok: updated " .. path .. " (sha=" .. sha .. ")"
  end,
}
