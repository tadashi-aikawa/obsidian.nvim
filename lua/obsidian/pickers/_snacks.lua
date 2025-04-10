--[[
  This file is based on code from obsidian-nvim/obsidian.nvim
  Original PR: https://github.com/obsidian-nvim/obsidian.nvim/pull/4
  License: MIT (https://github.com/obsidian-nvim/obsidian.nvim/blob/main/LICENSE)
  Retrieved on: [2025-04-06]
--]]
local snacks_picker = require "snacks.picker"

local Path = require "obsidian.path"
local abc = require "obsidian.abc"
local Picker = require "obsidian.pickers.picker"

---@param mapping table
---@return table
local function selection_mappings(mapping)
  if type(mapping) == "table" then
    local opts = { win = { input = { keys = {} } }, actions = {} }
    for k, v in pairs(mapping) do
      local name = string.gsub(v.desc, " ", "_")
      opts.win.input.keys = {
        [k] = { name, mode = { "n", "i" }, desc = v.desc },
      }
      opts.actions[name] = function(picker, item)
        picker:close()
        vim.schedule(function()
          v.callback(item.value or item._path)
        end)
      end
    end
    return opts
  end
  return {}
end

---@param mapping table
---@return table
local function query_mappings(mapping)
  if type(mapping) == "table" then
    local opts = { win = { input = { keys = {} } }, actions = {} }
    for k, v in pairs(mapping) do
      local name = string.gsub(v.desc, " ", "_")
      opts.win.input.keys[k] = { name, mode = { "n", "i" }, desc = v.desc }
      opts.actions[name] = function(picker)
        local query = picker.input.filter.pattern
        if query and #query > 0 then
          picker:close()
          vim.schedule(function()
            v.callback(query)
          end)
        elseif v.fallback_to_query then
          -- Handle fallback case if needed
        end
      end
    end
    return opts
  end
  return {}
end

---@class obsidian.pickers.SnacksPicker : obsidian.Picker
local SnacksPicker = abc.new_class({
  ---@diagnostic disable-next-line: unused-local
  __tostring = function(self)
    return "SnacksPicker()"
  end,
}, Picker)

---@param opts obsidian.PickerFindOpts|? Options.
SnacksPicker.find_files = function(self, opts)
  opts = opts or {}

  ---@type obsidian.Path
  local dir = opts.dir.filename and Path:new(opts.dir.filename) or self.client.dir

  local selection_map = selection_mappings(opts.selection_mappings) or {}
  local query_map = query_mappings(opts.query_mappings) or {}
  local map = vim.tbl_deep_extend("force", {}, selection_map, query_map)

  local pick_opts = vim.tbl_extend("force", map or {}, {
    source = "files",
    title = opts.prompt_title,
    cwd = tostring(dir),
    confirm = function(picker, item, action)
      picker:close()
      if item then
        if opts.callback then
          opts.callback(item._path)
        else
          snacks_picker.actions.jump(picker, item, action)
        end
      end
    end,
  })
  snacks_picker.pick(pick_opts)
end

---@param opts obsidian.PickerGrepOpts|? Options.
SnacksPicker.grep = function(self, opts)
  opts = opts or {}

  ---@type obsidian.Path
  local dir = opts.dir.filename and Path:new(opts.dir.filename) or self.client.dir

  local map = vim.tbl_deep_extend("force", {}, selection_mappings(opts.selection_mappings))

  local pick_opts = vim.tbl_extend("force", map or {}, {
    source = "grep",
    title = opts.prompt_title,
    cwd = tostring(dir),
    confirm = function(picker, item, action)
      picker:close()
      if item then
        if opts.callback then
          opts.callback(item._path or item.filename)
        else
          snacks_picker.actions.jump(picker, item, action)
        end
      end
    end,
  })
  snacks_picker.pick(pick_opts)
end

---@param values string[]|obsidian.PickerEntry[]
---@param opts obsidian.PickerPickOpts|? Options.
---@diagnostic disable-next-line: unused-local
SnacksPicker.pick = function(self, values, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  local entries = {}
  for _, value in ipairs(values) do
    if type(value) == "string" then
      table.insert(entries, {
        text = value,
        value = value,
      })
    elseif value.valid ~= false then
      local name = self:_make_display(value)
      table.insert(entries, {
        text = name,
        file = value.filename,
        pos = { value.lnum, value.col or 0 },
      })
    end
  end

  local map = vim.tbl_deep_extend("force", {}, selection_mappings(opts.selection_mappings))

  local pick_opts = vim.tbl_extend("force", map or {}, {
    title = opts.prompt_title,
    items = entries,
    layout = {
      preview = true,
    },
    format = "text",
    confirm = function(picker, item, action)
      picker:close()
      if item then
        if opts.callback then
          opts.callback(item.value)
        else
          snacks_picker.actions.jump(picker, item, action)
        end
      end
    end,
  })

  snacks_picker.pick(pick_opts)
end

return SnacksPicker
