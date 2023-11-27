local core = require("nougat.core")
local u_hl = require("nougat.util.hl")

local get_hl_def, get_hl_name = u_hl.get_hl_def, u_hl.get_hl_name

local mod = {}

mod.code = {
  buf_file_path = "f",
  buf_file_path_full = "F",
  buf_file_name = "t",
  buf_modified_flag = "m",
  buf_modified_flag_alt = "M",
  buf_readonly_flag = "r",
  buf_readonly_flag_alt = "R",
  buf_type_help_flag = "h",
  buf_type_help_flag_alt = "H",
  win_type_preview_flag = "w",
  win_type_preview_flag_alt = "W",
  buf_filetype_flag = "y",
  buf_filetype_flag_alt = "Y",
  buf_type_quickfix = "q",
  buf_keymap_name = "k",
  buf_number = "n",
  buf_cursor_char = "b",
  buf_cursor_char_hex = "B",
  buf_cursor_byte = "o",
  buf_cursor_byte_hex = "O",
  printer_page_number = "N",
  buf_line_current = "l",
  buf_line_total = "L",
  buf_col_current_byte = "c",
  buf_col_current = "v",
  buf_col_current_alt = "V",
  buf_line_percentage = "p",
  buf_line_percentage_alt = "P",
  argument_list_status = "a",
}

---@return (fun():integer) get_next_id
function mod.create_id_generator()
  local id = 0
  return function()
    id = id + 1
    return id
  end
end

local function get_next_list_item(items)
  local idx = (items._idx or 0) + 1
  local item = idx <= (items.len or idx) and items[idx] or nil
  items._idx = item and idx or 0
  return item, idx
end

local function get_next_priority_list_item(items)
  local item = items._node
  if item then
    items._node = item._next
    return item, item._idx
  end
  items._node = items._next
  return nil, nil
end

mod.on_event = require("nougat.util.on_event")

-- re-used table
---@type nougat_hl_def
local o_sep_hl = {}

---@param hl nougat_hl_def|nougat_separator_hl_def
---@param far_hl? nougat_hl_def
---@param near_hl? nougat_hl_def
---@param curr_hl? nougat_hl_def
---@param next_hl? nougat_hl_def
---@return nougat_hl_def sep_hl
local function prepare_sep_left_hl(hl, far_hl, near_hl, curr_hl, next_hl)
  o_sep_hl.bg = hl.bg or curr_hl and curr_hl.bg or "bg"
  o_sep_hl.fg = hl.fg or curr_hl and curr_hl.bg or next_hl and next_hl.bg or "bg"

  if o_sep_hl.bg == -1 then
    o_sep_hl.bg = near_hl and near_hl.bg or far_hl and far_hl.bg or nil
  elseif o_sep_hl.fg == -1 then
    o_sep_hl.fg = near_hl and near_hl.bg or far_hl and far_hl.bg or nil
  end

  return o_sep_hl
end

---@param hl nougat_hl_def|nougat_separator_hl_def
---@param prev_hl? nougat_hl_def
---@param curr_hl? nougat_hl_def
---@param near_hl? nougat_hl_def
---@param far_hl? nougat_hl_def
---@return nougat_hl_def sep_hl
local function prepare_sep_right_hl(hl, prev_hl, curr_hl, near_hl, far_hl)
  o_sep_hl.bg = hl.bg or curr_hl and curr_hl.bg or "bg"
  o_sep_hl.fg = hl.fg or prev_hl and prev_hl.bg or curr_hl and curr_hl.bg or "bg"

  if o_sep_hl.bg == 1 then
    o_sep_hl.bg = near_hl and near_hl.bg or far_hl and far_hl.bg or nil
  elseif o_sep_hl.fg == 1 then
    o_sep_hl.fg = near_hl and near_hl.bg or far_hl and far_hl.bg or nil
  end

  return o_sep_hl
end

