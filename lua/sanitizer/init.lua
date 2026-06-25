local notify = require("sanitizer.log").notify

local M = {}

-- live handle of the running build/run
local active_handle

---@class sanitizer.Opts
---@field sanitizer? string
---@field target? string

---@return string?
local function get_project_root()
  local project_root = vim.uv.cwd()
  if not project_root then
    notify("Cannot determine project root", vim.log.levels.ERROR)
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

  active_handle = require("sanitizer.runner").build(
    args.sanitizer,
    project_root,
    args.target,
    function(ok, err)
      active_handle = nil
      log(ok, err)
    end
  )
end

---@param args sanitizer.Opts
M.run = function(args)
  local project_root = get_project_root()
  if not project_root then
    return
  end

  active_handle = require("sanitizer.runner").run(
    args.sanitizer,
    project_root,
    args.target,
    function(ok, output, err)
      active_handle = nil
      log(ok, err, output)
    end
  )
end

---@param args sanitizer.Opts
M.clean = function(args)
  local project_root = get_project_root()
  if not project_root then
    return
  end

  notify("Clearing build directory...")
  require("sanitizer.runner").clean(args.sanitizer, project_root, function(ok, err)
    log(ok, err, "Cleared build directory")
  end)
end

M.stop = function()
  if active_handle and active_handle:is_running() then
    active_handle:cancel()
  else
    notify("No running command to stop", vim.log.levels.WARN)
  end
end

M.results = function()
  -- TODO: render the last result in the notification window (sanitizer.notification)
  notify("results view not implemented yet")
end

---@type table<string, fun(args: string[])>
local subcommands = {
  build = function(args)
    M.build({ sanitizer = args[1], target = args[2] })
  end,
  run = function(args)
    M.run({ sanitizer = args[1], target = args[2] })
  end,
  clean = function(args)
    M.clean({ sanitizer = args[1] })
  end,
  stop = function()
    M.stop()
  end,
  results = function()
    M.results()
  end,
}

---@param fargs string[]
M.run_command = function(fargs)
  local subcommand = fargs[1]
  local handler = subcommands[subcommand]
  if not handler then
    notify("Unknown subcommand " .. tostring(subcommand), vim.log.levels.ERROR)
    return
  end

  handler(vim.list_slice(fargs, 2))
end

return M
