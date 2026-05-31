local M = {}

local tests = {}

local function it(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local function assert_equal(actual, expected, context)
  if not vim.deep_equal(actual, expected) then
    error(
      string.format(
        "%s\nexpected: %s\nactual: %s",
        context or "assertion failed",
        vim.inspect(expected),
        vim.inspect(actual)
      )
    )
  end
end

local function assert_truthy(value, context)
  if not value then
    error(context or "expected truthy value")
  end
end

local function with_translator(mock_module, fn)
  package.loaded["translator"] = nil
  package.loaded["translator.module"] = mock_module
  fn(require("translator"))
end

local function with_notify_capture(fn)
  local original_notify = vim.notify
  local messages = {}

  vim.notify = function(message, level)
    messages[#messages + 1] = { message = message, level = level }
  end

  local ok, err = pcall(fn, messages)
  vim.notify = original_notify

  if not ok then
    error(err)
  end
end

local function with_fake_windows(fn)
  local original_open_win = vim.api.nvim_open_win
  local original_win_set_option = vim.api.nvim_win_set_option
  local original_is_valid = vim.api.nvim_win_is_valid
  local original_close = vim.api.nvim_win_close
  local windows = {}
  local next_win = 1000

  vim.api.nvim_open_win = function(buf, _, opts)
    next_win = next_win + 1
    local window = vim.deepcopy(opts)
    window.buf = buf
    windows[#windows + 1] = window
    return next_win
  end

  vim.api.nvim_win_set_option = function() end

  vim.api.nvim_win_is_valid = function(win)
    return win >= 1001 and win <= next_win
  end

  vim.api.nvim_win_close = function() end

  local ok, err = pcall(fn, windows)

  vim.api.nvim_open_win = original_open_win
  vim.api.nvim_win_set_option = original_win_set_option
  vim.api.nvim_win_is_valid = original_is_valid
  vim.api.nvim_win_close = original_close

  if not ok then
    error(err)
  end
end

vim.cmd("source plugin/translator.lua")

it("parses bare text and key-value args", function()
  local command = require("translator.command")

  assert_equal(
    command.parse_args("hello world to=zh"),
    { text = "hello world", to = "zh" },
    "should parse bare text before options"
  )

  assert_equal(
    command.parse_args('text="hello world" from=en to=zh'),
    { text = "hello world", from = "en", to = "zh" },
    "should parse quoted text values"
  )

  assert_equal(
    command.parse_args("text=hello world to=zh"),
    { text = "hello world", to = "zh" },
    "should preserve multi-word text after text="
  )
end)

it("passes multi-word command text through :Trans", function()
  local captured

  with_fake_windows(function()
    with_notify_capture(function()
      with_translator({
        translate = function(text, target_lang, source_lang, callback)
          captured = { text = text, target_lang = target_lang, source_lang = source_lang }
          callback(nil, "forced test error")
        end,
      }, function()
        vim.cmd("Trans text=hello world to=zh")
      end)
    end)
  end)

  assert_equal(
    captured,
    { text = "hello world", target_lang = "zh", source_lang = nil },
    "command parser should pass full text"
  )
end)

it("translates the current word and normalizes the target language", function()
  local captured

  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 })

  with_fake_windows(function()
    with_notify_capture(function()
      with_translator({
        translate = function(text, target_lang, source_lang, callback)
          captured = { text = text, target_lang = target_lang, source_lang = source_lang }
          callback(nil, "forced test error")
        end,
      }, function(translator)
        translator.translate_word({ to = ":zh" })
      end)
    end)
  end)

  assert_equal(captured, { text = "hello", target_lang = "zh", source_lang = nil }, "translate_word should use <cword>")
end)

it("shows a warning when there is no text to translate", function()
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })

  with_notify_capture(function(messages)
    with_translator({
      translate = function()
        error("translator module should not be called when there is no text")
      end,
    }, function(translator)
      translator.translate({})
    end)

    assert_truthy(#messages > 0, "expected a warning notification")
    assert_equal(messages[1].message, "No text to translate", "unexpected warning message")
  end)
end)

it("clamps popup size to the current editor dimensions", function()
  local popup_opts
  local original_columns = vim.o.columns
  local original_lines = vim.o.lines

  vim.o.columns = 40
  vim.o.lines = 10

  with_fake_windows(function(windows)
    with_notify_capture(function()
      with_translator({
        translate = function(_, _, _, callback)
          callback("line 1\nline 2", nil)
        end,
      }, function(translator)
        translator.setup({
          window = {
            width = 120,
            height = 50,
          },
        })
        translator.translate({ text = "hello" })
      end)
    end)

    popup_opts = windows[2]
  end)

  vim.o.columns = original_columns
  vim.o.lines = original_lines

  assert_truthy(popup_opts ~= nil, "expected popup window to open")
  assert_equal(popup_opts.width, 36, "popup width should be clamped")
  assert_equal(popup_opts.height, 6, "popup height should be clamped")
end)

