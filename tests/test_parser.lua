local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local T = new_set()

local parser = require("sanitizer.parser")

local ADDR_PREFIX_FMT = "0x%x in %s"
local FRAME_FMT = "    #%d %s (%s)"
local UBSAN_FMT = "%s:%d:5: runtime error: %s\nSUMMARY: %s"

-- Builders emit the noise a real sanitizer adds (numbering, address prefixes,
-- binary wrappers, SUMMARY) that the parser must strip back out, so a round trip
-- tests extraction rather than being the parser run in reverse.

-- FrameSpec is the structured input the builders turn into one stderr frame line.
---@class FrameSpec
---@field func string
---@field file string?  -- omit for a library frame (no file:line)
---@field line integer?
---@field binary string
---@field addr boolean?  -- emit the "0x.. in" prefix that asan adds, tsan omits

---@param spec FrameSpec
---@param idx integer
---@return string
local function frame_line(spec, idx)
  local body = spec.func
  if spec.file then
    body = body .. " " .. spec.file .. ":" .. spec.line
  end
  if spec.addr then
    body = ADDR_PREFIX_FMT:format(0x4a0000 + idx, body)
  end
  return FRAME_FMT:format(idx, body, spec.binary)
end

---@param header string
---@param frames FrameSpec[]
---@param summary string?
---@return string
local function stderr(header, frames, summary)
  local lines = { header }
  for i, f in ipairs(frames) do
    lines[#lines + 1] = frame_line(f, i - 1)
  end
  if summary then
    lines[#lines + 1] = "SUMMARY: " .. summary
  end
  return table.concat(lines, "\n")
end

---@param file string
---@param line integer
---@param desc string
---@param summary string
---@return string
local function ubsan_stderr(file, line, desc, summary)
  return UBSAN_FMT:format(file, line, desc, summary)
end

---@param frames SanitizerFrame[]
---@return integer[]
local function lines_from_frames(frames)
  local lines = {}
  for _, f in ipairs(frames) do
    table.insert(lines, f.line)
  end
  return lines
end

T["asan"] = new_set()

T["asan"]["parse: address-prefixed frames, error type, summary"] = function()
  local out =
    stderr("==9001==ERROR: AddressSanitizer: heap-use-after-free on address 0x602000000010", {
      {
        func = "useValue",
        file = "uaf/main.cpp",
        line = 7,
        binary = "uaf-test+0x1b2c",
        addr = true,
      },
      { func = "main", file = "uaf/main.cpp", line = 4, binary = "uaf-test+0x1a00", addr = true },
    }, "AddressSanitizer: heap-use-after-free main.cpp:7 in useValue")
  local res = parser.parse(out)
  eq(#res.frames, 2)
  eq(
    res.frames[1],
    { func = "useValue", file = "uaf/main.cpp", line = 7, binary = "uaf-test+0x1b2c" }
  )
  eq(res.sanitizer, "AddressSanitizer")
  eq(res.error_type, "heap-use-after-free on address 0x602000000010")
  eq(res.summary, "AddressSanitizer: heap-use-after-free main.cpp:7 in useValue")
end

T["asan"]["parse: library frame keeps func, omits file and line"] = function()
  local out = stderr("==9001==ERROR: AddressSanitizer: heap-use-after-free on address 0x1", {
    { func = "__libc_start_main", binary = "libc.so.6+0x29", addr = true },
  })
  local res = parser.parse(out)
  eq(res.frames[1], { func = "__libc_start_main", binary = "libc.so.6+0x29" })
end

T["asan"]["filter: keeps project frames, drops others"] = function()
  local out = stderr("==9001==ERROR: AddressSanitizer: heap-use-after-free on address 0x1", {
    { func = "useValue", file = "uaf/main.cpp", line = 7, binary = "uaf-test+0x1b2c", addr = true },
    { func = "main", file = "uaf/main.cpp", line = 4, binary = "uaf-test+0x1a00", addr = true },
    { func = "__libc_start_main", binary = "libc.so.6+0x29", addr = true },
  })
  local res = parser.parse(out)
  local user = parser.filter_user_frames(res.frames, "tests/fixtures/projects/uaf")
  eq(#user, 2)
  eq(lines_from_frames(user), { 7, 4 })
end

T["tsan"] = new_set()

T["tsan"]["parse: frames without address prefix"] = function()
  local out = stderr("WARNING: ThreadSanitizer: data race (pid=12345)", {
    { func = "increment", file = "race/main.cpp", line = 8, binary = "race-test+0x12" },
    { func = "main", file = "race/main.cpp", line = 20, binary = "race-test+0x56" },
  })
  local res = parser.parse(out)
  eq(#res.frames, 2)
  eq(
    res.frames[1],
    { func = "increment", file = "race/main.cpp", line = 8, binary = "race-test+0x12" }
  )
  eq(res.sanitizer, "ThreadSanitizer")
  eq(res.error_type, "data race (pid=12345)")
end

T["tsan"]["filter: matches by basename across project sources"] = function()
  local out = stderr("WARNING: ThreadSanitizer: data race (pid=12345)", {
    { func = "increment", file = "race/main.cpp", line = 8, binary = "race-test+0x12" },
    { func = "main", file = "race/main.cpp", line = 20, binary = "race-test+0x56" },
  })
  local res = parser.parse(out)
  local user = parser.filter_user_frames(res.frames, "tests/fixtures/projects/race")
  eq(#user, 2)
  eq(lines_from_frames(user), { 8, 20 })
end

T["ubsan"] = new_set()

T["ubsan"]["parse: runtime-error format via fallback"] = function()
  local out = ubsan_stderr(
    "ub/main.cpp",
    10,
    "signed integer overflow: 2147483647 + 1 cannot be represented in type 'int'",
    "UndefinedBehaviorSanitizer: undefined-behavior ub/main.cpp:10:5"
  )
  local res = parser.parse(out)
  eq(#res.frames, 1)
  eq(res.frames[1], {
    func = "signed integer overflow: 2147483647 + 1 cannot be represented in type 'int'",
    file = "main.cpp",
    line = 10,
  })
  eq(res.sanitizer, "UndefinedBehaviorSanitizer")
  eq(res.error_type, "signed integer overflow: 2147483647 + 1 cannot be represented in type 'int'")
end

return T
