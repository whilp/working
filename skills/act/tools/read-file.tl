-- skills/act/tools/read-file.tl: read a file and return its contents
--
-- module tool: returns a Tool record for ah to load via -t

local cio = require("cosmic.io")

return {
   name = "read_file",
   description = "Read the contents of a file and return it as a string.",
   input_schema = {
      type = "object",
      properties = {
         path = {type = "string", description = "Path to the file to read"},
      },
      required = {"path"},
   },
   execute = function(input: {string:any}): string
      local path = input.path as string
      if not path or path == "" then
         return "error: path required"
      end

      local content, err = cio.slurp(path)
      if not content then
         return "error: " .. (err or "could not read " .. path)
      end
      return content
   end,
}
