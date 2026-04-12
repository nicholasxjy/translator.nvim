local M = {}

local function tokenize(args)
  local tokens = {}
  local current = {}
  local quote
  local i = 1

  while i <= #args do
    local char = args:sub(i, i)

    if char == "\\" and i < #args then
      current[#current + 1] = args:sub(i + 1, i + 1)
      i = i + 2
    elseif quote then
      if char == quote then
        quote = nil
      else
        current[#current + 1] = char
      end
      i = i + 1
    else
      if char == "'" or char == '"' then
        quote = char
      elseif char:match("%s") then
        if #current > 0 then
          tokens[#tokens + 1] = table.concat(current)
          current = {}
        end
      else
        current[#current + 1] = char
      end
      i = i + 1
    end
  end

  if #current > 0 then
    tokens[#tokens + 1] = table.concat(current)
  end

  return tokens
end

--- Parse command arguments.
--- Supports:
---   - key=value pairs
---   - quoted values, e.g. text="hello world"
---   - bare text, e.g. :Trans hello world to=zh
---@param args string
---@return table
function M.parse_args(args)
  local opts = {}
  local text_parts = {}
  local tokens = tokenize(args or "")
  local i = 1

  while i <= #tokens do
    local token = tokens[i]
    local key, value = token:match("^(%w+)=(.*)$")

    if key == "text" then
      local parts = {}

      if value ~= "" then
        parts[#parts + 1] = value
      end

      i = i + 1
      while i <= #tokens and not tokens[i]:match("^%w+=") do
        parts[#parts + 1] = tokens[i]
        i = i + 1
      end

      opts.text = table.concat(parts, " ")
    elseif key then
      opts[key] = value
      i = i + 1
    else
      text_parts[#text_parts + 1] = token
      i = i + 1
    end
  end

  if (not opts.text or opts.text == "") and #text_parts > 0 then
    opts.text = table.concat(text_parts, " ")
  end

  return opts
end

return M
