local M = {}

local project = require("sanitizer.project")

local sanitizer_flags = {
  address = "-fsanitize=address",
  thread = "-fsanitize=thread",
  undefined = "-fsanitize=undefined",
  memory = "-fsanitize=memory -fsanitize-memory-track-origins",
  leak = "-fsanitize=leak",
}

local COMMON_FLAGS = "-fno-omit-frame-pointer -g -O1"

---@class RunnerError
---@field type "configure"|"build"|"run"|"validation"|"cancelled"
---@field message string
---@field code integer?

---@class RunnerHandle
---@field _handle uv.uv_process_t?
---@field _stage "idle"|"configure"|"build"|"run"|"done"
---@field _cancelled boolean
---@field _pid integer
local RunnerHandle = {}
RunnerHandle.__index = RunnerHandle

---@return RunnerHandle
function RunnerHandle.new()
  return setmetatable({
    _handle = nil,
    _stage = "idle",
    _cancelled = false,
    _pid = nil,
  }, RunnerHandle)
end

function RunnerHandle:cancel()
  if self._handle and not self._handle:is_closing() then
    self._cancelled = true
    if project.is_windows() then
      vim.system({ "taskkill", "/PID", tostring(self._pid), "/T", "/F" })
    else
      vim.uv.kill(-self._pid, "sigterm")
    end
  end
end

---@return boolean
function RunnerHandle:is_running()
  return self._stage ~= "idle" and self._stage ~= "done"
end

---@return string
function RunnerHandle:stage()
  return self._stage
end

---@param handle RunnerHandle
---@param cmd string
---@param args string[]
---@param on_exit fun(code: integer?, output: string)
local function execute_command(handle, cmd, args, on_exit)
  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)

  -- fds exhausted
  if not stdout or not stderr then
    if stdout then
      stdout:close()
    end
    if stderr then
      stderr:close()
    end
    vim.schedule(function()
      on_exit(nil, "failed to create pipe")
    end)
    return
  end

  local chunks = {}

  local function on_read(_err, data)
    if data then
      table.insert(chunks, data)
    end
  end

  local function close_fds()
    if not stdout:is_closing() then
      stdout:close()
    end
    if not stderr:is_closing() then
      stderr:close()
    end
  end

  local proc, pid = vim.uv.spawn(cmd, {
    args = args,
    stdio = { nil, stdout, stderr },
    detached = true,
  }, function(code)
    stdout:read_stop()
    stderr:read_stop()
    close_fds()
    if handle._handle and not handle._handle:is_closing() then
      handle._handle:close()
    end
    handle._handle = nil
    vim.schedule(function()
      on_exit(code, table.concat(chunks))
    end)
  end)

  -- spawn failed synchronously: proc is nil, pid holds the errno string, and the
  -- exit callback above never fires. Report it ourselves.
  if not proc then
    close_fds()
    vim.schedule(function()
      on_exit(nil, pid --[[@as string]])
    end)
    return
  end

  handle._handle, handle._pid = proc, pid --[[@as integer]]
  stdout:read_start(on_read)
  stderr:read_start(on_read)
end

---@param stage "configure"|"build"|"run"
---@param cancelled boolean
---@param code integer?
---@param output string
---@return RunnerError?
local function classify(stage, cancelled, code, output)
  if cancelled then
    return { type = "cancelled", message = stage .. " cancelled" }
  elseif code == nil then
    return { type = stage, message = "failed to spawn: " .. output }
  elseif code ~= 0 then
    return { type = stage, message = output, code = code }
  end
end

---@param sanitizer string
---@param project_root string
---@param target string?
---@param on_complete fun(ok: boolean, err: RunnerError?)
---@return RunnerHandle
M.build = function(sanitizer, project_root, target, on_complete)
  -- TODO: handle no cmake config cases
  local handle = RunnerHandle.new()
  sanitizer = project.normalize_sanitizer(sanitizer)

  local function fail(msg)
    handle._stage = "done"
    vim.schedule(function()
      on_complete(false, { type = "validation", message = msg })
    end)
    return handle
  end

  if not sanitizer_flags[sanitizer] then
    return fail("Invalid sanitizer. Choose from: address, thread, undefined, memory, leak")
  end

  local build_path = project.get_build_path(project_root, sanitizer)
  local flag = sanitizer_flags[sanitizer]

  if vim.fn.mkdir(build_path, "p") == 0 then
    return fail("Unable to create directory " .. build_path .. " . Check folder permissions.")
  end

  local cmd = "cmake"
  local configure_args = {
    "-S",
    project_root,
    "-B",
    build_path,
    "-DCMAKE_C_FLAGS=" .. flag .. " " .. COMMON_FLAGS,
    "-DCMAKE_CXX_FLAGS=" .. flag .. " " .. COMMON_FLAGS,
    "-DCMAKE_EXE_LINKER_FLAGS=" .. flag,
    "-DCMAKE_SHARED_LINKER_FLAGS=" .. flag,
    "-DCMAKE_MODULE_LINKER_FLAGS=" .. flag,
  }

  local build_args = { "--build", build_path }

  if target then
    vim.list_extend(build_args, { "--target", target })
  end

  handle._stage = "configure"
  execute_command(handle, cmd, configure_args, function(code, output)
    local err = classify("configure", handle._cancelled, code, output)
    if err then
      handle._stage = "done"
      on_complete(false, err)
      return
    end

    handle._stage = "build"
    execute_command(handle, cmd, build_args, function(build_code, build_output)
      handle._stage = "done"
      local build_err = classify("build", handle._cancelled, build_code, build_output)
      on_complete(build_err == nil, build_err)
    end)
  end)

  return handle
end

---@param sanitizer string
---@param project_root string
---@param target string
---@param on_complete fun(ok: boolean, output: string, err: RunnerError?)
---@return RunnerHandle
M.run = function(sanitizer, project_root, target, on_complete)
  local handle = RunnerHandle.new()
  sanitizer = project.normalize_sanitizer(sanitizer)

  if not sanitizer_flags[sanitizer] then
    handle._stage = "done"
    vim.schedule(function()
      on_complete(false, "", {
        type = "validation",
        message = "Invalid sanitizer. Choose from: address, thread, undefined, memory, leak",
      })
    end)
    return handle
  end

  local executable = project.get_executable_path(project_root, sanitizer, target)
  handle._stage = "run"
  execute_command(handle, executable, {}, function(code, output)
    handle._stage = "done"
    local err = classify("run", handle._cancelled, code, output)
    on_complete(err == nil, output, err)
  end)

  return handle
end

return M
