if vim.g.loaded_sanitizer then
  return
end
vim.g.loaded_sanitizer = true

vim.api.nvim_create_user_command("San", function(opts)
  require("sanitizer").run_command(opts.fargs)
end, {
  nargs = "+",
})
