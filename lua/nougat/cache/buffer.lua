local create_store = require("nougat.cache").create_store
local on_event = require("nougat.util").on_event

local default_value = {}

local store = create_store("buf", "nougat.cache.buffer", default_value)

local hooks = {}

local function run_hook(name, value, cache, bufnr)
  for i = 1, #hooks[name] do
    hooks[name][i](value, cache, bufnr)
  end
end

local function get_option_getter(name)
  return function(bufnr)
    local value = store[bufnr][name]
    if value == nil then
      value = vim.bo[bufnr][name]
      store[bufnr][name] = value
    end
    return value
  end
end

local get = {
  filename = function(bufnr)
    local filename = store[bufnr].filename
    if not filename then
      filename = vim.api.nvim_buf_get_name(bufnr)
      store[bufnr].filename = filename
    end
    return filename
  end,
  filetype = function(bufnr)
    local filetype = store[bufnr].filetype
    if not filetype then
      filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
      store[bufnr].filetype = filetype
    end
    return filetype
  end,
  modifiable = get_option_getter("modifiable"),
  modified = get_option_getter("modified"),
  readonly = get_option_getter("readonly"),
}

local subscribe = {
  filename = function()
    hooks["filename.change"] = {}

    on_event({ "BufReadPost", "BufFilePost" }, function(params)
      local bufnr, filename = params.buf, params.match
      local cache = store[bufnr]

      cache.filename = filename

      run_hook("filename.change", filename, cache, bufnr)
    end)
  end,
  filetype = function()
    hooks["filetype.change"] = {}

    on_event("FileType", function(params)
      local bufnr, filetype = params.buf, params.match
      local cache = store[bufnr]

      cache.filetype = filetype

      run_hook("filetype.change", filetype, cache, bufnr)
    end)
  end,
  modifiable = function()
    hooks["modifiable.change"] = {}

    on_event("OptionSet modifiable", function()
      local bufnr, modifiable = vim.api.nvim_get_current_buf(), vim.v.option_new
      local cache = store[bufnr]

      cache.modifiable = modifiable

      run_hook("modifiable.change", modifiable, cache, bufnr)
    end)
  end,
  modified = function()
    hooks["modified.change"] = {}

    default_value.modified = false

    on_event("BufModifiedSet", function(params)
      local bufnr = params.buf
      local cache = store[bufnr]

      cache.modified = vim.api.nvim_buf_get_option(bufnr, "modified")

      run_hook("modified.change", cache.modified, cache, bufnr)
    end)
  end,
  readonly = function()
    hooks["readonly.change"] = {}

    on_event("OptionSet readonly", function()
      local bufnr, readonly = vim.api.nvim_get_current_buf(), vim.v.option_new
      local cache = store[bufnr]

      cache.readonly = readonly

      run_hook("readonly.change", readonly, cache, bufnr)
    end)
  end,
  gitstatus = function()
    hooks["gitstatus.change"] = {}

    local provider
    if pcall(require, "gitsigns") then
      provider = "gitsigns"
    end

    if not provider then
      return
    end

    if provider == "gitsigns" then
      on_event("User GitSignsUpdate", function(params)
        local bufnr = params.buf
        local cache = store[bufnr]

        vim.schedule(function()
          local status = vim.fn.getbufvar(bufnr, "gitsigns_status_dict", false)
          if not status then
            cache.gitstatus = nil
            return
          end

          local gitstatus = cache.gitstatus
          if not gitstatus then
            gitstatus = {}
            cache.gitstatus = gitstatus
          end

          gitstatus.added = status.added or 0
          gitstatus.changed = status.changed or 0
          gitstatus.removed = status.removed or 0
          gitstatus.total = gitstatus.added + gitstatus.changed + gitstatus.removed

          run_hook("gitstatus.change", gitstatus, cache, bufnr)
        end)
      end)
    end
  end,
}

local mod = {
  store = store,
}

local enabled_key = {}

---@param key string
function mod.enable(key)
  if enabled_key[key] then
    return
  end

  if not subscribe[key] then
    error("missing subscribe")
  end

  subscribe[key]()

  enabled_key[key] = true
end

function mod.get(key, bufnr)
  return get[key](bufnr)
end

---@param event string
---@param callback fun(value: any, cache: table, bufnr: integer)
function mod.on(event, callback)
  if not hooks[event] then
    error("unknown event")
  end

  hooks[event][#hooks[event] + 1] = callback
end

return mod
