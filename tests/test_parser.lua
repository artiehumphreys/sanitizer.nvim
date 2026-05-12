local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local T = new_set()

local parser = require("sanitizer.parser")
local base_dir = "tests/fixtures/"
local project_dir = base_dir .. "projects"

---@param name string
---@return SanitizerResult
---@return SanitizerFrame[]
local function parse_fixture(name)
  local input = io.open(base_dir .. "output/" .. name):read("*a")
  local res = parser.parse(input)

  local user_frames = parser.filter_user_frames(res.frames, project_dir)
  return res, user_frames
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

T["tsan"] = new_set()

T["tsan"]["test user frames"] = function()
  local _, user_frames = parse_fixture("tsan_race.txt")
  local lines = lines_from_frames(user_frames)
  eq(#user_frames, 4)
  eq(lines, { 14, 8, 7, 6 })
end

T["asan"] = new_set()

T["asan"]["test user frames"] = function()
  local _, user_frames = parse_fixture("asan_uaf.txt")
  local lines = lines_from_frames(user_frames)
  eq(#user_frames, 3)
  eq(lines, { 7, 5, 4 })
end

T["ubsan"] = new_set()

T["ubsan"]["test user frames"] = function()
  local _, user_frames = parse_fixture("ubsan_ub.txt")
  local lines = lines_from_frames(user_frames)
  eq(#user_frames, 1)
  eq(lines, { 10 })
end

return T