---@class nougat_lazy_item_hl
---@field c? false|nougat_hl_def content (`false` means `content` w/o hl)
---@field c_idx? integer content index
---@field sl? false|nougat_separator_hl_def sep left (`false` means `sep_left` w/o hl)
---@field sl_idx? integer sep left index
---@field sr? false|nougat_separator_hl_def sep right (`false` means `sep_right` w/o hl)
---@field sr_idx? integer sep right index
---@field fc_idx? integer first child index
---@field lc_idx? integer last child index
---@field fb? nougat_hl_def fallback
---@field x? boolean skip highlight

---@param hls nougat_lazy_item_hl[]
---@param hl_idx integer
---@return nougat_lazy_item_hl
local function get_item_hl_table(hls, hl_idx)
  ---@type nougat_lazy_item_hl
  local item_hl = hls[hl_idx]
  if not item_hl then
    item_hl = { fb = {} }
    hls[hl_idx] = item_hl
  end

  item_hl.c = nil
  item_hl.c_idx = nil
  item_hl.sl = nil
  item_hl.sl_idx = nil
  item_hl.sr = nil
  item_hl.sr_idx = nil
  item_hl.fc_idx = nil
  item_hl.lc_idx = nil
  -- item_hl.fb.bg, item_hl.fb.fg = nil, nil
  item_hl.x = nil

  return item_hl
end

---@param hl? nougat_item_hl
---@param item NougatItem
---@param ctx nougat_bar_ctx
local function resolve_highlight(hl, item, ctx)
  local highlight = hl

  if type(highlight) == "function" then
    highlight = highlight(item, ctx)
  end

  if not highlight or type(highlight) == "table" then
    return highlight or false
  end

  if type(highlight) == "string" then
    return get_hl_def(highlight)
  end

  if type(highlight) == "number" then
    return get_hl_def("User" .. highlight)
  end

  return false
end

---@param affix nougat_item_affix
---@param item NougatItem
---@param ctx nougat_bar_ctx
---@param breakpoint integer
local function resolve_affix(affix, item, ctx, breakpoint)
  if type(affix) == "function" then
    return affix(item, ctx) or ""
  end

  return affix[breakpoint]
end

