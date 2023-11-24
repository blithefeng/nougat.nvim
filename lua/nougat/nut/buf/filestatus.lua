local Item = require("nougat.item")

local buf_cache = require("nougat.cache.buffer")

buf_cache.enable("modified")
buf_cache.enable("modifiable")
buf_cache.enable("readonly")

-- re-used table
local o_parts = { len = 0 }

local function get_content(item, ctx)
  local bufnr = ctx.bufnr
  local config = item:config(ctx)

  local part_idx = 0

  if config.readonly and buf_cache.get("readonly", bufnr) then
    part_idx = part_idx + 1
    o_parts[part_idx] = config.readonly
    part_idx = part_idx + 1
    o_parts[part_idx] = config.sep
  end
  if config.modified and buf_cache.get("modified", bufnr) then
    part_idx = part_idx + 1
    o_parts[part_idx] = config.modified
    part_idx = part_idx + 1
    o_parts[part_idx] = config.sep
  end
  if config.nomodifiable and not buf_cache.get("modifiable", bufnr) then
    part_idx = part_idx + 1
    o_parts[part_idx] = config.nomodifiable
    part_idx = part_idx + 1
    o_parts[part_idx] = config.sep
  end

  o_parts.len = part_idx > 0 and part_idx - 1 or part_idx

  return o_parts
end

local mod = {}

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
      modified = "+",
      nomodifiable = "-",
      readonly = "RO",
      sep = ",",
    }, opts.config or {}),
    on_click = opts.on_click,
    context = opts.context,
  })

  return item
end

return mod
