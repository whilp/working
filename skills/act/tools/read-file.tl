-- skills/act/tools/read-file.tl: read a file and return its contents
--
-- module tool: returns a Tool record for ah to load via -t

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

      local f = io.open(path, "r")
      if not f then
         return "error: could not open " .. path
      end

      local content = f:read("*a")
      f:close()
      return content or ""
   end,
}
