local parser = require("sanitizer.parser")
local base_dir = "tests/fixtures/"

local input = io.open(base_dir .. "output/tsan_race.txt"):read("*a")
local res = parser.parse(input)
local user = parser.filter_user_frames(res.frames, base_dir .. "projects")

print(vim.inspect(res))
print(vim.inspect(user))
