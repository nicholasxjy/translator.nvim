--- Parse command arguments in format: key=value key=value
---@param args string Command arguments string
---@return table Parsed options
local function parse_args(args)
  local opts = {}

  -- Match key=value pairs
  for key, value in string.gmatch(args, "(%w+)=([^%s]+)") do
    opts[key] = value
  end

  return opts
end

--- Create Trans command
vim.api.nvim_create_user_command("Trans", function(cmd_opts)
  local opts = parse_args(cmd_opts.args)
  require("translator").translate(opts)
end, {
  nargs = "*",
  range = true,
  desc = "Translate text using translate-shell",
})

--- Create TransWord command
vim.api.nvim_create_user_command("TransWord", function(cmd_opts)
  local opts = parse_args(cmd_opts.args)
  require("translator").translate_word(opts)
end, {
  nargs = "*",
  desc = "Translate word under cursor using translate-shell",
})

