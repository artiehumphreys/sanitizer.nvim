local notify = require("sanitizer.log").notify

local M = {}

---@class sanitizer.BuildOpts
---@field sanitizer? string
---@field target? string

---@param args sanitizer.BuildOpts
M.build = function(args)
  local project_root = vim.uv.cwd()
  if not project_root then
    notify("cannot determine project root", vim.log.levels.ERROR)
    return
  end

  require("sanitizer.runner").build(args.sanitizer, project_root, args.target, function(ok, err)
    -- TODO: pop-up window with result
    notify(ok and "ok" or err.message)
  end)
end

---@type table<string, fun(args: string[])>
local subcommands = {
  build = function(args)
    M.build({ sanitizer = args[1], target = args[2] })
  end,
}

---@param fargs string[]
M.run_command = function(fargs)
  local subcommand = fargs[1]
  local handler = subcommands[subcommand]
  if not handler then
    notify("unknown subcommand " .. tostring(subcommand), vim.log.levels.ERROR)
    return
  end

  handler(vim.list_slice(fargs, 2))
end

return M
