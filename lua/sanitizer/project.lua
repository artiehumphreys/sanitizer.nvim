local M = {}

---@param project_root string
---@return string[]
M.get_project_files = function(project_root)
	local res = {}
	local pattern = "**/*.{c,cpp,h,hpp,cc,hh}"
	local files = vim.fn.globpath(project_root, pattern, false, true)

	for _, file in ipairs(files) do
		local filename = vim.fn.fnamemodify(file, ":t")
		res[filename] = vim.fn.fnamemodify(file, ":p")
	end

	return res
end

return M
