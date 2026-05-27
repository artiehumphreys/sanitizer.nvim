local M = {}

local source_extensions =
  { c = true, cpp = true, h = true, hpp = true, cc = true, hh = true, cxx = true }

local excluded_dirs = { "build", "node_modules", ".git", ".vscode", ".idea", ".cache" }

local BUILD_DIR_PREFIX = "san_build"

---@param project_root string
---@param sanitizer string
---@return string
function M.get_build_path(project_root, sanitizer)
  return vim.fs.joinpath(project_root, BUILD_DIR_PREFIX .. "_" .. sanitizer)
end

---@param project_root string
---@param sanitizer string
---@param target string
---@return string
function M.get_executable_path(project_root, sanitizer, target)
  return vim.fs.joinpath(M.get_build_path(project_root, sanitizer), target)
end

--FIX: is this needed?
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
---@return boolean
M.has_cmake_config = function(project_root)
  return vim.uv.fs_stat(vim.fs.joinpath(project_root, "CMakeLists.txt")) ~= nil
end

return M
