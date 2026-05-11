local M = {}

local BUILD_DIR = "san_build"
local sanitizer_flags =
	{ address = "-fsanitize=address", thread = "-fsanitize=thread", undefined = "-fsanitize=undefined" }

local ERR_INVALID_SANITIZER = "The sanitizer you provided was invalid. Please from one of [address, thread, undefined]"

---@param sanitizer string
---@param project_root string
---@param target string?
---@param on_complete fun(ok: boolean, error_message: string?)
M.build = function(sanitizer, project_root, target, on_complete)
	if not sanitizer_flags[sanitizer:lower()] then
		on_complete(false, ERR_INVALID_SANITIZER)
		return
	end

	local build_path = project_root .. "/" .. BUILD_DIR
	local flag = sanitizer_flags[sanitizer:lower()]

	vim.fn.mkdir(build_path, "p")

	local configure_cmd =
		{ "cmake", "-S", project_root, "-B", build_path, "-DCMAKE_C_FLAGS=" .. flag, "-DCMAKE_CXX_FLAGS=" .. flag }

	local build_cmd = { "cmake", "--build", build_path }

	if target then
		vim.list_extend(build_cmd, { "--target", target })
	end

	vim.system(configure_cmd, {}, function(configure_result)
		if configure_result.code ~= 0 then
			vim.schedule(function() on_complete(false, configure_result.stderr) end)
			return
		end

		M.run_cmake_build(build_cmd, on_complete)
	end)
end

---@param build_cmd string[]
---@param on_complete fun(ok: boolean, error_message: string?)
M.run_cmake_build = function(build_cmd, on_complete)
	vim.system(build_cmd, {}, function(build_result)
		vim.schedule(function()
			if build_result.code ~= 0 then
				on_complete(false, build_result.stderr)
			else
				on_complete(true, nil)
			end
		end)
	end)
end

return M
