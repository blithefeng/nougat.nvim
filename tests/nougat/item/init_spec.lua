pcall(require, "luacov")

local Item = require("nougat.item")
local sep = require("nougat.separator")

local t = require("tests.util")

describe("NougatItem", function()
  it("can be initialized", function()
    local item = Item({ content = "" })
    t.type(item.id, "number")
  end)

  describe(":init", function()
    it("is called properly", function()
      local init_params

      local item = Item({
        init = function(...)
          init_params = { ... }
        end,
        content = "",
      })

      t.eq(#init_params, 1)
      t.eq(item, init_params[1])
    end)
  end)

  describe("o.hidden", function()
    it("boolean", function()
      local item = Item({ hidden = true })

      t.eq(item.hidden, true)
    end)

    it("function", function()
      local item = Item({
        hidden = function(_, ctx)
          return ctx.ctx._hidden
        end,
      })

      local ctx = t.make_ctx(0, { ctx = {} })

      ctx.ctx._hidden = true
      t.eq(item:hidden(ctx), true)

      ctx.ctx._hidden = false
      t.eq(item:hidden(ctx), false)
    end)

    it("NougatItem", function()
      local ctx = t.make_ctx(0, { ctx = {} })

      local item

      local bool = Item({ hidden = true })

      item = Item({ hidden = bool })

      t.eq(item:hidden(ctx), true)

      bool.hidden = false
      t.eq(item:hidden(ctx), false)

      local fn = Item({
        hidden = function(_, ctx)
          return ctx.ctx._hidden
        end,
      })

      item = Item({ hidden = fn })

      ctx.ctx._hidden = true
      t.eq(item:hidden(ctx), true)

      ctx.ctx._hidden = false
      t.eq(item:hidden(ctx), false)
    end)
  end)

  describe("o.hl", function()
    it("integer", function()
      local item = Item({ hl = 1 })
      t.eq(item.hl, 1)
    end)

    it("string", function()
      local item = Item({ hl = "NougatTest" })
      t.eq(item.hl, "NougatTest")
    end)

    it("nougat_hl_def", function()
      local hl = { bg = "red" }
      local item = Item({ hl = hl })
      t.ref(item.hl, hl)
    end)

    it("function", function()
      local hl = function()
        return 1
      end

      local item = Item({ hl = hl })

      t.ref(item:hl(t.make_ctx(0)), 1)
    end)

    it("NougatItem", function()
      local item = Item({
        hl = Item({ hl = "NougatTest" }),
      })

      local ctx = t.make_ctx(0)

      t.eq(item:hl(ctx), "NougatTest")

      item = Item({
        hl = Item({
          hl = function()
            return 1
          end,
        }),
      })

      t.eq(item:hl(ctx), 1)
    end)
  end)

  describe("breakpoints", function()
    for _, name in ipairs({ "sep_left", "prefix", "suffix", "sep_right" }) do
      it("o." .. name, function()
        local breakpoints = { 0, 40, 80 }

        local vmap = ({
          sep_left = { sep.space(), sep.vertical() },
          prefix = { "X", "Y" },
          suffix = { "X", "Y" },
          sep_right = { sep.space(), sep.vertical() },
        })[name]

        local value = vmap[1]
        local item = Item({ [name] = value })

        t.eq(item[name], { value })

        value = { vmap[1] }
        item = Item({ [name] = value })

        t.ref(item[name], value)
        t.eq(item[name][2], nil)
        t.eq(item[name][3], nil)

        item:_init_breakpoints(breakpoints)

        t.eq(#item[name], #breakpoints)
        t.ref(item[name], value)
        t.eq(item[name][1], value[1])
        t.eq(item[name][2], value[1])
        t.eq(item[name][3], value[1])

        value = { vmap[1], vmap[2] }
        item = Item({ [name] = value })

        t.ref(item[name], value)
        t.eq(item[name][3], nil)

        item:_init_breakpoints(breakpoints)

        t.eq(#item[name], #breakpoints)
        t.ref(item[name], value)
        t.eq(item[name][1], value[1])
        t.eq(item[name][2], value[2])
        t.eq(item[name][3], value[2])
      end)
    end

    it("config", function()
      local breakpoints = { 0, 40, 80 }
      local ctx = t.make_ctx(0)

      local config = { a = 1 }
      local item = Item({ config = config })
      item:_init_breakpoints(breakpoints)

      ctx.breakpoint = 1
      t.eq(item:config(ctx), { a = 1 })
      ctx.breakpoint = 2
      t.eq(item:config(ctx), { a = 1 })
      ctx.breakpoint = 3
      t.eq(item:config(ctx), { a = 1 })

      config = {
        [1] = { a = 1 },
      }
      item = Item({ config = config })
      item:_init_breakpoints(breakpoints)

      ctx.breakpoint = 1
      t.eq(item:config(ctx), { a = 1 })
      ctx.breakpoint = 2
      t.eq(item:config(ctx), { a = 1 })
      ctx.breakpoint = 3
      t.eq(item:config(ctx), { a = 1 })

      config = {
        a = 1,
        [1] = { b = 2 },
        [2] = { a = 1.1, c = 3 },
      }
      item = Item({ config = config })
      item:_init_breakpoints(breakpoints)

      ctx.breakpoint = 0
      t.ref(item:config(ctx), config)
      t.eq(#item:config(ctx), #breakpoints)

      ctx.breakpoint = 1
      t.ref(item:config(ctx), config[ctx.breakpoint])
      t.eq(item:config(ctx), { a = 1, b = 2 })
      ctx.breakpoint = 2
      t.ref(item:config(ctx), config[ctx.breakpoint])
      t.eq(item:config(ctx), { a = 1.1, b = 2, c = 3 })
      ctx.breakpoint = 3
      t.ref(item:config(ctx), config[ctx.breakpoint])
      t.eq(item:config(ctx), { a = 1.1, b = 2, c = 3 })
    end)

    it("nested items", function()
      local breakpoints = { 0, 40 }

      local ctx = t.make_ctx(0)

      local child_item = Item({
        prefix = "X",
        config = { a = 1 },
      })

      local item = Item({
        prefix = " ",
        content = { child_item },
      })

      item:_init_breakpoints(breakpoints)

      t.eq(#item.prefix, #breakpoints)
      t.eq(item.prefix[1], " ")
      t.eq(item.prefix[2], " ")

      ctx.breakpoint = 0
      t.eq(#child_item.prefix, #breakpoints)
      t.eq(#child_item:config(ctx), #breakpoints)

      ctx.breakpoint = 1
      t.eq(child_item.prefix[ctx.breakpoint], "X")
      t.eq(child_item:config(ctx), { a = 1 })
      ctx.breakpoint = 2
      t.eq(child_item.prefix[ctx.breakpoint], "X")
      t.eq(child_item:config(ctx), { a = 1 })
    end)
  end)

  describe("o.sep_left", function()
    it("is adjusted if right separator is used", function()
      local rcs = sep.right_chevron_solid(true)
      local item = Item({
        sep_left = sep.right_chevron_solid(true),
      })
      t.eq(item.sep_left[1].hl.bg, rcs.hl.fg)
      t.eq(item.sep_left[1].hl.fg, -rcs.hl.bg)
    end)
  end)

  describe("o.sep_right", function()
    it("is adjusted if left separator is used", function()
      local rcs = sep.left_half_circle_solid(true)
      local item = Item({
        sep_right = sep.left_half_circle_solid(true),
      })
      t.eq(item.sep_right[1].hl.bg, rcs.hl.fg)
      t.eq(item.sep_right[1].hl.fg, -rcs.hl.bg)
    end)
  end)

  describe("o.type=code", function()
    it("n", function()
      t.eq(
        Item({
          type = "code",
          content = "n",
          align = "left",
          max_width = 8,
          min_width = 4,
          leading_zero = true,
        }).content,
        "%-04.8n"
      )

      t.eq(
        Item({
          type = "code",
          content = "n",
          align = "right",
          max_width = 8,
          min_width = 4,
          leading_zero = true,
        }).content,
        "%04.8n"
      )
    end)
  end)

  describe("o.type=vim_expr", function()
    it("&option", function()
      t.eq(
        Item({
          type = "vim_expr",
          content = "&filetype",
          align = "left",
          max_width = 8,
          min_width = 4,
        }).content,
        "%-4.8{&filetype}"
      )
    end)

    it("*:variable", function()
      t.eq(
        Item({
          type = "vim_expr",
          content = "g:colors_name",
        }).content,
        "%{g:colors_name}"
      )
    end)

    it(".expand=true", function()
      t.eq(
        Item({
          type = "vim_expr",
          content = "'%4.8{&filetype}'",
          expand = true,
        }).content,
        "%{%'%4.8{&filetype}'%}"
      )
    end)
  end)

  describe("o.type=lua_expr", function()
    describe("function", function()
      local function assert_context(context, ctx)
        t.type(context.bufnr, "number")
        t.type(context.tabid, "number")
        t.type(context.winid, "number")
        t.type(context.is_focused, "boolean")
        t.eq(context.ctx, ctx)
      end

      it("w/o context", function()
        local fn_params

        local item = Item({
          type = "lua_expr",
          align = "left",
          max_width = 8,
          min_width = 4,
          content = function(...)
            fn_params = { ... }
            return "Lua"
          end,
        })

        local fn_name, fn_id = t.match(item.content, "%%-4%.8{v:lua%.(nougat_.+)%((.+)%)}")

        t.eq(_G[fn_name](tonumber(fn_id)), "Lua")

        assert_context(fn_params[1], item)
      end)

      it("w/ context", function()
        local fn_params

        local item_context = {}
        local item = Item({
          type = "lua_expr",
          align = "left",
          max_width = 8,
          min_width = 4,
          content = function(...)
            fn_params = { ... }
            return "Lua"
          end,
          context = item_context,
        })

        local fn_name, fn_id = t.match(item.content, "%%-4%.8{v:lua%.(nougat_.+)%((.+)%)}")

        t.eq(_G[fn_name](tonumber(fn_id)), "Lua")

        assert_context(fn_params[1], item_context)
      end)

      it(".expand=true", function()
        local item = Item({
          type = "lua_expr",
          content = function() end,
          expand = true,
        })

        t.match(item.content, "%%{%%v:lua%.nougat_.+%(.+%)%%}")
      end)
    end)

    it("number", function()
      t.eq(
        Item({
          type = "lua_expr",
          content = 42,
        }).content,
        "%{luaeval('42')}"
      )
    end)

    it("string", function()
      t.eq(
        Item({
          type = "lua_expr",
          content = "'Lua'",
        }).content,
        "%{luaeval('''Lua''')}"
      )
    end)
  end)

  describe("o.type=literal", function()
    describe("w/ opts", function()
      it("boolean", function()
        t.eq(
          Item({
            type = "literal",
            content = true,
            align = "left",
            max_width = 5,
          }).content,
          "%-.5{'true'}"
        )
      end)

      it("number", function()
        t.eq(
          Item({
            type = "literal",
            content = 7,
            leading_zero = true,
            min_width = 3,
          }).content,
          "%03{'7'}"
        )
      end)

      it("string", function()
        t.eq(
          Item({
            type = "literal",
            content = "'%string%'",
            align = "right",
          }).content,
          "%{'''%string%'''}"
        )
      end)
    end)

    describe("w/o opts", function()
      it("boolean", function()
        t.eq(
          Item({
            type = "literal",
            content = true,
          }).content,
          "true"
        )
      end)

      it("number", function()
        t.eq(
          Item({
            type = "literal",
            content = 42,
          }).content,
          "42"
        )
      end)

      it("string", function()
        t.eq(
          Item({
            type = "literal",
            content = "'%string%'",
          }).content,
          "'%%string%%'"
        )
      end)
    end)
  end)

  describe("o.type=tab_label", function()
    it("label", function()
      t.eq(
        Item({
          type = "tab_label",
          content = "label",
          tabnr = 7,
        }).content,
        "%7Tlabel%T"
      )
    end)

    it("close label", function()
      t.eq(
        Item({
          type = "tab_label",
          content = "x",
          tabnr = 7,
          close = true,
        }).content,
        "%7Xx%X"
      )
    end)

    it("close current label", function()
      t.eq(
        Item({
          type = "tab_label",
          content = "x",
          tabnr = 0,
          close = true,
        }).content,
        "%999Xx%X"
      )
    end)

    it("w/o opts", function()
      t.eq(
        Item({
          type = "tab_label",
          content = "x",
        }).content,
        Item({
          type = "literal",
          content = "x",
          align = "right",
        }).content
      )
    end)
  end)

  describe("fn content", function()
    it("works", function()
      local context = {}
      local item

      local function content(self, ctx)
        t.ref(self, item)
        t.ref(ctx, context)
        return "Lua"
      end

      item = Item({ content = content })

      t.eq(item.content, content)
      t.eq(item:content(context), "Lua")
    end)
  end)

  describe("string content", function()
    it("works", function()
      t.eq(Item({ content = "Lua" }).content, "Lua")
    end)
  end)

  describe("table content", function()
    it("string elements", function()
      local item = Item({
        content = { "L", "u", "a" },
      })

      t.eq(item.content.len, 3)
      t.type(item.content.next, "function")
    end)

    it("item elements", function()
      local item = Item({
        content = {
          Item({ content = "L" }),
          Item({ content = "u" }),
          Item({ content = "a" }),
        },
      })

      t.eq(item.content.len, 3)
      t.type(item.content.next, "function")
    end)
  end)

  describe("o.on_click", function()
    it("fn content", function()
      local spy = t.spy()

      local context = {}

      local item = Item({
        content = function()
          return "Lua"
        end,
        on_click = function(id, click_count, mouse_button, modifiers, ctx)
          spy(id, click_count, mouse_button, modifiers)
          t.assert_ctx(ctx)
          t.ref(ctx.ctx, context)
        end,
        context = context,
      })

      t.type(item.content, "function")

      local ctx = t.make_ctx(0, { ctx = context })

      local click_fn, fn_id = t.get_click_fn(item:content(ctx), "Lua")
      click_fn(fn_id, 1, "l", "s")

      t.spy(spy).was.called_with(fn_id, 1, "l", "s")

      local n_click_fn, n_fn_id = t.get_click_fn(item:content(ctx), "Lua")
      t.ref(n_click_fn, click_fn)
      t.eq(n_fn_id, fn_id)

      n_click_fn(fn_id, 1, "l", "s")

      t.spy(spy).was.called(2)
    end)

    it("string content", function()
      local fn_id, click_fn
      local spy = t.spy()

      local item
      item = Item({
        content = "Lua",
        on_click = function(id, click_count, mouse_button, modifiers, ctx)
          spy(id, click_count, mouse_button, modifiers)
          t.assert_ctx(ctx)
          t.ref(ctx.ctx, item)
        end,
      })

      click_fn, fn_id = t.get_click_fn(item.content, "Lua")
      click_fn(fn_id, 1, "l", "s")

      t.spy(spy).was.called_with(fn_id, 1, "l", "s")
    end)
  end)

  describe("o.cache", function()
    it("throws if missing both .scope and .store", function()
      local err = t.error(function()
        Item({
          content = function()
            return "Lua"
          end,
          cache = {},
        })
      end)
      t.match(err, "one of cache.scope or cache.store is required")
    end)

    it("creates store with .scope", function()
      local store
      local item = Item({
        content = function()
          return "Lua"
        end,
        cache = {
          scope = "buf",
          get = function(cstore, ctx)
            store = cstore
            return store[ctx.bufnr]
          end,
        },
      })

      local ctx = t.make_ctx(0, nil)
      local cache = item:cache(ctx)

      t.type(store, "table")
      t.ref(cache, store[ctx.bufnr])
    end)

    it("sets default cache getter for .scope", function()
      local store, item

      local ctx = t.make_ctx(0, { breakpoint = 0 })

      store = require("nougat.store").WinStore("tests.item.default_cache_getter")
      item = Item({
        cache = {
          scope = "win",
          store = store,
        },
      })

      t.ref(item:cache(ctx), store[ctx.winid][ctx.breakpoint])

      store = require("nougat.store").TabStore("tests.item.default_cache_getter")
      item = Item({
        cache = {
          scope = "tab",
          store = store,
        },
      })

      t.ref(item:cache(ctx), store[ctx.tabid][ctx.breakpoint])
    end)

    describe(".clear", function()
      it("throws if unexpected type", function()
        local err = t.error(Item, {
          cache = {
            scope = "buf",
            clear = function() end,
          },
        })
        t.match(err, "unexpected item.cache.clear type: function")
      end)

      describe("=", function()
        local function create_item(clear)
          local content_spy = t.spy()
          local item = Item({
            content = function(_, ctx)
              content_spy()
              return tostring(ctx.winid)
            end,
            cache = {
              scope = "buf",
              clear = clear,
            },
          })
          return item, content_spy
        end

        before_each(function()
          require("nougat.store")._clear()
        end)

        it("event", function()
          local event = "BufModifiedSet"

          local item, content_spy = create_item(event)
          local ctx = t.make_ctx(0, { breakpoint = 0 })

          local content = item:content(ctx)

          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(1)

          vim.api.nvim_exec_autocmds("BufModifiedSet", {
            buffer = ctx.bufnr,
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(2)
        end)

        it("event[]", function()
          local event = { "BufModifiedSet", "BufWinLeave" }

          local item, content_spy = create_item(event)
          local ctx = t.make_ctx(0, { breakpoint = 0 })

          local content = item:content(ctx)

          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(1)

          vim.api.nvim_exec_autocmds("BufModifiedSet", {
            buffer = ctx.bufnr,
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(2)

          vim.api.nvim_exec_autocmds("BufWinLeave", {
            buffer = ctx.bufnr,
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(3)
        end)

        it("{event,get_id}", function()
          local event = {
            "User NougatItemTest",
            function(info)
              return info.data.bufnr
            end,
          }

          local item, content_spy = create_item(event)
          local ctx = t.make_ctx(0, { breakpoint = 0 })

          local content = item:content(ctx)

          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(1)

          vim.api.nvim_exec_autocmds("User", {
            pattern = vim.split(event[1], " ")[2],
            data = { bufnr = ctx.bufnr },
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(2)
        end)

        it("{event[],get_id}", function()
          local event = {
            { "User NougatItemTestA", "User NougatItemTestB" },
            function(info)
              return info.data.bufnr
            end,
          }

          local item, content_spy = create_item(event)
          local ctx = t.make_ctx(0, { breakpoint = 0 })

          local content = item:content(ctx)

          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(1)

          vim.api.nvim_exec_autocmds("User", {
            pattern = vim.split(event[1][1], " ")[2],
            data = { bufnr = ctx.bufnr },
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(2)

          vim.api.nvim_exec_autocmds("User", {
            pattern = vim.split(event[1][2], " ")[2],
            data = { bufnr = ctx.bufnr },
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(3)
        end)

        it("(event|event[]|{event,get_id}|{event[],get_id})[]", function()
          local event = {
            "BufModifiedSet",
            { "BufWinEnter", "BufWinLeave" },
            {
              "User NougatItemTestA",
              function(info)
                return info.data.A
              end,
            },
            {
              { "User NougatItemTestB1", "User NougatItemTestB2" },
              function(info)
                return info.data.B
              end,
            },
          }

          local item, content_spy = create_item(event)
          local ctx = t.make_ctx(0, { breakpoint = 0 })

          local content = item:content(ctx)

          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(1)

          vim.api.nvim_exec_autocmds(event[1], {
            buffer = ctx.bufnr,
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(2)

          vim.api.nvim_exec_autocmds(event[2][1], {
            buffer = ctx.bufnr,
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(3)

          vim.api.nvim_exec_autocmds(event[2][2], {
            buffer = ctx.bufnr,
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(4)

          vim.api.nvim_exec_autocmds("User", {
            pattern = vim.split(event[3][1], " ")[2],
            data = { A = ctx.bufnr },
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(5)

          vim.api.nvim_exec_autocmds("User", {
            pattern = vim.split(event[4][1][1], " ")[2],
            data = { B = ctx.bufnr },
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(6)

          vim.api.nvim_exec_autocmds("User", {
            pattern = vim.split(event[4][1][2], " ")[2],
            data = { B = ctx.bufnr },
          })

          t.eq(item:content(ctx), content)
          t.eq(item:content(ctx), content)
          t.spy(content_spy).was.called(7)
        end)
      end)

      describe("get_id", function()
        it("throws if default not available for scope", function()
          local err = t.error(Item, {
            cache = {
              scope = "tab",
              clear = "TabLeave",
            },
          })
          t.match(err, "default clear get_id not available for cache.scope=tab")
        end)

        it("throws if default not available for event", function()
          local err = t.error(Item, {
            cache = {
              scope = "buf",
              clear = "UserGettingBored",
            },
          })
          t.match(err, "default clear get_id not available for event: UserGettingBored")
        end)
      end)
    end)
  end)
end)
