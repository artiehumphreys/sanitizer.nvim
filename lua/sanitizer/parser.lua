local M = {}

local PATTERNS = {
	frame = "^%s+#%d+%s+(.+)%s+%((.-)%)$",
	file_line = "(.+)%s+(.+):(%d+)$",
	summary = "^SUMMARY:%s+(.+)$",
	error_info = "ERROR:%s+(%w+):%s+(.+)%s+on",
	is_frame = "^%s+#%d+",
	is_summary = "^SUMMARY:",
	is_error = "ERROR:%s+%w+:",
}

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

M.extract_stack_frame = function(line, result)
	local before, binary = line:match(PATTERNS.frame)
	if before ~= nil then
		local func, file, line_num = before:match(PATTERNS.file_line)
		-- TODO: build frame table and insert into result.frames
	end
end

M.filter_user_frames = function(frames, project_root) end

return M
