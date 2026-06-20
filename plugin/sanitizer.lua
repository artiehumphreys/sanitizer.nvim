if vim.g.loaded_sanitizer then
  return
end
vim.g.loaded_sanitizer = true

vim.api.nvim_create_user_command("San", function(opts)
  require("sanitizer").run_command(opts.fargs)
end, {
  nargs = "+",
  complete = function(subcommand_arg_lead)
    local san_args = { "address", "leak", "memory", "thread", "undefined" }
    return vim
      .iter(san_args)
      :filter(function(arg)
        return arg:find(subcommand_arg_lead) ~= nil
      end)
      :totable()
  end,
})
