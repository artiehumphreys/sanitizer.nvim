local M = {}

---@class SanitizerFrame
---@field func string
---@field file string?
---@field line number?
---@field binary string?

---@class SanitizerResult
---@field frames SanitizerFrame[]
---@field summary string?
---@field sanitizer string?
---@field error_type string?

---@type table<string, string>
local PATTERNS = {
	frame_with_binary = "^%s+#%d+%s+(.+)%s+%((.-)%)$",
	frame_no_binary = "^%s+#%d+%s+(.+)$",
	addr_prefix = "^0x%x+%s+in%s+",
	file_line = "(.+)%s+([^:]+):(%d+)",
	summary = "^SUMMARY:%s+(.+)$",
	error_info = "(%w+Sanitizer):%s+(.+)$",
	is_frame = "^%s+#%d+",
	is_summary = "^SUMMARY:",
	is_error = "%w+Sanitizer:",
	ubsan_error = "(.+):(%d+):%d+:%s+runtime error:%s+(.+)$",
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

	if #result.frames == 0 then
		M.try_ubsan_format(lines, result)
	end

	return result
end

---@param line string
---@param result SanitizerResult
M.extract_summary = function(line, result)
	result.summary = line:match(PATTERNS.summary)
end

---@param line string
---@param result SanitizerResult
M.extract_error_info = function(line, result)
	local sanitizer, error_type = line:match(PATTERNS.error_info)
	result.sanitizer = result.sanitizer or sanitizer
	result.error_type = result.error_type or error_type
end

---@param line string
---@param result SanitizerResult
M.extract_stack_frame = function(line, result)
	local frame_info, binary = line:match(PATTERNS.frame_with_binary)
	if not frame_info then
		-- frames from user code may omit binary info
		frame_info = vim.trim(line:match(PATTERNS.frame_no_binary))
	end
	frame_info = frame_info:gsub(PATTERNS.addr_prefix, "")
	local func, file, line_num = frame_info:match(PATTERNS.file_line)
	if func then
		table.insert(result.frames, { func = func, file = file, line = tonumber(line_num), binary = binary })
	else
		-- <null> function
		table.insert(result.frames, { func = frame_info, file = nil, line = nil, binary = binary })
	end
end

---@param lines string[]
---@param result SanitizerResult
M.try_ubsan_format = function(lines, result)
	for _, line in ipairs(lines) do
		local file, line_num, desc = line:match(PATTERNS.ubsan_error)
		if file then
			table.insert(result.frames, { func = desc, file = vim.fn.fnamemodify(file, ":t"), line = tonumber(line_num), binary = nil })
			result.error_type = desc
			break
		end
	end

	if not result.sanitizer and result.summary then
		local sanitizer = result.summary:match(PATTERNS.error_info)
		if sanitizer then
			result.sanitizer = sanitizer
		end
	end
end

---@param frames SanitizerFrame[]
---@param project_root string
---@return SanitizerFrame[]
M.filter_user_frames = function(frames, project_root)
	local user_frames = {}
	local project = require("sanitizer.project")
	local files = project.get_project_files(project_root)

	for _, frame in ipairs(frames) do
		if frame.file and files[frame.file] then
			table.insert(user_frames, frame)
		end
	end

	return user_frames
end

return M
