local buf_cache = require("nougat.cache.buffer")
local Item = require("nougat.item")

local function get_wordcount(format)
  local wordcount = vim.fn.wordcount()
  local count = wordcount.visual_words or wordcount.words
  return format(count)
end

local in_visual_mode = {
  ["v"] = true,
  ["vs"] = true,
  ["V"] = true,
  ["Vs"] = true,
  [""] = true,
  ["s"] = true,
}

local function get_content(item, ctx)
  local config = item:config(ctx)

  if in_visual_mode[vim.fn.mode()] then
    return get_wordcount(config.format)
  end

  local cache = item:cache(ctx)

  local changedtick = vim.api.nvim_buf_get_changedtick(ctx.bufnr)
  if cache.ct ~= changedtick then
    cache.ct = changedtick
    cache.v = get_wordcount(config.format)
  end

  return cache.v
end

local hidden = {}

---@param filetype_map table<string, true>
---@return nougat_item_hidden
function hidden.if_not_filetype(filetype_map)
  buf_cache.enable("filetype")
  return function(_, ctx)
    return not filetype_map[buf_cache.get("filetype", ctx.bufnr)]
  end
end

local mod = {
  hidden = hidden,
}

function mod.create(opts)
  local item = Item({
    priority = opts.priority,
    hidden = opts.hidden,
    hl = opts.hl,
    sep_left = opts.sep_left,
    prefix = opts.prefix,
    content = get_content,
    suffix = opts.suffix,
    sep_right = opts.sep_right,
    config = vim.tbl_extend("force", {
      format = tostring,
    }, opts.config or {}),
    on_click = opts.on_click,
    context = opts.context,
    cache = {
      scope = "buf",
      initial_value = {
        -- buffer changedtick
        ct = -1,
        --- value
        v = "",
      },
    },
  })

  return item
end

return mod
