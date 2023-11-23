local core = require("nougat.core")
local iu = require("nougat.item.util")
local ic = require("nougat.item.cache")
local create_store = require("nougat.cache").create_store
local u = require("nougat.util")

local next_id = u.create_id_generator()

--luacheck: push no max line length

---@alias nougat_item_content string|string[]|NougatItem[]|(fun(self: NougatItem, ctx: nougat_bar_ctx):nil|string|string[]|NougatItem[])
---@alias nougat_item_hl integer|string|nougat_hl_def|(fun(self: NougatItem, ctx: nougat_bar_ctx): integer|string|nougat_hl_def)
---@alias nougat_item_affix string[]|(fun(item: NougatItem, ctx: nougat_bar_ctx):string)
---@alias nougat_item_hidden boolean|(fun(self: NougatItem, ctx: nougat_bar_ctx):boolean)

---@alias nougat_item_config.cache.clear__event string|string[]
---@alias nougat_item_config.cache.clear__get_id (fun(info: table): integer)
---@alias nougat_item_config.cache.clear nougat_item_config.cache.clear__event | { [1]: nougat_item_config.cache.clear__event, [2]?: nougat_item_config.cache.clear__get_id } | { [1]: nougat_item_config.cache.clear__event, [2]?: nougat_item_config.cache.clear__get_id }[]

---@class nougat_item_config.cache
---@field get? fun(store: NougatCacheStore, ctx: nougat_bar_ctx):table
---@field scope? 'buf'|'win'|'tab'
---@field initial_value? table
---@field store? NougatCacheStore
---@field clear? nougat_item_config.cache.clear

---@class nougat_item_config__nil
---@field init? fun(self: NougatItem): nil
---@field prepare? fun(self: NougatItem, ctx: nougat_bar_ctx):nil
---@field hidden? nougat_item_hidden
---@field hl? nougat_item_hl
---@field content? string|string[]|NougatItem[]
---@field sep_left? nougat_separator|nougat_separator[]
---@field sep_right? nougat_separator|nougat_separator[]
---@field prefix? string|nougat_item_affix
---@field suffix? string|nougat_item_affix
---@field context? nougat_core_item_options_context
---@field on_click? string|nougat_core_click_handler
---@field priority? integer
---@field ctx? table

---@class nougat_item_config__core: nougat_item_config__nil
---@field align? 'left'|'right'
---@field leading_zero? boolean
---@field max_width? integer
---@field min_width? integer

---@class nougat_item_config__code: nougat_item_config__core
---@field type 'code'
---@field content string

---@class nougat_item_config__vim_expr: nougat_item_config__core
---@field type 'vim_expr'
---@field content string
---@field expand? boolean

---@class nougat_item_config__lua_expr: nougat_item_config__core
---@field type 'lua_expr'
---@field content number|string|nougat_core_expression_fn
---@field expand? boolean

---@class nougat_item_config__literal: nougat_item_config__core
---@field type 'literal'
---@field content boolean|number|string

---@class nougat_item_config__tab_label: nougat_item_config__nil
---@field type 'tab_label'
---@field content number|string
---@field close? boolean
---@field tabnr? integer

---@class nougat_item_config__function: nougat_item_config__nil
---@field content fun(self: NougatItem, ctx: nougat_bar_ctx):nil|string|string[]|NougatItem[]
---@field config? table|table[]
---@field cache? nougat_item_config.cache

---@alias nougat_item_config nougat_item_config__nil|nougat_item_config__code|nougat_item_config__vim_expr|nougat_item_config__lua_expr|nougat_item_config__literal|nougat_item_config__tab_label|nougat_item_config__function

--luacheck: pop

local invalidate_cache = ic.invalidate_cache

---@param item NougatItem
---@param ctx nougat_bar_ctx
local function content_function_processor(item, ctx)
  local parts = ctx.parts
  local part_idx = parts.len

  part_idx = core.add_clickable("", {
    id = item._on_click_id,
    context = item._on_click_context or item,
    on_click = item._on_click,
  }, parts, part_idx)

  local end_delim = parts[part_idx]

  parts.len = part_idx - 2

  local content = item._content(item, ctx) or ""

  if #content > 0 then
    parts[part_idx - 1] = content
  else -- no content returned
    if part_idx == parts.len then -- no parts added
      -- discard clickable parts
      part_idx = part_idx - 7
    else
      part_idx = parts.len
      parts[part_idx + 1] = end_delim
    end
  end

  parts.len = part_idx
