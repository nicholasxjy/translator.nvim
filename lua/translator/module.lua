---@class TranslatorModule
local M = {}

--- Execute translate-shell command
---@param text string The text to translate
---@param target_lang string Target language (e.g., "zh", "en")
---@param source_lang string|nil Source language (optional)
---@return string|nil result Translation result
---@return string|nil error Error message if failed
M.translate = function(text, target_lang, source_lang)
  if not text or text == "" then
    return nil, "No text to translate"
  end

  -- Build translate-shell command
  local cmd = { "trans" }

  -- Add source and target language
  if source_lang then
    table.insert(cmd, source_lang .. ":" .. target_lang)
  else
    table.insert(cmd, ":" .. target_lang)
  end

  -- Add border flag for better formatting
  table.insert(cmd, "-no-ansi")

  -- Add text to translate
  table.insert(cmd, text)

  -- Execute command
  local result = vim.fn.system(cmd)

  -- Check for errors
  if vim.v.shell_error ~= 0 then
    return nil, "Translation failed: " .. result
  end

  return result, nil
end

return M
