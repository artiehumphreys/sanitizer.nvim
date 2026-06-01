local new_set = MiniTest.new_set

local T = new_set()

if not os.getenv("CI") then
  return T
end

local runner = require("sanitizer.runner")
local parser = require("sanitizer.parser")

local project_base = "tests/fixtures/projects"

local timeout = 60000

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

  local build_handle = runner.build(sanitizer, project_root, nil, function(ok, err)
    build_ok = ok
    build_err = err
    build_done = true
  end)

  local build_fired = vim.wait(timeout, function()
    return build_done
  end)

  if not build_fired then
    return false,
      ("build callback never fired within %dms (stuck in stage=%q)"):format(
        timeout,
        build_handle:stage()
      ),
      nil
  end
  if not build_ok then
    return false, "build failed: " .. (build_err and build_err.message or "(no error message)"), nil
  end

  local run_done = false
  local run_output

  local run_handle = runner.run(sanitizer, project_root, target, function(_, output)
    run_output = output
    run_done = true
  end)

  local run_fired = vim.wait(timeout, function()
    return run_done
  end)

  if not run_fired then
    return false,
      ("run callback never fired within %dms (stuck in stage=%q)"):format(
        timeout,
        run_handle:stage()
      ),
      nil
  end
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

local function cancel_configure()
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

local function cancel_build()
  local sanitizer = "thread"
  local project_root = project_base .. "/hang"

  local done = false
  local err_out = nil

  -- SLOW_CONFIGURE unset so configure finishes fast
  vim.env.SLOW_BUILD = "1"
  local handle = runner.build(sanitizer, project_root, nil, function(_, err)
    done = true
    err_out = err
  end)

  vim.wait(10000, function()
    return handle:stage() == "build"
  end)
  assert(handle:stage() == "build")

  handle:cancel()
  vim.wait(3000, function()
    return done
  end)
  vim.env.SLOW_BUILD = nil

  assert_cancelled(handle, err_out, done)
end

T["cancel"] = new_set()
T["cancel"]["during configure"] = function()
  cancel_configure()
end
T["cancel"]["during build"] = function()
  cancel_build()
end

return T