end

local item_hidden_processor = {
  boolean = function(item)
    return item._item_hidden.hidden
  end,
  ["function"] = function(item, ctx)
    return item._item_hidden:hidden(ctx)
  end,
}

local function hl_item_processor(item, ctx)
  return type(item._hl_item.hl) == "function" and item._hl_item:hl(ctx) or item._hl_item.hl
end

---@param clear nougat_item_config.cache.clear
---@param store NougatCacheStore
---@param scope? 'buf'|'win'|'tab'
local function handle_item_cache_clear(clear, store, scope)
  if type(clear) == "string" then
    -- "A"
    return handle_item_cache_clear({ clear }, store, scope)
  end

  if type(clear) ~= "table" then
    error("unexpected item.cache.clear type: " .. type(clear))
  end

  if type(clear[2]) == "string" then
    -- {"A", "B"}
    ---@cast clear string[]

    ---@type table<nougat_item_config.cache.clear__get_id, string[]>
    local event_by_get_id = {}
    for i = 1, #clear do
      local event = clear[i]
      local get_id = ic.get_invalidation_id_getter(event, scope)
      if event_by_get_id[get_id] then
        table.insert(event_by_get_id[get_id], event)
      else
        event_by_get_id[get_id] = { event }
      end
      for get_id_fn, events in pairs(event_by_get_id) do
        u.on_event(events, function(info)
          store:clear(get_id_fn(info))
        end)
      end
    end
  elseif type(clear[2]) == "function" then
    -- {"C", get_id}
    -- {{"D", "E"}, get_id}

    local get_id = clear[2] --[[@as nougat_item_config.cache.clear__get_id]]
    u.on_event(clear[1], function(info)
      store:clear(get_id(info))
    end)
  elseif type(clear[2]) == "table" then
    -- {{"A", "B"}, {"C", get_id}, {{"D", "E"}, get_id}}
    ---@cast clear table[]

    for i = 1, #clear do
      handle_item_cache_clear(clear[i], store, scope)
    end
  end
end

