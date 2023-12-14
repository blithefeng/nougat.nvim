local s = require("nougat.store")
local on_event = require("nougat.util.on_event")

local cache_getter = {
  buf = function(item, ctx)
    return item._cache_store[ctx.bufnr][ctx.breakpoint]
  end,
  win = function(item, ctx)
    return item._cache_store[ctx.winid][ctx.breakpoint]
  end,
  tab = function(item, ctx)
    return item._cache_store[ctx.tabid][ctx.breakpoint]
  end,
  _wrap_fn = function(item, ctx)
    return item._cache_get(item._cache_store, ctx)
  end,
}

local create_store = {
  buf = s.BufStore,
  win = s.WinStore,
  tab = s.TabStore,
}

local mod = {
  cache_getter = cache_getter,
  create_store = create_store,
}

function mod.cached_fn_content_processor(item, ctx)
  local c = item:cache(ctx)
  if not c._v then
    c._v = item:_cached_fn_content(ctx)
  end
  return c._v
end

---@type table<string, fun(info: table): integer>
local id_getter_by_key = {
  buf = function(info)
    return info.buf
  end,
}

local buf_id_getter_by_event = {
  lspattach = id_getter_by_key.buf,
  lspdetach = id_getter_by_key.buf,
}

---@param event string
---@param scope string
local function get_store_clear_id_getter(event, scope)
  if scope ~= "buf" then
    error("default clear get_id not available for cache.scope=" .. scope)
  end
  if string.sub(event, 1, 3):lower() == "buf" then
    return id_getter_by_key.buf
  end
  local get_id = buf_id_getter_by_event[event:lower()]
  if get_id then
    return get_id
  end
  error("default clear get_id not available for event: " .. event)
end

---@param clear nougat_item_config.cache.clear
---@param store NougatBufStore|NougatWinStore|NougatTabStore
---@param scope? 'buf'|'win'|'tab'
local function process_item_cache_clear(clear, store, scope)
  if type(clear) == "string" then
    -- "A"
    return process_item_cache_clear({ clear }, store, scope)
  end

  if type(clear) ~= "table" then
    error("unexpected item.cache.clear type: " .. type(clear))
  end

  if not clear[2] or type(clear[2]) == "string" then
    -- {"A", "B"}
    ---@cast clear string[]

    ---@type table<nougat_item_config.cache.clear__get_id, string[]>
    local event_by_get_id = {}
    for i = 1, #clear do
      local event = clear[i]
      local get_id = get_store_clear_id_getter(event, scope or store.type)
      if event_by_get_id[get_id] then
        table.insert(event_by_get_id[get_id], event)
      else
        event_by_get_id[get_id] = { event }
      end
      for get_id_fn, events in pairs(event_by_get_id) do
        on_event(events, function(info)
          store:clear(get_id_fn(info))
        end)
      end
    end
  elseif type(clear[2]) == "function" then
    -- {"C", get_id}
    -- {{"D", "E"}, get_id}

    local get_id = clear[2] --[[@as nougat_item_config.cache.clear__get_id]]
    on_event(clear[1], function(info)
      store:clear(get_id(info))
    end)
  elseif type(clear[2]) == "table" then
    -- {{"A", "B"}, {"C", get_id}, {{"D", "E"}, get_id}}
    ---@cast clear table[]

    for i = 1, #clear do
      process_item_cache_clear(clear[i], store, scope)
    end
  end
end

mod.process_item_cache_clear = process_item_cache_clear

return mod
