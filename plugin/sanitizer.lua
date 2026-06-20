if vim.g.loaded_sanitizer then
  return
end
vim.g.loaded_sanitizer = true

local sanitizers = { "address", "thread", "undefined", "memory", "leak" }

local arg_completions = {
  build = { sanitizers },
  run = { sanitizers },
  clean = { sanitizers },
  results = {},
  stop = {},
}

vim.api.nvim_create_user_command("San", function(opts)
  require("sanitizer").run_command(opts.fargs)
end, {
  nargs = "+",
  complete = function(arg_lead, cmd_line, _)
    local words = vim.split(vim.trim(cmd_line), "%s+")
    local typing_new = cmd_line:sub(-1) == " "

    local argc = #words - 1 + (typing_new and 1 or 0)

    local candidates
    if argc == 1 then
      candidates = vim.tbl_keys(arg_completions)
    else
      local subcommand = words[2]
      local spec = arg_completions[subcommand]
      candidates = spec and spec[argc - 1] or {}
    end
    return vim
      .iter(candidates)
      :filter(function(c)
        return vim.startswith(c, arg_lead)
      end)
      :totable()
  end,
})
