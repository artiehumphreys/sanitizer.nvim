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

-- module-level state
M._handle = nil
M._current = nil

---@class RunnerError
---@field type "configure"|"build"|"run"|"validation"
---@field message string
---@field code integer?

---@return boolean
local function is_running()
  return M._handle ~= nil and not M._handle:is_closing()
end

---@param build_cmd string[]
---@param on_complete fun(ok: boolean, err: RunnerError?)
local function run_cmake_build(build_cmd, on_complete)
  M._current = "build"
  M._handle = vim.system(build_cmd, {}, function(build_result)
    vim.schedule(function()
      if build_result.code ~= 0 then
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
M.build = function(sanitizer, project_root, target, on_complete)
  -- TODO: handle no cmake config cases
  if is_running() then
    vim.schedule(function()
      on_complete(false, {
        type = "validation",
        message = "Build is already running (use :San cancel to abort)",
      })
    end)
    return
  end

  sanitizer = sanitizer:lower()

  if not sanitizer_flags[sanitizer] then
    vim.schedule(function()
      on_complete(false, {
        type = "validation",
        message = "Invalid sanitizer. Choose from: address, thread, undefined, memory, leak",
      })
    end)
    return
  end

  local build_path = project.get_build_path(project_root, sanitizer)
  local flag = sanitizer_flags[sanitizer]

  local ok = vim.fn.mkdir(build_path, "p")
  if ok == 0 then
    vim.schedule(function()
      on_complete(false, {
        type = "validation",
        message = "Unable to create directory "
          .. build_path
          .. " . Please check folder permissions.",
      })
    end)
    return
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

  M._current = "configure"
  -- NOTE: vim.system returns a SystemObj handle when the command runs asynchronously
  M._handle = vim.system(configure_cmd, {}, function(configure_result)
    if configure_result.code ~= 0 then
      M._handle, M._current = nil, nil
      vim.schedule(function()
        on_complete(false, {
          type = "configure",
          message = configure_result.stderr,
          code = configure_result.code,
        })
      end)
      return
    end

    run_cmake_build(build_cmd, on_complete)
  end)
end

---@param sanitizer string
---@param project_root string
---@param target string
---@param on_complete fun(ok: boolean, output: string, err: RunnerError?)
M.run = function(sanitizer, project_root, target, on_complete)
  sanitizer = sanitizer:lower()
  local run_cmd = { project.get_executable_path(project_root, sanitizer, target) }
  M._current = "run"
  M._handle = vim.system(run_cmd, {}, function(run_result)
    local output = (run_result.stdout or "") .. (run_result.stderr or "")
    vim.schedule(function()
      if run_result.code ~= 0 then
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
end

return M
