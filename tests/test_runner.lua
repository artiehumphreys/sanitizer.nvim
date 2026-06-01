local new_set = MiniTest.new_set

local T = new_set()

local project_root = "tests/fixtures/projects/uaf"

local runner = require("sanitizer.runner")

local function build_invalid_sanitizer()
  local sanitizer = "garbage"

  local done, ok, err = false, nil, nil
  local handle = runner.build(sanitizer, project_root, nil, function(o, e)
    done, ok, err = true, o, e
  end)

  local fired = vim.wait(1000, function()
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

T["build"] = new_set()
T["build"]["invalid sanitizer"] = function()
  build_invalid_sanitizer()
end
return T