it("renders the redesigned translation popup with source, result, and key hints", function()
  local popup_buf

  with_fake_windows(function(windows)
    with_notify_capture(function()
      with_translator({
        translate = function(_, _, _, callback)
          callback("你好\n\nhello, hi", nil)
        end,
      }, function(translator)
        translator.setup({
          window = {
            width = 80,
            height = 20,
          },
        })
        translator.translate({ text = "hello", from = "en", to = "zh" })
      end)
    end)

    popup_buf = windows[2].buf
  end)

  local lines = vim.api.nvim_buf_get_lines(popup_buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  assert_truthy(content:find("SOURCE", 1, true), "popup should show a source pane")
  assert_truthy(content:find("TRANSLATION  en -> zh", 1, true), "popup should show language direction")
  assert_truthy(content:find("hello", 1, true), "popup should include the source text")
  assert_truthy(content:find("你好", 1, true), "popup should include the translation")
  assert_truthy(content:find("<leader>ts", 1, true), "popup should include selection shortcut")
  assert_truthy(content:find("q close", 1, true), "popup should include close hint")
end)

it("returns a clear error when translate-shell is unavailable", function()
  package.loaded["translator.module"] = nil
  local module = require("translator.module")
  local original_executable = vim.fn.executable
  local done = false
  local result
  local err

  vim.fn.executable = function()
    return 0
  end

  module.translate("hello", "zh", nil, function(res, message)
    result = res
    err = message
    done = true
  end)

  vim.fn.executable = original_executable

  assert_truthy(done, "expected callback to run immediately")
  assert_equal(result, nil, "result should be nil when trans is unavailable")
  assert_equal(
    err,
    "translate-shell executable `trans` not found. Install translate-shell and ensure it is on PATH.",
    "unexpected missing executable error"
  )
end)

it("runs translate-shell asynchronously through jobstart", function()
  package.loaded["translator.module"] = nil
  local module = require("translator.module")
  local original_executable = vim.fn.executable
  local original_jobstart = vim.fn.jobstart
  local captured_cmd
  local done = false
  local result
  local err

  vim.fn.executable = function()
    return 1
  end

  vim.fn.jobstart = function(cmd, opts)
    captured_cmd = cmd
    opts.on_stdout(nil, { "translated", "" })
    opts.on_stderr(nil, {})
    opts.on_exit(nil, 0)
    return 1
  end

  module.translate("hello", "zh", "en", function(res, message)
    result = res
    err = message
    done = true
  end)

  assert_truthy(
    vim.wait(200, function()
      return done
    end),
    "expected async callback to complete"
  )

  vim.fn.executable = original_executable
  vim.fn.jobstart = original_jobstart

  assert_equal(captured_cmd, { "trans", "en:zh", "-no-ansi", "hello" }, "unexpected translate command")
  assert_equal(result, "translated", "unexpected async result")
  assert_equal(err, nil, "did not expect an error on success")
end)

it("times out a translate-shell job that never exits", function()
  package.loaded["translator.module"] = nil
  local module = require("translator.module")
  local original_executable = vim.fn.executable
  local original_jobstart = vim.fn.jobstart
  local original_jobstop = vim.fn.jobstop
  local stopped_job
  local done = false
  local result
  local err

  vim.fn.executable = function()
    return 1
  end

  vim.fn.jobstart = function()
    return 42
  end

  vim.fn.jobstop = function(job_id)
    stopped_job = job_id
    return 1
  end

  module.translate("hello", "zh", nil, function(res, message)
    result = res
    err = message
    done = true
  end, 20)

  assert_truthy(
    vim.wait(200, function()
      return done
    end),
    "expected timeout callback to complete"
  )

  vim.fn.executable = original_executable
  vim.fn.jobstart = original_jobstart
  vim.fn.jobstop = original_jobstop

  assert_equal(stopped_job, 42, "timeout should stop the running job")
  assert_equal(result, nil, "result should be nil on timeout")
  assert_equal(err, "Translation timed out after 20ms", "unexpected timeout error")
end)

function M.run()
  local failures = {}

  for _, test in ipairs(tests) do
    local ok, err = pcall(test.fn)
    if ok then
      print("PASS " .. test.name)
    else
      failures[#failures + 1] = { name = test.name, err = err }
      print("FAIL " .. test.name)
      print(err)
    end
  end

  if #failures > 0 then
    error(string.format("%d test(s) failed", #failures))
  end
end

return M
