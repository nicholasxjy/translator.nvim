---@class TranslatorModule
local M = {}

local function build_command(text, target_lang, source_lang)
  local cmd = { "trans" }

  if source_lang and source_lang ~= "" then
    cmd[#cmd + 1] = source_lang .. ":" .. target_lang
  else
    cmd[#cmd + 1] = ":" .. target_lang
  end

  cmd[#cmd + 1] = "-no-ansi"
  cmd[#cmd + 1] = text

  return cmd
end

local function collect_chunks(chunks)
  if type(chunks) ~= "table" then
    return ""
  end

  local lines = {}
  for _, chunk in ipairs(chunks) do
    if chunk and chunk ~= "" then
      lines[#lines + 1] = chunk
    end
  end

  return table.concat(lines, "\n")
end

--- Execute translate-shell command asynchronously.
---@param text string The text to translate
---@param target_lang string Target language (e.g., "zh", "en")
---@param source_lang string|nil Source language (optional)
---@param on_complete fun(result:string|nil, err:string|nil)
---@return integer|nil job_id
M.translate = function(text, target_lang, source_lang, on_complete)
  if not text or text == "" then
    on_complete(nil, "No text to translate")
    return nil
  end

  if vim.fn.executable("trans") ~= 1 then
    on_complete(nil, "translate-shell executable `trans` not found. Install translate-shell and ensure it is on PATH.")
    return nil
  end

  local cmd = build_command(text, target_lang, source_lang)
  local stdout = {}
  local stderr = {}

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout = data or stdout
    end,
    on_stderr = function(_, data)
      stderr = data or stderr
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        local result = vim.trim(collect_chunks(stdout))
        local err_output = vim.trim(collect_chunks(stderr))

        if code ~= 0 then
          local message = err_output ~= "" and err_output or result
          if message == "" then
            message = "translate-shell exited with code " .. code
          end
          on_complete(nil, "Translation failed: " .. message)
          return
        end

        on_complete(result, nil)
      end)
    end,
  })

  if job_id <= 0 then
    on_complete(nil, "Failed to start translate-shell command")
    return nil
  end

  return job_id
end

return M
