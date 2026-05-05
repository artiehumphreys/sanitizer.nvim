local parser = require("sanitizer.parser")
local base_dir = "tests/fixtures/"

local input = io.open(base_dir .. "output/tsan_race.txt"):read("*a")
local res = parser.parse(input)
local user = parser.filter_user_frames(res.frames, base_dir .. "projects")

print("--- TSan Output ---")
print(vim.inspect(res))
print(vim.inspect(user))

input = io.open(base_dir .. "output/uaf_asan.txt"):read("*a")
res = parser.parse(input)
user = parser.filter_user_frames(res.frames, base_dir .. "projects")

print("--- ASan Output ---")
print(vim.inspect(res))
print(vim.inspect(user))
