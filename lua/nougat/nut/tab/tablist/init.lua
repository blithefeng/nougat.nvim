local buf_cache = require("nougat.cache.buffer")
local Item = require("nougat.item")
local get_hl_def = require("nougat.util.hl").get_hl_def

buf_cache.enable("filename")

local function get_content(item, ctx)
  local active_tabid = ctx.tabid
  local tabids = vim.api.nvim_list_tabpages()

  local items = item.tabs.items
  local item_idx = 0

  for tidx = 1, #tabids do
    local tabid = tabids[tidx]

    local tab = tabid == active_tabid and item.active_tab or item.inactive_tab

    item_idx = item_idx + 1
    items[item_idx] = tab
  end

  item.tabs.ctx = ctx
  item.tabs.len = item_idx
  item.tabs.tabids = tabids

  return item.tabs
end

local function get_next_tab_item(tabs)
  local ctx, tab_ctx = tabs.ctx, tabs.tab_ctx

  local idx = tabs._idx + 1

  local tabid = tabs.tabids[idx]

  if not tabid then
    tabs._idx = 0
    ctx.tab = nil
    return nil, nil
  end

  tabs._idx = idx

  tab_ctx.tabid, tab_ctx.tabnr = tabid, vim.api.nvim_tabpage_get_number(tabid)
  tab_ctx.winid = vim.api.nvim_tabpage_get_win(tabid)
  tab_ctx.bufnr = vim.api.nvim_win_get_buf(tab_ctx.winid)
  tab_ctx.is_focused = ctx.tabid == tabid
  tab_ctx.filename = buf_cache.get("filename", tab_ctx.bufnr)

  ctx.tab = tab_ctx

  return tabs.items[idx], idx
end

local default_tab_hl = {
  active = get_hl_def("TabLineSel"),
  inactive = get_hl_def("TabLine"),
}

local function get_default_tab()
  return Item({
    sep_left = { content = "▎" },
    content = {
      require("nougat.nut.tab.tablist.label").create({}),
      require("nougat.nut.tab.tablist.close").create({
        prefix = " ",
        suffix = " ",
      }),
    },
  })
end

local mod = {}

function mod.create(opts)
  local active_tab = opts.active_tab or get_default_tab()
  if not active_tab.hl then
    active_tab.hl = default_tab_hl.active
  end

  local inactive_tab = opts.inactive_tab or get_default_tab()
  if not inactive_tab.hl then
    inactive_tab.hl = default_tab_hl.inactive
  end

  local item = Item({
    priority = opts.priority,
    hidden = opts.hidden,
    sep_left = opts.sep_left,
    prefix = opts.prefix,
    content = get_content,
    suffix = opts.suffix,
    sep_right = opts.sep_right,
  })

  item.active_tab = active_tab.id and active_tab or Item(active_tab)
  item.inactive_tab = inactive_tab.id and inactive_tab or Item(inactive_tab)

  item.tabs = {
    ctx = nil,
    tab_ctx = {},

    _idx = 0,
    len = 0,
    items = {},
    tabids = {},

    next = get_next_tab_item,
  }

  return item
end

return mod
