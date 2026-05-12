local M = {}

local BUILD_DIR = "san_build"
local sanitizer_flags = {
  address = "-fsanitize=address",
  thread = "-fsanitize=thread",
  undefined = "-fsanitize=undefined",
}

---@class RunnerError
---@field type "configure"|"build"|"run"|"validation"
---@field message string
---@field code integer?

---@param sanitizer string
---@param project_root string
---@param target string?
---@param on_complete fun(ok: boolean, err: RunnerError?)
M.build = function(sanitizer, project_root, target, on_complete)
  if not sanitizer_flags[sanitizer:lower()] then
    on_complete(false, {
      type = "validation",
      message = "Invalid sanitizer. Choose from: address, thread, undefined",
    })
    return
  end

  local build_path = project_root .. "/" .. BUILD_DIR
  local flag = sanitizer_flags[sanitizer:lower()]

  vim.fn.mkdir(build_path, "p")

  local configure_cmd = {
    "cmake",
    "-S",
    project_root,
    "-B",
    build_path,
    "-DCMAKE_C_FLAGS=" .. flag,
    "-DCMAKE_CXX_FLAGS=" .. flag,
  }

  local build_cmd = { "cmake", "--build", build_path }

  if target then
    vim.list_extend(build_cmd, { "--target", target })
  end

  vim.system(configure_cmd, {}, function(configure_result)
    if configure_result.code ~= 0 then
      vim.schedule(function()
        on_complete(false, {
          type = "configure",
          message = configure_result.stderr,
          code = configure_result.code,
        })
      end)
      return
    end

    M.run_cmake_build(build_cmd, on_complete)
  end)
end

---@param build_cmd string[]
---@param on_complete fun(ok: boolean, err: RunnerError?)
M.run_cmake_build = function(build_cmd, on_complete)
  vim.system(build_cmd, {}, function(build_result)
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

---@param project_root string
---@param target string
---@param on_complete fun(ok: boolean, output: string, err: RunnerError?)
M.run = function(project_root, target, on_complete)
  local run_cmd = { project_root .. "/" .. BUILD_DIR .. "/" .. target }
  vim.system(run_cmd, {}, function(run_result)
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
