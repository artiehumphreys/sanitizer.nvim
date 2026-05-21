local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local T = new_set()

if not os.getenv("CI") then
  return T
end

local runner = require("sanitizer.runner")
local parser = require("sanitizer.parser")

local project_dir = "tests/projects/fixtures"

local timeout = 25000

local expected = {
  { sanitizer = "address", project = "uaf", error_pattern = "use%-after%-free" },
  { sanitizer = "undefined", project = "ub", error_pattern = "runtime error" },
  { sanitizer = "thread", project = "race", error_pattern = "data race" },
  { sanitizer = "memory", project = "mem", error_pattern = "use%-of%-uninitialized%-value" },
  { sanitizer = "leak", project = "uaf", error_pattern = "leak" },
}

---@param sanitizer string
---@param project string
---@return boolean
---@return string
---@return SanitizerResult?
local function build_and_parse(sanitizer, project)
  local project_root = project_dir .. "/" .. project
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

  runner.run(project_root, target, function(_, output)
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
  -- TODO: assert output
end

return T
