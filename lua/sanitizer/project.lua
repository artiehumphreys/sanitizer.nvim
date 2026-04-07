local M = {}

---@param project_root string
---@return table<string, string>
M.get_project_files = function(project_root)
	local res = {}
	local pattern = "**/*.{c,cpp,h,hpp,cc,hh}"
	local files = vim.fn.globpath(project_root, pattern, false, true)

	for _, file in ipairs(files) do
		if not file:find("build/") and not file:find("node_modules/") then
			local filename = vim.fn.fnamemodify(file, ":t")
			res[filename] = vim.fn.fnamemodify(file, ":p")
		end
	end

	return res
end

return M
