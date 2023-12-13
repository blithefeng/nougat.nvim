local Item = require("nougat.item")
local color = require("nougat.color").get()
local on_event = require("nougat.util").on_event

--luacheck: push no max line length

---@class nougat.nut.mode_config.config
---@field text? table<string, string>
---@field highlight? table<'normal'|'visual'|'insert'|'replace'|'commandline'|'terminal'|'inactive', nougat_hl_def>

---@class nougat_nut_mode_config: nougat_item_config__function
---@field cache? nil
---@field config? nougat.nut.mode_config.config|nougat.nut.mode_config.config[]
---@field content? nil
---@field hl? nil
---@field prepare? nil

--luacheck: pop

local mode_group = {
  ["n"] = "normal",
  ["no"] = "normal",
  ["nov"] = "normal",
  ["noV"] = "normal",
  ["no"] = "normal",
  ["niI"] = "normal",
  ["niR"] = "normal",
  ["niV"] = "normal",
  ["nt"] = "normal",
  ["ntT"] = "normal",

  ["v"] = "visual",
  ["vs"] = "visual",
  ["V"] = "visual",
  ["Vs"] = "visual",
  [""] = "visual",
  ["s"] = "visual",

  ["s"] = "visual",
  ["S"] = "visual",
  [""] = "visual",

  ["i"] = "insert",
  ["ic"] = "insert",
  ["ix"] = "insert",

  ["R"] = "replace",
  ["Rc"] = "replace",
  ["Rx"] = "replace",
  ["Rv"] = "replace",
  ["Rvc"] = "replace",
  ["Rvx"] = "replace",

  ["c"] = "commandline",
  ["cv"] = "commandline",
  ["ce"] = "commandline",
  ["r"] = "commandline",
  ["rm"] = "commandline",
  ["r?"] = "commandline",
  ["!"] = "commandline",

  ["t"] = "terminal",

  ["-"] = "inactive",
}

local default_text = {
  ["n"] = "NORMAL",
  ["no"] = "OP PENDING",
  ["nov"] = "OP PENDING CHAR",
  ["noV"] = "OP PENDING LINE",
  ["no"] = "OP PENDING BLOCK",
  ["niI"] = "INSERT (NORMAL)",
  ["niR"] = "REPLACE (NORMAL)",
  ["niV"] = "V REPLACE (NORMAL)",
  ["nt"] = "TERMINAL NORMAL",
  ["ntT"] = "TERMINAL (NORMAL)",

  ["v"] = "VISUAL",
  ["vs"] = "SELECT (VISUAL)",
  ["V"] = "V-LINE",
  ["Vs"] = "SELECT (V-LINE)",
  [""] = "V-BLOCK",
  ["s"] = "SELECT (V-BLOCK)",

  ["s"] = "SELECT",
  ["S"] = "S-LINE",
  [""] = "S-BLOCK",

  ["i"] = "INSERT",
  ["ic"] = "INSERT COMPL GENERIC",
  ["ix"] = "INSERT COMPL",

  ["R"] = "REPLACE",
  ["Rc"] = "REPLACE COMP GENERIC",
  ["Rx"] = "REPLACE COMP",
  ["Rv"] = "V REPLACE",
  ["Rvc"] = "V REPLACE COMP GENERIC",
  ["Rvx"] = "V REPLACE COMP",

  ["c"] = "COMMAND",
  ["cv"] = "VIM EX",
  ["ce"] = "EX",
  ["r"] = "PROMPT",
  ["rm"] = "MORE PROMPT",
  ["r?"] = "CONFIRM",
  ["!"] = "SHELL",

  ["t"] = "TERMINAL",

  ["-"] = "INACTIVE",
}

local default_highlight = {
  normal = {
    bg = "fg",
    fg = "bg",
  },
  visual = {
    bg = color.yellow,
    fg = "bg",
  },
  insert = {
    bg = color.blue,
    fg = "bg",
  },
  replace = {
    bg = color.magenta,
    fg = "bg",
  },
  commandline = {
    bg = color.green,
    fg = "bg",
  },
  terminal = {
    bg = color.cyan,
    fg = "bg",
  },
  inactive = {
    bg = "fg",
    fg = "bg",
  },
}

local cache = {
  mode = "n",
  group = mode_group["n"],
}

local function on_mode_changed()
  local event = vim.v.event
  local old_mode, new_mode = event.old_mode, event.new_mode
  cache.mode, cache.group = new_mode, mode_group[new_mode]
  if old_mode == "t" then
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end
end

---@param item NougatItem
---@param ctx nougat_bar_ctx
local function content(item, ctx)
  local mode = ctx.is_focused and cache.mode or "-"
  return item:config(ctx).text[mode] or mode
end

---@param item NougatItem
---@param ctx nougat_bar_ctx
local function hl(item, ctx)
  return item:config(ctx).highlight[ctx.is_focused and cache.group or "inactive"]
end

local mod = {}

---@param config? nougat_nut_mode_config
function mod.create(config)
  on_event("ModeChanged", on_mode_changed)

  config = config or {}

  local item = Item({
    priority = config.priority,
    hidden = config.hidden,
    hl = hl,
    sep_left = config.sep_left,
    prefix = config.prefix,
    content = content,
    suffix = config.suffix,
    sep_right = config.sep_right,
    config = vim.tbl_deep_extend("keep", config.config or {}, {
      text = default_text,
      highlight = default_highlight,
    }),
    on_click = config.on_click,
    context = config.context,
  })

  return item
end

return mod
