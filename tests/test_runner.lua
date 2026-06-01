local new_set = MiniTest.new_set

local T = new_set()

local project_root = "tests/fixtures/projects/uaf"
local bad_sanitizer = "garbage"
local timeout = 1000

local runner = require("sanitizer.runner")

local function build_invalid_sanitizer()
  local done, ok, err = false, nil, nil
  local handle = runner.build(bad_sanitizer, project_root, nil, function(o, e)
    done, ok, err = true, o, e
  end)

  local fired = vim.wait(timeout, function()
    return done
  end)

  assert(fired, "build callback was never fired for invalid sanitizer")
  assert(ok == false, "expected ok=false for invalid sanitizer")
  assert(
    err and err.type == "validation",
    "expected validation error for invalid sanitizer. Got" .. vim.inspect(err)
  )
  assert(handle:stage() == "done", "handle should be done after validation failure")
  assert(not handle:is_running(), "handle should not be running after validation error")
end

local function run_invalid_sanitizer()
  local done, ok, output, err = false, nil, nil, nil
  local handle = runner.run(bad_sanitizer, project_root, "uaf-test", function(o, out, e)
    done, ok, output, err = true, o, out, e
  end)

  local fired = vim.wait(timeout, function()
    return done
  end)

  assert(fired, "run callback was never fired for invalid sanitizer")
  assert(ok == false, "expected ok=false for invalid sanitizer")
  assert(output == "", "expected empty output for validation error, got" .. vim.inspect(output))
  assert(
    err and err.type == "validation",
    "expected validation error for invalid sanitizer. Got" .. vim.inspect(err)
  )
  assert(handle:stage() == "done", "handle should be done after validation failure")
  assert(not handle:is_running(), "handle should not be running after validation error")
end

T["build"] = new_set()
T["build"]["invalid sanitizer"] = function()
  build_invalid_sanitizer()
end

T["run"] = new_set()
T["run"]["invalid sanitizer"] = function()
  run_invalid_sanitizer()
end

return T
