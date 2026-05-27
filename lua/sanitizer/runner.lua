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
---@field _handle vim.SystemObj?
---@field _stage "idle"|"configure"|"build"|"run"|"done"
---@field _cancelled boolean
local RunnerHandle = {}
RunnerHandle.__index = RunnerHandle

---@return RunnerHandle
function RunnerHandle.new()
  return setmetatable({
    _handle = nil,
    _stage = "idle",
    _cancelled = false,
  }, RunnerHandle)
end

function RunnerHandle:cancel()
  if self._handle and not self._handle:is_closing() then
    self._cancelled = true
    self._handle:kill("sigterm")
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
---@param build_cmd string[]
---@param on_complete fun(ok: boolean, err: RunnerError?)
local function run_cmake_build(handle, build_cmd, on_complete)
  handle._stage = "build"
  handle._handle = vim.system(build_cmd, {}, function(build_result)
    handle._stage = "done"
    vim.schedule(function()
      if handle._cancelled then
        on_complete(false, { type = "cancelled", message = "build cancelled" })
      elseif build_result.code ~= 0 then
        on_complete(false, {
          type = "build",
          message = build_result.stderr,
          code = build_result.code,
        })
      else
        on_complete(true, nil)
      end
    end)
  end)
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

  local configure_cmd = {
    "cmake",
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

  local build_cmd = { "cmake", "--build", build_path }

  if target then
    vim.list_extend(build_cmd, { "--target", target })
  end

  handle._stage = "configure"
  -- NOTE: vim.system returns a SystemObj handle when the command runs asynchronously
  handle._handle = vim.system(configure_cmd, {}, function(configure_result)
    if handle._cancelled then
      handle._stage = "done"
      vim.schedule(function()
        on_complete(false, { type = "cancelled", message = "build cancelled" })
      end)
      return
    end
    if configure_result.code ~= 0 then
      handle._stage = "done"
      vim.schedule(function()
        on_complete(false, {
          type = "configure",
          message = configure_result.stderr,
          code = configure_result.code,
        })
      end)
      return
    end

    run_cmake_build(handle, build_cmd, on_complete)
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

  local run_cmd = { project.get_executable_path(project_root, sanitizer, target) }
  handle._stage = "run"
  handle._handle = vim.system(run_cmd, {}, function(run_result)
    local output = (run_result.stdout or "") .. (run_result.stderr or "")
    handle._stage = "done"
    vim.schedule(function()
      if handle._cancelled then
        on_complete(false, output, { type = "cancelled", message = "run cancelled" })
      elseif run_result.code ~= 0 then
        on_complete(false, output, {
          type = "run",
          message = run_result.stderr,
          code = run_result.code,
        })
      else
        on_complete(true, output, nil)
      end
    end)
  end)

  return handle
end

return M
