local util = require "obsidian.util"

local M = {}

---@enum obsidian.completion.RefType
M.RefType = {
  Wiki = 1,
  Markdown = 2,
}

---Backtrack through a string to find the first occurrence of '[['.
---
---@param input string
---@return string|?, string|?, obsidian.completion.RefType|?
local find_search_start = function(input)
  for i = string.len(input), 1, -1 do
    local substr = string.sub(input, i)
    if vim.startswith(substr, "]") or vim.endswith(substr, "]") then
      return nil
    elseif vim.startswith(substr, "[[") then
      return substr, string.sub(substr, 3)
    elseif vim.startswith(substr, "[") and string.sub(input, i - 1, i - 1) ~= "[" then
      return substr, string.sub(substr, 2)
    end
  end
  return nil
end

---Check if a completion request can/should be carried out. Returns a boolean
---and, if true, the search string and the column indices of where the completion
---items should be inserted.
---
---@return boolean, string|?, integer|?, integer|?, obsidian.completion.RefType|?
M.can_complete = function(request)
  local input, search = find_search_start(request.context.cursor_before_line)
  if input == nil or search == nil or string.len(search) == 0 or util.is_whitespace(search) then
    return false
  end

  local until_cursor_len = vim.str_utfindex(request.context.cursor_before_line, #request.context.cursor_before_line)
  local cursor_col = vim.str_utfindex(request.context.cursor.col)
  local input_len = vim.str_utfindex(input, #input)

  if vim.startswith(input, "[[") then
    return true, search, until_cursor_len - input_len, cursor_col, M.RefType.Wiki
  end
  if vim.startswith(input, "[") then
    return true, search, until_cursor_len - input_len, cursor_col, M.RefType.Markdown
  end

  return false
end

M.get_trigger_characters = function()
  return { "[" }
end

M.get_keyword_pattern = function()
  -- Note that this is a vim pattern, not a Lua pattern. See ':help pattern'.
  -- The enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  return [=[\%(^\|[^\[]\)\zs\[\{1,2}[^\]]\+\]\{,2}]=]
end

return M
