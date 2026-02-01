local translator = require("translator.module")

---@class WindowConfig
---@field width number Popup window width
---@field height number Popup window height
---@field title string Popup window title
---@field border string Border style (e.g., "rounded", "single", "double", "solid")
---@field title_pos string Title position (e.g., "center", "left", "right")

---@class Config
---@field default_target_lang string Default target language
---@field default_source_lang string|nil Default source language
---@field window WindowConfig Window configuration
local config = {
  default_target_lang = "zh",
  default_source_lang = nil,
  window = {
    width = 80,
    height = 20,
    title = " Translation ",
    border = "rounded",
    title_pos = "center",
  },
}

---@class Translator
local M = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

--- Get current word under cursor
---@return string|nil
local function get_current_word()
  return vim.fn.expand("<cword>")
end

--- Get visual selection text
---@return string|nil
local function get_visual_selection()
  -- Check if currently in visual mode
  local mode = vim.fn.mode()
  local in_visual = mode == "v" or mode == "V" or mode == "\22" -- \22 is <C-V>

  -- Determine positions based on whether we're in visual mode
  local start_pos, end_pos, vmode
  if in_visual then
    -- In visual mode: use "v" mark (start of selection) and "." (cursor)
    start_pos = vim.fn.getpos("v")
    end_pos = vim.fn.getpos(".")
    vmode = mode
    -- Exit visual mode to set the marks for future use
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  else
    -- Not in visual mode: use '< and '> marks
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
    vmode = vim.fn.visualmode()
    if vmode == "" or vmode == nil then
      vmode = "v"
    end
  end

  -- Ensure start_pos is before end_pos
  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    start_pos, end_pos = end_pos, start_pos
  end

  -- Use getregion for proper UTF-8 handling (Neovim 0.10+)
  if vim.fn.has("nvim-0.10") == 1 then
    local ok, region = pcall(vim.fn.getregion, start_pos, end_pos, { type = vmode })
    if ok and region and #region > 0 then
      return table.concat(region, "\n")
    end
  end

  -- Fallback for older Neovim versions or if getregion fails
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  if start_line == 0 or end_line == 0 then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  if #lines == 0 then
    return nil
  end

  -- Handle single line selection with UTF-8 awareness
  if #lines == 1 then
    lines[1] = vim.fn.strpart(lines[1], start_col - 1, end_col - start_col + 1)
  else
    lines[1] = vim.fn.strpart(lines[1], start_col - 1)
    lines[#lines] = vim.fn.strpart(lines[#lines], 0, end_col)
  end

  return table.concat(lines, "\n")
end

--- Show loading window
---@return number|nil win_id Window ID of the loading window
local function show_loading()
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set loading message
  local lines = { "  Translating...  " }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate position (center of screen)
  local width = 20
  local height = 1
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create loading window
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = false,
  }

  local win = vim.api.nvim_open_win(buf, false, opts)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  return win
end

--- Close loading window
---@param win_id number|nil Window ID to close
local function close_loading(win_id)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, true)
  end
end

--- Show translation result in popup window
---@param text string Translation result
local function show_popup(text)
  local buf = vim.api.nvim_create_buf(false, true)

  -- Split text into lines
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate popup position (center of screen)
  local width = M.config.window.width
  local height = math.min(M.config.window.height, #lines + 2)
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
    border = M.config.window.border,
    title = M.config.window.title,
    title_pos = M.config.window.title_pos,
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

  -- Show loading window
  local loading_win = show_loading()

  -- Perform translation
  local result, err = translator.translate(text, target_lang, source_lang)

  -- Close loading window
  close_loading(loading_win)

  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- Show result in popup
  if result then
    show_popup(result)
  end
end

--- Translate word under cursor
---@param opts table|nil Options table with to, from fields
M.translate_word = function(opts)
  opts = opts or {}

  -- Get word under cursor
  local word = get_current_word()

  if not word or word == "" then
    vim.notify("No word under cursor", vim.log.levels.WARN)
    return
  end

  -- Add the word to opts and call translate
  opts.text = word
  M.translate(opts)
end

--- Translate current word under cursor (exported API)
---@param opts table|nil Options table with to, from fields (e.g., { to = "zh", from = "en" })
M.transCurWord = function(opts)
  M.translate_word(opts)
end

--- Translate visual selection (exported API)
---@param opts table|nil Options table with to, from fields (e.g., { to = "zh", from = "en" })
M.transVisualSel = function(opts)
  opts = opts or {}
  -- Get visual selection
  local text = get_visual_selection()

  if not text or text == "" then
    vim.notify("No text selected", vim.log.levels.WARN)
    return
  end

  -- Add the text to opts and call translate
  opts.text = text
  M.translate(opts)
end

return M
