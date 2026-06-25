local new_set = MiniTest.new_set

local T = new_set()

local sanitizer = require("sanitizer")

-- Captures notifications raised during fn by stubbing vim.notify
local function captured_notify(fn)
  local msgs = {}
  local original = vim.notify
  vim.notify = function(msg, level)
    table.insert(msgs, { msg = msg, level = level })
  end
  local ok, err = pcall(fn)
  vim.notify = original
  assert(ok, err)
  return msgs
end

-- Temporarily replaces sanitizer[name] with a recording stub so dispatch can be
-- tested without spawning cmake
local function stub(name, replacement)
  local original = sanitizer[name]
  sanitizer[name] = replacement
  return function()
    sanitizer[name] = original
  end
end

T["run_command"] = new_set()

T["run_command"]["dispatches build with sanitizer and target"] = function()
  local got
  local restore = stub("build", function(args)
    got = args
  end)
  sanitizer.run_command({ "build", "address", "mytarget" })
  restore()

  assert(got, "build handler was not called")
  assert(got.sanitizer == "address", "sanitizer not forwarded, got " .. vim.inspect(got))
  assert(got.target == "mytarget", "target not forwarded, got " .. vim.inspect(got))
end

T["run_command"]["unknown subcommand errors without dispatching"] = function()
  local msgs = captured_notify(function()
    sanitizer.run_command({ "bogus", "address" })
  end)

  assert(#msgs == 1, "expected exactly one notification, got " .. #msgs)
  assert(msgs[1].msg:match("Unknown subcommand"), "got " .. msgs[1].msg)
  assert(msgs[1].level == vim.log.levels.ERROR, "expected ERROR level")
end

T["stop"] = new_set()

T["stop"]["no running command warns and does not error"] = function()
  local msgs = captured_notify(function()
    sanitizer.stop()
  end)

  assert(#msgs == 1, "expected exactly one notification, got " .. #msgs)
  assert(msgs[1].msg:match("No running command"), "got " .. msgs[1].msg)
  assert(msgs[1].level == vim.log.levels.WARN, "expected WARN level")
end

T["results"] = new_set()

T["results"]["placeholder reports not implemented"] = function()
  local msgs = captured_notify(function()
    sanitizer.results()
  end)

  assert(#msgs == 1, "expected exactly one notification, got " .. #msgs)
  assert(msgs[1].msg:match("not implemented"), "got " .. msgs[1].msg)
end

return T
