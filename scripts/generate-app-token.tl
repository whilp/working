-- scripts/generate-app-token.tl: generate a GitHub App installation access token
--
-- reads a PEM private key, builds a JWT, exchanges it for an installation token.
-- requires openssl for RSA-SHA256 signing.
--
-- usage:
--   cosmic scripts/generate-app-token.tl --app-id ID --installation-id ID --key path.pem
--
-- environment variables (fallback):
--   APP_ID, INSTALLATION_ID, PRIVATE_KEY_PATH

local child = require("cosmic.child")
local codec = require("cosmic.codec")
local cosmo = require("cosmo")
local cio = require("cosmic.io")
local env = require("cosmic.env")
local getopt = require("cosmic.getopt")
local json = require("cosmic.json")
local time = require("cosmic.time")
local unix = require("cosmo.unix")

local function die(msg: string)
  io.stderr:write("error: " .. msg .. "\n")
  os.exit(1)
end

local function base64url(data: string): string
  local b64 = codec.encode_base64(data)
  -- convert standard base64 to base64url: +->-, /->_, strip =
  return (b64:gsub("+", "-"):gsub("/", "_"):gsub("=", ""))
end

-- workaround: explicit env passthrough needed due to cosmic/issues/263
local function run(argv: {string}, stdin: string): string, number
  local h, err = child.spawn(argv, {
    stdin = stdin,
    env = unix.environ() as {string},
    stderr = 1,
  })
  if not h then
    die("spawn failed: " .. (err or "unknown"))
  end
  local ok, out, code = h:read()
  if not ok then
    return out or "", code
  end
  return out as string, code
end

local function sign_rs256(signing_input: string, key_path: string): string
  -- use openssl to sign with RSA-SHA256
  local out, code = run({
    "openssl", "dgst", "-sha256", "-sign", key_path, "-binary",
  }, signing_input)
  if code ~= 0 then
    die("openssl sign failed (exit " .. tostring(code) .. "): " .. (out or ""))
  end
  return out
end

local function build_jwt(app_id: string, key_path: string): string
  local now = time.now()
  local header = json.encode({alg = "RS256", typ = "JWT"})
  local payload = json.encode({
    iat = now - 60,
    exp = now + (10 * 60),
    iss = app_id,
  })

  local signing_input = base64url(header) .. "." .. base64url(payload)
  local signature = sign_rs256(signing_input, key_path)
  return signing_input .. "." .. base64url(signature)
end

local function fetch_token(jwt: string, installation_id: string): string
  local url = "https://api.github.com/app/installations/" .. installation_id .. "/access_tokens"
  local status, _, body = cosmo.Fetch(url, {
    method = "POST",
    headers = {
      ["Authorization"] = "Bearer " .. jwt,
      ["Accept"] = "application/vnd.github+json",
      ["User-Agent"] = "generate-app-token",
      ["X-GitHub-Api-Version"] = "2022-11-28",
    },
  })

  if status ~= 201 then
    die("github api failed (status " .. tostring(status) .. "): " .. (body or ""))
  end

  local resp = json.decode(body) as {string: string}
  if not resp or not resp.token then
    die("unexpected response: " .. (body or ""))
  end
  return resp.token
end

local function main()
  -- parse args
  local app_id: string
  local installation_id: string
  local key_path: string

  local parser = getopt.new(arg, "a:i:k:h", {
    {name = "app-id", has_arg = "required", short = "a"},
    {name = "installation-id", has_arg = "required", short = "i"},
    {name = "key", has_arg = "required", short = "k"},
    {name = "help", has_arg = "none", short = "h"},
  })

  while true do
    local opt, optarg = parser:next()
    if not opt then break end
    if opt == "a" then
      app_id = optarg
    elseif opt == "i" then
      installation_id = optarg
    elseif opt == "k" then
      key_path = optarg
    elseif opt == "h" then
      io.write("usage: cosmic scripts/generate-app-token.tl [options]\n")
      io.write("\n")
      io.write("options:\n")
      io.write("  -a, --app-id ID            github app id (or APP_ID env)\n")
      io.write("  -i, --installation-id ID   installation id (or INSTALLATION_ID env)\n")
      io.write("  -k, --key PATH             path to PEM private key (or PRIVATE_KEY_PATH env)\n")
      io.write("  -h, --help                 show this help\n")
      os.exit(0)
    end
  end

  -- fall back to env
  app_id = app_id or env.get("APP_ID")
  installation_id = installation_id or env.get("INSTALLATION_ID")
  key_path = key_path or env.get("PRIVATE_KEY_PATH")

  if not app_id or app_id == "" then die("app-id required") end
  if not installation_id or installation_id == "" then die("installation-id required") end
  if not key_path or key_path == "" then die("key path required") end

  -- validate key file exists
  local key_data, key_err = cio.slurp(key_path)
  if not key_data then
    die("cannot read key file: " .. (key_err or key_path))
  end

  local jwt = build_jwt(app_id, key_path)
  local token = fetch_token(jwt, installation_id)
  io.write(token .. "\n")
end

main()
