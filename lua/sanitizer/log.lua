local M = {}

local prefix = "[sanitizer]: "

---@param message string
---@param level? integer
M.notify = function(message, level)
  vim.notify(prefix .. message, level or vim.log.levels.INFO)
end

return M
