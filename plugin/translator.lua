local command = require("translator.command")

--- Create Trans command
vim.api.nvim_create_user_command("Trans", function(cmd_opts)
  local opts = command.parse_args(cmd_opts.args)
  require("translator").translate(opts)
end, {
  nargs = "*",
  range = true,
  desc = "Translate text using translate-shell",
})

--- Create TransWord command
vim.api.nvim_create_user_command("TransWord", function(cmd_opts)
  local opts = command.parse_args(cmd_opts.args)
  require("translator").translate_word(opts)
end, {
  nargs = "*",
  desc = "Translate word under cursor using translate-shell",
})