---@param class NougatItem
---@param config nougat_item_config
local function init(class, config)
  ---@class NougatItem
  local self = setmetatable({}, { __index = class })

  self.id = next_id()

  self.ctx = config.ctx or {}

  self.hl = config.hl
  if type(self.hl) == "table" and self.hl.id then
    self._hl_item = self.hl --[[@as NougatItem]]
    self.hl = hl_item_processor
  end

  self.sep_left = iu.normalize_sep(-1, config.sep_left)
  self.prefix = type(config.prefix) == "string" and { config.prefix } or config.prefix
  self.suffix = type(config.suffix) == "string" and { config.suffix } or config.suffix
  self.sep_right = iu.normalize_sep(1, config.sep_right)

  self.prepare = config.prepare

  self.hidden = config.hidden
  if type(self.hidden) == "table" then
    self._item_hidden = self.hidden --[[@as NougatItem]]
    self.hidden = item_hidden_processor[type(self._item_hidden.hidden)]
  end

  self.priority = config.priority

  if config.type == "code" then
    ---@cast config nougat_item_config__code
    self.content = core.code(config.content, {
      align = config.align,
      leading_zero = config.leading_zero,
      min_width = config.min_width,
      max_width = config.max_width,
    })
  elseif config.type == "vim_expr" then
    ---@cast config nougat_item_config__vim_expr
    self.content = core.expression(config.content, {
      align = config.align,
      expand = config.expand,
      is_vimscript = true,
      leading_zero = config.leading_zero,
      min_width = config.min_width,
      max_width = config.max_width,
    })
  elseif config.type == "lua_expr" then
    ---@cast config nougat_item_config__lua_expr
    self.content = core.expression(config.content, {
      id = self.id .. "_expression_fn",
      align = config.align,
      context = config.context or self,
      expand = config.expand,
      leading_zero = config.leading_zero,
      min_width = config.min_width,
      max_width = config.max_width,
    })
  elseif config.type == "literal" then
    ---@cast config nougat_item_config__literal
    local has_opts = config.align or config.leading_zero or config.min_width or config.max_width
    self.content = core.literal(config.content, has_opts and {
      align = config.align,
      leading_zero = config.leading_zero,
      min_width = config.min_width,
      max_width = config.max_width,
    } or nil)
  elseif config.type == "tab_label" then
    ---@cast config nougat_item_config__tab_label
    self.content = core.label(config.content, {
      close = config.close,
      tabnr = config.tabnr,
    })
  else
    ---@cast config nougat_item_config__nil|nougat_item_config__function
    self.content = config.content
  end

  if config.cache then
    ---@type nougat_item_config.cache
    local cache = config.cache

    if cache.store then
      self._cache_store = cache.store
    elseif cache.scope then
      self._cache_store = create_store(cache.scope, self.id .. "_cache_store", cache.initial_value)
    end
    assert(type(self._cache_store) == "table", "one of cache.scope or cache.store is required")

    if cache.get then
      self._cache_get = cache.get
      self.cache = ic.cache_getter._wrap_fn
    elseif cache.scope then
      self.cache = ic.cache_getter[cache.scope]
    end
    assert(type(self.cache) == "function", "one of cache.get or cache.scope is required")

    self._cache_type = (cache.store or cache.initial_value) and "manual" or "auto"
    if self._cache_type == "auto" and type(self.content) == "function" then
      self._get_content = self.content
      self.content = ic.auto_cached_content
    end

    if cache.clear then
      handle_item_cache_clear(cache.clear, self._cache_store, cache.scope)
    end

    ---@diagnostic disable: undefined-field
    if cache.invalidate then
      vim.deprecate("NougatItem option cache.invalidate", "cache.clear", "0.4.0", "nougat.nvim")

      if type(cache.invalidate) == "string" then
        local get_id = ic.get_invalidation_id_getter(cache.invalidate, cache.scope)
        u.on_event(cache.invalidate, function(info)
          invalidate_cache(self._cache_store, get_id, info)
        end)
      elseif type(cache.invalidate) == "table" then
        assert(type(cache.invalidate[1]) == "string", "unexpected cache.invalidate[1], expected string")
        local get_id = cache.invalidate[2]
        assert(type(get_id) == "function", "unexpected cache.invalidate[2], expected function")
        u.on_event(cache.invalidate[1], function(info)
          invalidate_cache(self._cache_store, get_id, info)
        end)
      end
    end
    ---@diagnostic enable: undefined-field
  end

  if type(self.content) == "table" then
    self.content.len = #self.content

    if self.content[1] and self.content[1].id then
      -- NougatItem[]

      self.content._overflow = "hide-all"

      for i = 1, #self.content do
        if self.content[i].priority then
          self.content._overflow = "hide-self"
          break
        end
      end
    end
  end

  if config.on_click then
    if type(self.content) == "function" then
      self._content = self.content
      self._on_click = config.on_click
      self._on_click_id = self.id .. "_click_handler"
      self._on_click_context = config.context
      self.content = content_function_processor
    else
      ---@diagnostic disable-next-line: param-type-mismatch
      self.content = core.clickable(self.content, {
        id = self.id .. "_click_handler",
        context = config.context or self,
        on_click = config.on_click,
      })
    end
  end

  if type(self.content) == "table" then
    self.content.next = u.get_next_list_item
  end

  self._config = config.config or {}

  self._on_init_breakpoints = config.on_init_breakpoints

  if config.init then
    config.init(self)
  end

  return self
end

---@class NougatItem
---@field id integer
---@field hl? nougat_item_hl
---@field sep_left? nougat_separator[]
---@field prefix? nougat_item_affix
---@field content nougat_item_content
---@field suffix? nougat_item_affix
---@field sep_right? nougat_separator[]
---@field hidden? nougat_item_hidden
---@field prepare? fun(self: NougatItem, ctx: nougat_bar_ctx):nil
---@field ctx table
local Item = setmetatable({}, {
  __call = init,
  __name = "NougatItem",
})

---@param breakpoints integer[]
function Item:_init_breakpoints(breakpoints)
  iu.prepare_config_breakpoints(self, breakpoints)
  iu.prepare_property_breakpoints(self, "sep_left", breakpoints)
  iu.prepare_property_breakpoints(self, "prefix", breakpoints)
  iu.prepare_property_breakpoints(self, "suffix", breakpoints)
  iu.prepare_property_breakpoints(self, "sep_right", breakpoints)

  if self._on_init_breakpoints then
    self:_on_init_breakpoints(breakpoints)
  end
end

---@param ctx nougat_bar_ctx
function Item:config(ctx)
  return self._config[ctx.ctx.breakpoint] or self._config
end

---@alias NougatItem.constructor fun(config: nougat_item_config): NougatItem
---@type NougatItem|NougatItem.constructor
local NougatItem = Item

return NougatItem
