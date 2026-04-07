local M = {}

---@class SanitizerFrame
---@field func string
---@field file string?
---@field line number?
---@field binary string

---@class SanitizerResult
---@field frames SanitizerFrame[]
---@field summary string?
---@field sanitizer string?
---@field error_type string?

---@type table<string, string>
local PATTERNS = {
	frame = "^%s+#%d+%s+(.+)%s+%((.-)%)$",
	file_line = "(.+)%s+(.+):(%d+)$",
	summary = "^SUMMARY:%s+(.+)$",
	error_info = "ERROR:%s+(%w+):%s+(.+)%s+on",
	is_frame = "^%s+#%d+",
	is_summary = "^SUMMARY:",
	is_error = "ERROR:%s+%w+:",
}

---@param output string
---@return SanitizerResult
M.parse = function(output)
	local lines = vim.split(output, "\n")
	local result = { frames = {}, summary = nil, sanitizer = nil, error_type = nil }

	for _, line in ipairs(lines) do
		if line:match(PATTERNS.is_summary) then
			M.extract_summary(line, result)
		elseif line:match(PATTERNS.is_error) then
			M.extract_error_info(line, result)
		elseif line:match(PATTERNS.is_frame) then
			M.extract_stack_frame(line, result)
		end
	end

	return result
end

---@param line string
---@param result SanitizerResult
M.extract_stack_frame = function(line, result)
	local before, binary = line:match(PATTERNS.frame)
	if before ~= nil then
		local func, file, line_num = before:match(PATTERNS.file_line)
		if func then
			table.insert(result.frames, { func = func, file = file, line = tonumber(line_num), binary = binary })
		else
			-- when file is <null>
			-- TODO: should I keep them?
			table.insert(result.frames, { func = before, file = nil, line = nil, binary = binary })
		end
	end
end

---@param frames SanitizerFrame[]
---@param project_root string
M.filter_user_frames = function(frames, project_root)
	local user_frames = {}
	local project = require("sanitizer.project")
	local files = project.get_project_files(project_root)

	for _, frame in ipairs(frames) do
		if frame.file and files[frame.file] then
			table.insert(user_frames, files[frame.file])
		end
	end
end

return M
