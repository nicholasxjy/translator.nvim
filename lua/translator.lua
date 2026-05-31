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
---@field timeout_ms number Translation command timeout in milliseconds
---@field window WindowConfig Window configuration
local defaults = {
  default_target_lang = "zh",
  default_source_lang = nil,
  timeout_ms = 15000,
  window = {
    width = 80,
    height = 20,
    title = " translator.nvim ",
    border = "rounded",
    title_pos = "center",
  },
}

---@class Translator
local M = {}

---@type Config
M.config = vim.deepcopy(defaults)

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), args or {})
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

local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(value, max_value))
end

local function get_editor_bounds()
  local width = clamp(vim.o.columns - 4, 1, vim.o.columns)
  local height = clamp(vim.o.lines - 4, 1, vim.o.lines)
  return width, height
end

local function display_width(text)
  return vim.fn.strdisplaywidth(text or "")
end

local function pad_right(text, width)
  local padding = width - display_width(text)
  if padding <= 0 then
    return text
  end

  return text .. string.rep(" ", padding)
end

local function center_text(text, width)
  local padding = width - display_width(text)
  if padding <= 0 then
    return text
  end

  local left_padding = math.floor(padding / 2)
  return string.rep(" ", left_padding) .. text .. string.rep(" ", padding - left_padding)
end

