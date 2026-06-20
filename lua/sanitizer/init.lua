local notify = require("sanitizer.log").notify

local M = {}

---@class sanitizer.Opts
---@field sanitizer? string
---@field target? string

---@return string?
local function get_project_root()
  local project_root = vim.uv.cwd()
  if not project_root then
    notify("cannot determine project root", vim.log.levels.ERROR)
    return nil
  end
  return project_root
end

---@param ok boolean
---@param err RunnerError?
---@param output string?
local function log(ok, err, output)
  -- TODO: pop-up window with result
  if ok then
    notify(output or "ok")
  else
    -- err always present when not ok: classify returns nil only on success
    local level = err.type == "cancelled" and vim.log.levels.WARN or vim.log.levels.ERROR
    ---@diagnostic disable-next-line: need-check-nil
    notify(err.message, level)
  end
end

---@param args sanitizer.Opts
M.build = function(args)
  local project_root = get_project_root()
  if not project_root then
    return
  end

  require("sanitizer.runner").build(args.sanitizer, project_root, args.target, log)
end

---@param args sanitizer.Opts
M.run = function(args)
  local project_root = get_project_root()
  if not project_root then
    return
  end

  require("sanitizer.runner").run(
    args.sanitizer,
    project_root,
    args.target,
    function(ok, output, err)
      log(ok, err, output)
    end
  )
end

---@type table<string, fun(args: string[])>
local subcommands = {
  build = function(args)
    M.build({ sanitizer = args[1], target = args[2] })
  end,
  run = function(args)
    M.run({ sanitizer = args[1], target = args[2] })
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

  if #fargs < 2 then
    notify(
      "please provide a sanitizer. Choose from address, thread, undefined, memory, leak",
      vim.log.levels.ERROR
    )
    return
  end
  -- get plugin args
  handler(vim.list_slice(fargs, 2))
end

return M
