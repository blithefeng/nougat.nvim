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

function mod.get_next_list_item(items)
  local idx = (items._idx or 0) + 1
  local item = idx <= (items.len or idx) and items[idx] or nil
  items._idx = item and idx or 0
  return item, idx
end

mod.on_event = require("nougat.util.on_event")

return mod
