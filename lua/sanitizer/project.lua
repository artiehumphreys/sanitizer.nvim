local M = {}

local source_extensions = { c = true, cpp = true, h = true, hpp = true, cc = true, hh = true }

local excluded_dirs = { "build", "node_modules" }

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
    return ext and source_extensions[ext] or false
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
  local found = vim.fs.find(function(name)
    return name:lower() == "cmakelists.txt"
  end, {
    path = project_root,
    limit = 1,
  })

  return #found > 0
end

return M
