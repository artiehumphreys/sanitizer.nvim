local new_set = MiniTest.new_set

local T = new_set()

if not os.getenv("CI") then
  return T
end

local runner = require("sanitizer.runner")
local parser = require("sanitizer.parser")

local project_base = "tests/fixtures/projects"

local timeout = 25000

local all_cases = {
  { sanitizer = "address", project = "uaf", error_pattern = "use%-after%-free" },
  { sanitizer = "undefined", project = "ub", error_pattern = "overflow" },
  { sanitizer = "thread", project = "race", error_pattern = "data race" },
  { sanitizer = "memory", project = "mem", error_pattern = "use%-of%-uninitialized%-value" },
  { sanitizer = "leak", project = "leak", error_pattern = "leak" },
}

local sanitizer_filter = os.getenv("SANITIZER")
local expected = {}
for _, case in ipairs(all_cases) do
  if not sanitizer_filter or case.sanitizer == sanitizer_filter then
    table.insert(expected, case)
  end
end

---@param sanitizer string
---@param project string
---@return boolean
---@return string
---@return SanitizerResult?
local function build_and_parse(sanitizer, project)
  local project_root = project_base .. "/" .. project
  local target = project .. "-test"

  local build_done = false
  local build_ok, build_err

  runner.build(sanitizer, project_root, nil, function(ok, err)
    build_ok = ok
    build_err = err
    build_done = true
  end)

  vim.wait(timeout, function()
    return build_done
  end)

  if not build_ok then
    return false, "build failed: " .. (build_err and build_err.message or "unknown"), nil
  end

  local run_done = false
  local run_output

  runner.run(sanitizer, project_root, target, function(_, output)
    run_output = output
    run_done = true
  end)

  vim.wait(timeout, function()
    return run_done
  end)

  if not run_output or run_output == "" then
    return false, "no sanitizer output captured", nil
  end

  local result = parser.parse(run_output)
  return true, run_output, result
end

for _, case in ipairs(expected) do
  T[case.sanitizer] = new_set()

  T[case.sanitizer]["is output parseable"] = function()
    local ok, output, result = build_and_parse(case.sanitizer, case.project)
    assert(ok, output)
    assert(result, "parser result is nil for " .. case.sanitizer)
    assert(result.error_type, "parser returned nil error_type for " .. case.sanitizer)
    assert(
      result.error_type:lower():match(case.error_pattern),
      "error type does not match the case pattern "
        .. case.error_pattern
        .. " != "
        .. result.error_type
        .. " for "
        .. case.sanitizer
        .. ". The output is here\n"
        .. output
    )
  end

  T[case.sanitizer]["has frames"] = function()
    local ok, output, result = build_and_parse(case.sanitizer, case.project)
    assert(ok, output)
    assert(result, "parser result is nil for " .. case.sanitizer)
    assert(#result.frames > 0, "no frames parsed for " .. case.sanitizer)
  end

  T[case.sanitizer]["has user frames"] = function()
    local ok, output, result = build_and_parse(case.sanitizer, case.project)
    assert(ok, output)
    assert(result, "parser result is nil for " .. case.sanitizer)

    local project_root = project_base .. "/" .. case.project
    local user_frames = parser.filter_user_frames(result.frames, project_root)
    assert(#user_frames > 0, "no user frames for " .. case.sanitizer)
  end
end

---@param handle RunnerHandle
---@param err RunnerError?
---@param done boolean
local function assert_cancelled(handle, err, done)
  assert(done, "callback never fired")
  assert(err and err.type == "cancelled", "expected cancelled got " .. vim.inspect(err))
  assert(handle:stage() == "done")
  assert(not handle:is_running())
end

---@param project_base string
local function cancel_configure(project_base)
  local sanitizer = "thread"
  local project_root = project_base .. "/hang"

  local done = false
  local err_out = nil

  vim.env.SLOW_CONFIGURE = "1"
  local handle = runner.build(sanitizer, project_root, nil, function(_, err)
    done = true
    err_out = err
  end)

  -- let cmake spawn
  vim.wait(200)
  assert(handle:stage() == "configure")

  handle:cancel()
  vim.wait(3000, function()
    return done
  end)
  vim.env.SLOW_CONFIGURE = nil

  assert_cancelled(handle, err_out, done)
end

return T
