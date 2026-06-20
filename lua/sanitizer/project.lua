local M = {}

local source_extensions =
  { c = true, cpp = true, h = true, hpp = true, cc = true, hh = true, cxx = true }

local excluded_dirs = { "build", "node_modules", ".git", ".vscode", ".idea", ".cache" }

local BUILD_DIR_PREFIX = "san_build"

---@param project_root string
---@param sanitizer string
---@return string
M.get_build_path = function(project_root, sanitizer)
  return vim.fs.joinpath(project_root, BUILD_DIR_PREFIX .. "_" .. sanitizer)
end

---@param project_root string
---@param sanitizer string
---@param target string
---@return string
M.get_executable_path = function(project_root, sanitizer, target)
  return vim.fs.joinpath(M.get_build_path(project_root, sanitizer), target)
end

---@param dir_path string
---@return boolean
local function is_excluded_dir(dir_path)
  for _, dir in ipairs(excluded_dirs) do
    if dir_path:find(dir, 1, true) then
      return true
    end
  end
  return false
end

---@param project_root string
---@return table<string, string>
M.get_project_files = function(project_root)
  local project_files = {}
  local files = vim.fs.find(function(name, path)
    if is_excluded_dir(path) then
      return false
    end
    local ext = name:match("%.([^%.]+)$")
    return source_extensions[ext or ""] == true
  end, {
    path = project_root,
    limit = math.huge,
    type = "file",
  })

  for _, file in ipairs(files) do
    local filename = vim.fn.fnamemodify(file, ":t")
    project_files[filename] = vim.fn.fnamemodify(file, ":p")
  end

  return project_files
end

---@param project_root string
---@return boolean
M.has_cmake_config = function(project_root)
  return vim.uv.fs_stat(vim.fs.joinpath(project_root, "CMakeLists.txt")) ~= nil
end

---@param name string
---@return string
M.normalize_sanitizer = function(name)
  return name and name:lower() or nil
end

---@return boolean
M.is_windows = function()
  return vim.uv.os_uname().sysname:find("Windows") ~= nil
end

return M