local function wrap_display(text, width)
  if not text or text == "" then
    return { "" }
  end

  local wrapped = {}

  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    if line == "" then
      wrapped[#wrapped + 1] = ""
    else
      local current = {}
      local current_width = 0
      local char_count = vim.fn.strchars(line)

      for i = 0, char_count - 1 do
        local char = vim.fn.strcharpart(line, i, 1)
        local char_width = display_width(char)

        if current_width > 0 and current_width + char_width > width then
          wrapped[#wrapped + 1] = table.concat(current)
          current = { char }
          current_width = char_width
        else
          current[#current + 1] = char
          current_width = current_width + char_width
        end
      end

      wrapped[#wrapped + 1] = table.concat(current)
    end
  end

  return wrapped
end

local function normalize_lang(lang)
  if not lang or lang == "" then
    return "auto"
  end

  return lang
end

--- Show loading window
---@param source_lang string|nil Source language
---@param target_lang string Target language
---@return number|nil win_id Window ID of the loading window
local function show_loading(source_lang, target_lang)
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set loading message
  local direction = normalize_lang(source_lang) .. " -> " .. normalize_lang(target_lang)
  local message = " Translating · " .. direction .. " "
  local lines = { message }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate position (center of screen)
  local max_width, _ = get_editor_bounds()
  local width = math.min(display_width(message), max_width)
  local height = 1
  local row = math.max(math.floor((vim.o.lines - height) / 2), 0)
  local col = math.max(math.floor((vim.o.columns - width) / 2), 0)

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

local function set_window_options(win, opts)
  opts = opts or {}
  vim.api.nvim_win_set_option(win, "wrap", opts.wrap == true)
  vim.api.nvim_win_set_option(win, "cursorline", opts.cursorline == true)
  vim.api.nvim_win_set_option(win, "signcolumn", "no")
  vim.api.nvim_win_set_option(win, "winhighlight", "Normal:NormalFloat,FloatBorder:FloatBorder")
end

local function make_popup_buffer(lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  if filetype then
    vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  end

  return buf
end

local function repeat_line(line, count)
  local lines = {}

  for _ = 1, count do
    lines[#lines + 1] = line
  end

  return lines
end

local function setup_popup_highlights()
  vim.api.nvim_set_hl(0, "TranslatorTitle", { default = true, link = "Title" })
  vim.api.nvim_set_hl(0, "TranslatorHeader", { default = true, link = "Identifier" })
  vim.api.nvim_set_hl(0, "TranslatorBorder", { default = true, link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "TranslatorKey", { default = true, link = "Special" })
  vim.api.nvim_set_hl(0, "TranslatorFooter", { default = true, link = "Comment" })
end

local function highlight_line(buf, ns, line, group)
  vim.api.nvim_buf_add_highlight(buf, ns, group, line, 0, -1)
end

local function apply_highlights(buf, lines, kind)
  local ns = vim.api.nvim_create_namespace("translator_popup")

  for i, line in ipairs(lines) do
    local line_index = i - 1

    if kind == "title" and line:find("translator.nvim", 1, true) then
      highlight_line(buf, ns, line_index, "TranslatorTitle")
    elseif line:find("SOURCE", 1, true) or line:find("TRANSLATION", 1, true) then
      highlight_line(buf, ns, line_index, "TranslatorHeader")
    elseif line:find("─", 1, true) or line:find("│", 1, true) then
      highlight_line(buf, ns, line_index, "TranslatorBorder")
    elseif line:find("<leader>", 1, true) or line:find(":Trans", 1, true) or line:find("q close", 1, true) then
      highlight_line(buf, ns, line_index, "TranslatorKey")
    elseif kind == "footer" or line:find("from:", 1, true) then
      highlight_line(buf, ns, line_index, "TranslatorFooter")
    end
  end
end

local function set_popup_keymaps(buf, close_popup)
  vim.keymap.set("n", "q", close_popup, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close_popup, { buffer = buf, nowait = true, silent = true })
end

local function footer_line(width, source_lang, target_lang)
  local from = normalize_lang(source_lang)
  local to = normalize_lang(target_lang)
  local left = "q close  Esc close  j/k scroll"
  local right = "from: " .. from .. "  to: " .. to
  local padding_width = math.max(display_width(left) + 1, width - display_width(right))

  return pad_right(left, padding_width) .. right
end

local function build_source_lines(source_text, target_lang, width)
  local to = normalize_lang(target_lang)
  local lines = {
    "SOURCE  VISUAL SELECTION",
    "",
  }

  vim.list_extend(lines, wrap_display(source_text, width))
  lines[#lines + 1] = ""
  vim.list_extend(lines, wrap_display("<leader>ts  translate selection", width))
  vim.list_extend(lines, wrap_display("<leader>tw  translate word", width))
  vim.list_extend(lines, wrap_display(":Trans to=" .. to .. "  command mode", width))

  return lines
end

local function build_result_lines(result, source_lang, target_lang, width)
  local direction = normalize_lang(source_lang) .. " -> " .. normalize_lang(target_lang)
  local lines = {
    "TRANSLATION  " .. direction,
    "",
  }

  vim.list_extend(lines, wrap_display(result, width))

  return lines
end

local function popup_layout()
  local max_width, max_height = get_editor_bounds()
  local width = clamp(M.config.window.width, 1, max_width)
  local height = clamp(M.config.window.height, 1, max_height)
  local row = math.max(math.floor((vim.o.lines - height) / 2), 0)
  local col = math.max(math.floor((vim.o.columns - width) / 2), 0)
  local header_height = math.min(2, math.max(height - 2, 1))
  local footer_height = height >= 5 and 1 or 0
  local body_height = math.max(height - header_height - footer_height, 1)
  local separator_width = width >= 40 and 1 or 0
  local left_width = math.floor(width * 0.38)

  if separator_width == 0 then
    left_width = 0
  else
    left_width = clamp(left_width, 12, math.max(12, width - separator_width - 20))
  end

  local right_width = math.max(width - left_width - separator_width, 1)

  return {
    width = width,
    height = height,
    row = row,
    col = col,
    inner_row = row + 1,
    inner_col = col + 1,
    header_height = header_height,
    footer_height = footer_height,
    body_height = body_height,
    left_width = left_width,
    separator_width = separator_width,
    right_width = right_width,
  }
end

--- Show translation result in popup window
---@param source_text string Source text
---@param text string Translation result
---@param source_lang string|nil Source language
---@param target_lang string Target language
local function show_popup(source_text, text, source_lang, target_lang)
  local layout = popup_layout()
  local frame_buf = make_popup_buffer(repeat_line(string.rep(" ", layout.width), layout.height))
  local header_lines = {
    center_text("translator.nvim", layout.width),
    string.rep("─", layout.width),
  }
  local header_buf = make_popup_buffer(header_lines)
  local source_lines = build_source_lines(source_text, target_lang, math.max(layout.left_width, 1))
  local source_buf = make_popup_buffer(source_lines)
  local separator_lines = repeat_line("│", layout.body_height)
  local separator_buf = make_popup_buffer(separator_lines)
  local result_lines = build_result_lines(text, source_lang, target_lang, layout.right_width)
  local result_buf = make_popup_buffer(result_lines, "markdown")
  local footer_lines = { footer_line(layout.width, source_lang, target_lang) }
  local footer_buf = make_popup_buffer(footer_lines)
  local wins = {}
  local result_win

  setup_popup_highlights()
  apply_highlights(header_buf, header_lines, "title")
  apply_highlights(source_buf, source_lines, "source")
  apply_highlights(separator_buf, separator_lines, "separator")
  apply_highlights(result_buf, result_lines, "result")
  apply_highlights(footer_buf, footer_lines, "footer")

  local function close_popup()
    for i = #wins, 1, -1 do
      local win = wins[i]
      if win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end

  for _, buf in ipairs({ source_buf, result_buf, footer_buf }) do
    set_popup_keymaps(buf, close_popup)
  end

  wins[#wins + 1] = vim.api.nvim_open_win(frame_buf, false, {
    relative = "editor",
    width = layout.width,
    height = layout.height,
    row = layout.row,
    col = layout.col,
    style = "minimal",
    border = M.config.window.border,
    title = M.config.window.title,
    title_pos = M.config.window.title_pos,
    focusable = false,
    zindex = 50,
  })

  wins[#wins + 1] = vim.api.nvim_open_win(header_buf, false, {
    relative = "editor",
    width = layout.width,
    height = layout.header_height,
    row = layout.inner_row,
    col = layout.inner_col,
    style = "minimal",
    focusable = false,
    zindex = 51,
  })

  if layout.left_width > 0 then
    wins[#wins + 1] = vim.api.nvim_open_win(source_buf, false, {
      relative = "editor",
      width = layout.left_width,
      height = layout.body_height,
      row = layout.inner_row + layout.header_height,
      col = layout.inner_col,
      style = "minimal",
      focusable = false,
      zindex = 51,
    })

    wins[#wins + 1] = vim.api.nvim_open_win(separator_buf, false, {
      relative = "editor",
      width = layout.separator_width,
      height = layout.body_height,
      row = layout.inner_row + layout.header_height,
      col = layout.inner_col + layout.left_width,
      style = "minimal",
      focusable = false,
      zindex = 51,
    })
  end

  result_win = vim.api.nvim_open_win(result_buf, true, {
    relative = "editor",
    width = layout.right_width,
    height = layout.body_height,
    row = layout.inner_row + layout.header_height,
    col = layout.inner_col + layout.left_width + layout.separator_width,
    style = "minimal",
    focusable = true,
    zindex = 52,
  })
  wins[#wins + 1] = result_win

  if layout.footer_height > 0 then
    wins[#wins + 1] = vim.api.nvim_open_win(footer_buf, false, {
      relative = "editor",
      width = layout.width,
      height = layout.footer_height,
      row = layout.inner_row + layout.header_height + layout.body_height,
      col = layout.inner_col,
      style = "minimal",
      focusable = false,
      zindex = 51,
    })
  end

  set_window_options(wins[1], { wrap = false, cursorline = false })
  for i = 2, #wins do
    set_window_options(wins[i], { wrap = false, cursorline = false })
  end
  set_window_options(result_win, { wrap = false, cursorline = true })

  return result_buf, result_win
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
  local loading_win = show_loading(source_lang, target_lang)

  translator.translate(text, target_lang, source_lang, function(result, err)
    close_loading(loading_win)

    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    if result and result ~= "" then
      show_popup(text, result, source_lang, target_lang)
      return
    end

    vim.notify("Translation returned no result", vim.log.levels.WARN)
  end, M.config.timeout_ms)
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
  M.translate(vim.tbl_extend("force", {}, opts, { text = word }))
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
  M.translate(vim.tbl_extend("force", {}, opts, { text = text }))
end

return M
