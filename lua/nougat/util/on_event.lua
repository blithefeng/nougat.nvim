local augroup = vim.api.nvim_create_augroup("nougat.on_event", { clear = true })

---@type table<string, (fun(info:table):nil)[]>
local autocmd_cb_store = {}

local option_set = {
  cb_store = {},
  autocmd_id = nil,
}

function option_set.cb(info)
  for _, cb in ipairs(option_set.cb_store[info.match]) do
    cb(info)
  end
end

---@param event string|string[]
---@param callback (fun(info:table):nil)
local function on_event(event, callback)
  if type(event) == "string" then
    event = { event }
  end

  for _, ev in ipairs(event) do
    local event_name = ev
    local pattern

    if string.sub(ev, 1, 5) == "User " then
      event_name = "User"
      pattern = string.sub(ev, 6)
    elseif string.sub(ev, 1, 10) == "OptionSet " then
      event_name = "OptionSet"
      pattern = string.sub(ev, 11)
    end

    if event_name == "OptionSet" then
      local cb_store = option_set.cb_store
      if not cb_store[pattern] then
        cb_store[pattern] = {}
      end

      table.insert(cb_store[pattern], callback)

      local autocmd_id = vim.api.nvim_create_autocmd(event_name, {
        group = augroup,
        pattern = table.concat(vim.tbl_keys(cb_store), ","),
        callback = option_set.cb,
        desc = "[nougat] util.on_event - " .. event_name,
      })

      if option_set.autocmd_id then
        vim.api.nvim_del_autocmd(option_set.autocmd_id)
      end

      option_set.autocmd_id = autocmd_id
    else
      if not autocmd_cb_store[ev] then
        autocmd_cb_store[ev] = {}

        vim.api.nvim_create_autocmd(event_name, {
          group = augroup,
          pattern = pattern,
          callback = function(info)
            local cbs = info.event == "User" and autocmd_cb_store["User " .. info.match]
              or info.event == "OptionSet" and autocmd_cb_store["OptionSet " .. info.match]
              or autocmd_cb_store[info.event]

            for _, cb in ipairs(cbs) do
              cb(info)
            end
          end,
          desc = "[nougat] util.on_event - " .. ev,
        })
      end

      autocmd_cb_store[ev][#autocmd_cb_store[ev] + 1] = callback
    end
  end
end

return on_event
