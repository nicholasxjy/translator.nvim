local translator = require("translator.module")

---@class Config
---@field default_target_lang string Default target language
---@field default_source_lang string|nil Default source language
---@field popup_width number Popup window width
---@field popup_height number Popup window height
local config = {
  default_target_lang = "zh",
  default_source_lang = nil,
  popup_width = 80,
  popup_height = 20,
}

---@class Translator
local M = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

--- Get visual selection text
---@return string|nil
local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  if start_line == 0 or end_line == 0 then
    return nil
  end

  local lines = vim.fn.getline(start_line, end_line)
  if type(lines) == "string" then
    lines = { lines }
  end

  if #lines == 0 then
    return nil
  end

  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  return table.concat(lines, "\n")
end

--- Show translation result in popup window
---@param text string Translation result
local function show_popup(text)
  local buf = vim.api.nvim_create_buf(false, true)

  -- Split text into lines
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate popup position (center of screen)
  local width = M.config.popup_width
  local height = math.min(M.config.popup_height, #lines + 2)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create popup window
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Translation ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  -- Close popup with q or <Esc>
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<cr>", { noremap = true, silent = true })
end

--- Main translate function
---@param opts table Options table with text, to, from fields
M.translate = function(opts)
  opts = opts or {}

  -- Get text to translate
  local text = opts.text
  if not text or text == "" then
    text = get_visual_selection()
  end

  if not text or text == "" then
    vim.notify("No text to translate", vim.log.levels.WARN)
    return
  end

  -- Get target language
  local target_lang = opts.to or M.config.default_target_lang
  -- Remove leading colon if present (e.g., ":zh" -> "zh")
  target_lang = target_lang:gsub("^:", "")

  -- Get source language
  local source_lang = opts.from or M.config.default_source_lang

  -- Perform translation
  local result, err = translator.translate(text, target_lang, source_lang)

  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- Show result in popup
  if result then
    show_popup(result)
  end
end

return M