---@param items NougatItem[]|{ len?: integer }
---@param ctx nougat_bar_ctx
function mod.prepare_parts(items, ctx)
  local breakpoint = ctx.ctx.breakpoint

  local hls, parts = ctx.hls, ctx.parts
  local hl_idx, part_idx

  local ctx_hl = ctx.hl
  local reset_hl_bg, reset_hl_fg, reset_hl_name = ctx_hl.bg, ctx_hl.fg, get_hl_name(ctx_hl, ctx_hl)

  local item = items:next()
  while item do
    hl_idx, part_idx = hls.len, parts.len

    if item.prepare then
      item:prepare(ctx)
    end

    local hidden = item.hidden and (item.hidden == true or item:hidden(ctx))

    if not hidden then
      hl_idx = hl_idx + 1

      local item_hl = get_item_hl_table(hls, hl_idx)
      item_hl.fb.bg, item_hl.fb.fg = reset_hl_bg, reset_hl_fg

      if item.sep_left then
        local sep = item.sep_left[breakpoint]

        if sep.content then
          item_hl.sl = resolve_highlight(sep.hl, item, ctx)

          if item_hl.sl then
            item_hl.sl_idx = part_idx
            part_idx = part_idx + 3
          elseif item.hl then
            item_hl.c = resolve_highlight(item.hl, item, ctx)

            if item_hl.c then
              item_hl.c_idx = part_idx
              part_idx = part_idx + 3
            end
          end

          part_idx = part_idx + 1
          parts[part_idx] = sep.content
        end
      end

      -- content hl is not added yet
      if not item_hl.c_idx then
        -- content hl is not resolved yet
        if item_hl.c ~= false then
          item_hl.c = resolve_highlight(item.hl, item, ctx)
        end

        if item_hl.c then
          item_hl.c_idx = part_idx
          part_idx = part_idx + 3
        elseif item_hl.sl_idx then -- sep_left hl was added
          -- separator's highlight should not bleed into content
          part_idx = core.add_highlight(reset_hl_name, nil, parts, part_idx)
        end
      end

      if item_hl.c then
        ctx_hl.bg, ctx_hl.fg = item_hl.c.bg or ctx_hl.bg, item_hl.c.fg or ctx_hl.fg
      else
        ctx_hl.bg, ctx_hl.fg = reset_hl_bg, reset_hl_fg
      end

      if item.content then
        if item.prefix then
          part_idx = part_idx + 1
          parts[part_idx] = resolve_affix(item.prefix, item, ctx, breakpoint)
        end

        local content = item.content
        local content_type = type(content)
        if content_type == "function" then
          hls.len = hl_idx
          parts.len = part_idx

          content = item:content(ctx) or ""
          content_type = type(content)

          hl_idx = hls.len
        end

        if (content_type == "table" and content.len or #content) > 0 then
          if content_type == "table" then
            if type(content[1]) == "string" then
              ---@cast content string[]
              for idx = 1, (content.len or #content) do
                part_idx = part_idx + 1
                parts[part_idx] = content[idx]
              end
            else
              hls.len = hl_idx
              parts.len = part_idx

              if not content.next then
                content.next = get_next_list_item
              end

              ---@cast content NougatItem[]
              mod.prepare_parts(content, ctx)

              if hl_idx ~= hls.len then
                local total_child_hls = hls.len - hl_idx
                hl_idx = hls.len
                item_hl.fc_idx = total_child_hls == 1 and hl_idx or hl_idx - total_child_hls + 1
                item_hl.lc_idx = hl_idx
              end
              part_idx = parts.len
            end
          else
            part_idx = part_idx + 1
            parts[part_idx] = content
          end

          if item.suffix then
            part_idx = part_idx + 1
            parts[part_idx] = resolve_affix(item.suffix, item, ctx, breakpoint)
          end
        else -- no content returned
          if part_idx == parts.len then -- no parts added
            if item.prefix then
              -- discard prefix
              part_idx = part_idx - 1
              parts.len = part_idx
            end
          else
            part_idx = parts.len
          end
        end
      end

      if item.sep_right then
        local sep = item.sep_right[breakpoint]

        if sep.content then
          item_hl.sr = resolve_highlight(sep.hl, item, ctx)

          if item_hl.sr then
            item_hl.sr_idx = part_idx
            part_idx = part_idx + 3
          end

          part_idx = part_idx + 1
          parts[part_idx] = sep.content
        end
      end

      if item_hl.c or item_hl.sl or item_hl.sr then
        part_idx = core.add_highlight(reset_hl_name, nil, parts, part_idx)
      end

      if item.hl == false then
        hl_idx = hl_idx - 1
      end
    end

    hls.len = hl_idx
    parts.len = part_idx

    item = items:next()
  end
end

function mod.link_priority_item(node, item, idx)
  item.priority = item.priority == false and -math.huge or item.priority or 0
  while node do
    local next_item = node._next
    if not next_item or next_item.priority < item.priority then
      item._idx = idx
      item._next = next_item
      node._next = item
      return
    end
    node = next_item
  end
end

function mod.initialize_priority_item_list(items, get_next)
  if not items.next then
    items.next = get_next or get_next_priority_list_item
  end

  for idx = 1, (items.len or #items) do
    local item = items[idx]
    mod.link_priority_item(items, item, idx)

    if type(item.content) == "table" then
      mod.initialize_priority_item_list(item.content, items.next)
    end
  end

  items._node = items._next

  return items
end

---@param slots table<integer, (string|table)[]|{ hl: nougat_lazy_item_hl, len: integer }|nil>
---@param idx integer
---@return (string|table)[]|{ hl: nougat_lazy_item_hl, len: integer }
local function get_item_parts_slot(slots, idx)
  local slot = slots[idx]
  if not slot then
    slot = { hl = { fb = {} } }
    slots[idx] = slot
  end

  local item_hl = slot.hl
  item_hl.c = nil
  item_hl.c_idx = nil
  item_hl.sl = nil
  item_hl.sl_idx = nil
  item_hl.sr = nil
  item_hl.sr_idx = nil
  item_hl.fc_idx = nil
  item_hl.lc_idx = nil
  -- item_hl.fb.bg, item_hl.fb.fg = nil, nil
  item_hl.x = nil

  return slot
end

local o_eval_stl_opts = {}

function mod.prepare_slots(items, ctx)
  local available_width = ctx.available_width

  local initial_available_width = available_width

  local ctx_hl = ctx.hl
  local reset_hl_bg, reset_hl_fg, reset_hl_name = ctx_hl.bg, ctx_hl.fg, get_hl_name(ctx_hl, ctx_hl)

  local breakpoint = ctx.ctx.breakpoint

  local slots = ctx.slots

  local item, item_idx = items:next()
  while item do
    local slot_initial_available_width = available_width

    local parts = get_item_parts_slot(slots, item_idx)
    local item_hl = parts.hl
    item_hl.fb.bg, item_hl.fb.fg = reset_hl_bg, reset_hl_fg

    local part_idx = 0

    local should_skip_slot

    if available_width >= 0 then
      if item.prepare then
        item:prepare(ctx)
      end

      local hidden = item.hidden and (item.hidden == true or item:hidden(ctx))

      if not hidden then
        if item.sep_left then
          local sep = item.sep_left[breakpoint]

          if sep.content then
            item_hl.sl = resolve_highlight(sep.hl, item, ctx)

            if item_hl.sl then
              item_hl.sl_idx = part_idx
              part_idx = part_idx + 3
            elseif item.hl then
              item_hl.c = resolve_highlight(item.hl, item, ctx)

              if item_hl.c then
                item_hl.c_idx = part_idx
                part_idx = part_idx + 3
              end
            end

            part_idx = part_idx + 1
            parts[part_idx] = sep.content

            available_width = available_width - vim.api.nvim_strwidth(sep.content)
          else
            part_idx = part_idx + 1
            parts[part_idx] = ""
          end
        end

        -- content hl is not added yet
        if not item_hl.c_idx then
          -- content hl is not resolved yet
          if item_hl.c ~= false then
            item_hl.c = resolve_highlight(item.hl, item, ctx)
          end

          if item_hl.c then
            item_hl.c_idx = part_idx
            part_idx = part_idx + 3
          elseif item_hl.sl_idx then -- sep_left hl was added
            -- separator's highlight should not bleed into content
            part_idx = core.add_highlight(reset_hl_name, nil, parts, part_idx)
          end
        end

        if item_hl.c then
          ctx_hl.bg, ctx_hl.fg = item_hl.c.bg or ctx_hl.bg, item_hl.c.fg or ctx_hl.fg
        else
          ctx_hl.bg, ctx_hl.fg = reset_hl_bg, reset_hl_fg
        end

        local nested_items_idx, nested_items

        if item.content then
          if item.prefix then
            part_idx = part_idx + 1
            parts[part_idx] = resolve_affix(item.prefix, item, ctx, breakpoint)

            available_width = available_width - vim.api.nvim_strwidth(parts[part_idx])
          end

          local content = item.content
          local content_type = type(content)
          if content_type == "function" then
            parts.len = part_idx

            ctx.parts = parts

            content = item:content(ctx) or ""
            content_type = type(content)
          end

          if (content_type == "table" and content.len or #content) > 0 then
            o_eval_stl_opts.winid = ctx.winid

            if content_type == "table" then
              if type(content[1]) == "string" then
                ---@cast content string[]
                for idx = 1, (content.len or #content) do
                  local c = vim.api.nvim_eval_statusline(content[idx], o_eval_stl_opts)

                  part_idx = part_idx + 1
                  parts[part_idx] = content[idx]

                  available_width = available_width - c.width
                end
              else
                if not content.next then
                  mod.initialize_priority_item_list(content)
                end

                part_idx = part_idx + 1

                nested_items_idx = part_idx
                nested_items = content
              end
            else
              if item.priority == -math.huge then
                part_idx = part_idx + 1
                parts[part_idx] = content
              else
                local c = vim.api.nvim_eval_statusline(content, o_eval_stl_opts)

                part_idx = part_idx + 1
                parts[part_idx] = content

                available_width = available_width - c.width
              end
            end

            if item.suffix then
              part_idx = part_idx + 1
              parts[part_idx] = resolve_affix(item.suffix, item, ctx, breakpoint)

              available_width = available_width - vim.api.nvim_strwidth(parts[part_idx])
            end
          else -- no content returned
            if part_idx == parts.len then -- no parts added
              if item.prefix then
                -- discard prefix
                part_idx = part_idx - 1
                parts.len = part_idx
              end
            else
              part_idx = parts.len
            end
          end
        end

        if item.sep_right then
          local sep = item.sep_right[breakpoint]

          if sep.content then
            item_hl.sr = resolve_highlight(sep.hl, item, ctx)

            if item_hl.sr then
              item_hl.sr_idx = part_idx
              part_idx = part_idx + 3
            end

            part_idx = part_idx + 1
            parts[part_idx] = sep.content

            available_width = available_width - vim.api.nvim_strwidth(sep.content)
          else
            part_idx = part_idx + 1
            parts[part_idx] = ""
          end
        end

        if nested_items_idx then
          local nested_slots = parts[nested_items_idx]
          if not nested_slots or nested_slots.id ~= item.id then
            nested_slots = { id = item.id }
            parts[nested_items_idx] = nested_slots
          end

          nested_slots.len = nested_items.len
          ctx.available_width = available_width
          ctx.slots = nested_slots

          ---@cast nested_items NougatItem[]
          mod.prepare_slots(nested_items, ctx)

          if ctx.available_width == available_width then
            should_skip_slot = true
          else
            available_width = ctx.available_width
          end

          ctx.slots = slots
          ctx.available_width = available_width
        end

        if item_hl.c or item_hl.sl or item_hl.sr then
          part_idx = core.add_highlight(reset_hl_name, nil, parts, part_idx)
        end

        if item.hl == false then
          item_hl.x = true
        end
      end
    end

    if should_skip_slot then
      part_idx = 0
      available_width = slot_initial_available_width
    elseif available_width < 0 then
      if items._overflow == "hide-all" then
        for i = 1, #slots do
          slots[i].len = 0
        end
        ctx.available_width = initial_available_width
        break
      else
        -- hide-self
        part_idx = 0
        available_width = slot_initial_available_width
      end
    end

    parts.len = part_idx
    ctx.available_width = available_width

    item, item_idx = items:next()
  end
end

local function prepare_parts_from_slots(slots, parts, parts_len, hls, hls_len, item_hl)
  for i = 1, slots.len do
    local slot = slots[i]

    if type(slot) == "table" then
      if slot.len > 0 then
        local c_len, hl = parts_len, slot.hl
        if hl and not hl.x then
          hls_len = hls_len + 1

          local item_hls_len = hls_len

          if hl.sl_idx then
            hl.sl_idx = hl.sl_idx + parts_len
          end

          if hl.c_idx then
            hl.c_idx = hl.c_idx + parts_len
          end

          if hl.sr_idx then
            hl.sr_idx = hl.sr_idx + parts_len
          end

          parts_len, hls_len = prepare_parts_from_slots(slot, parts, parts_len, hls, hls_len, hl)

          if item_hls_len ~= hls_len then
            local total_child_hls = hls_len - item_hls_len
            hl.fc_idx = total_child_hls == 1 and hls_len or hls_len - total_child_hls + 1
            hl.lc_idx = hls_len
          end

          hls[item_hls_len] = hl
        else
          parts_len, hls_len = prepare_parts_from_slots(slot, parts, parts_len, hls, hls_len)
        end

        c_len = parts_len - c_len

        if item_hl and item_hl.sr_idx then
          item_hl.sr_idx = item_hl.sr_idx + c_len - 1
        end
      end
    else
      parts_len = parts_len + 1
      parts[parts_len] = slot or ""
    end
  end

  return parts_len, hls_len
end

function mod.prepare_priority_parts(items, ctx)
  local parts = ctx.parts
  mod.prepare_slots(items, ctx)
  parts.len, ctx.hls.len = prepare_parts_from_slots(ctx.slots, parts, 0, ctx.hls, 0)
  ctx.parts = parts
end

---@param ctx nougat_bar_ctx
---@param fallback_hl nougat_hl_def
function mod.process_bar_highlights(ctx, fallback_hl)
  local hls = ctx.hls
  local hl_idx = hls.len

  local parts = ctx.parts

  for idx = 1, hl_idx do
    local hl = hls[idx]

    if hl.sl then
      -- for parent:
      -- - last child of prev sibling
      -- - or prev sibling
      -- for first child:
      -- - parent
      -- for children:
      -- - prev sibling
      local near_prev_hl = idx > 1 and hls[idx - 1] or nil
      -- for first child:
      -- - prev sibling of parent
      local far_prev_hl = ((near_prev_hl and idx == near_prev_hl.fc_idx) and idx > 2) and hls[idx - 2] or nil
      -- for parent
      -- - first child
      local near_next_hl = hl.fc_idx and hls[hl.fc_idx] or nil

      core.add_highlight(
        get_hl_name(
          prepare_sep_left_hl(
            hl.sl,
            far_prev_hl and (far_prev_hl.c or far_prev_hl.fb) or nil,
            near_prev_hl and (near_prev_hl.c or near_prev_hl.fb) or nil,
            hl.c,
            near_next_hl and (near_next_hl.c or near_next_hl.fb) or nil
          ),
          hl.fb or fallback_hl
        ),
        nil,
        parts,
        hl.sl_idx
      )
    end

    if hl.c then
      core.add_highlight(get_hl_name(hl.c, hl.fb or fallback_hl), nil, parts, hl.c_idx)
    end

    if hl.sr then
      -- for parent:
      -- - last child
      local prev_hl = hl.lc_idx and hls[hl.lc_idx] or nil
      -- for parent:
      -- - next sibling
      -- for children:
      -- - next sibling
      -- for last child:
      -- - next sibling of parent
      local near_next_hl = hl.lc_idx and (hl.lc_idx + 1 <= hl_idx and hls[hl.lc_idx + 1])
        or idx + 1 <= hl_idx and hls[idx + 1]
        or nil
      -- for parent:
      -- - first child of next sibling
      -- for last child:
      -- - first child of next sibling of parent
      local far_next_hl = (near_next_hl and near_next_hl.fc_idx) and hls[near_next_hl.fc_idx] or nil

      core.add_highlight(
        get_hl_name(
          prepare_sep_right_hl(
            hl.sr,
            prev_hl and (prev_hl.c or prev_hl.fb) or nil,
            hl.c,
            near_next_hl and (near_next_hl.c or near_next_hl.fb) or nil,
            far_next_hl and (far_next_hl.c or far_next_hl.fb) or nil
          ),
          hl.fb or fallback_hl
        ),
        nil,
        parts,
        hl.sr_idx
      )
    end
  end
end

mod.get_next_list_item = get_next_list_item

return mod
