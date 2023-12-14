pcall(require, "luacov")

local Bar = require("nougat.bar")

local t = require("tests.util")

describe("nut.mode", function()
  local bar, ctx

  local nut

  before_each(function()
    bar = Bar("statusline")
    ctx = t.make_ctx(0, {
      ctx = {},
      width = vim.api.nvim_win_get_width(0),
    })

    package.loaded["nougat.nut.mode"] = nil
    nut = require("nougat.nut.mode")
  end)

  after_each(function()
    if ctx.bufnr then
      vim.api.nvim_buf_delete(ctx.bufnr, { force = true })
    end
  end)

  it("works", function()
    bar:add_item(nut.create())

    t.eq(
      bar:generate(ctx),
      table.concat({
        "%#bg_663399_fg_ffcd00_#",
        "NORMAL",
        "%#bg_ffcd00_fg_663399_#",
      })
    )

    local co = coroutine.running()

    vim.cmd("startinsert")
    vim.defer_fn(function()
      local _, err = pcall(function()
        t.match(bar:generate(ctx), "INSERT")
      end)

      vim.cmd("stopinsert")
      vim.defer_fn(function()
        coroutine.resume(co, err)
      end, 20)
    end, 20)

    local err = coroutine.yield()
    if err then
      error(err)
    end
  end)

  it("refreshes immediately after exiting terminal mode", function()
    bar:add_item(nut.create())

    t.match(bar:generate(ctx), "NORMAL")

    local co = coroutine.running()

    vim.cmd("terminal echo nougat.nvim")

    vim.cmd("startinsert")
    vim.defer_fn(function()
      local _, err = pcall(function()
        t.match(bar:generate(ctx), "TERMINAL")
      end)

      if err then
        return coroutine.resume(co, err)
      end

      t.spy(vim, "cmd")

      vim.cmd("stopinsert")
      vim.defer_fn(function()
        _, err = pcall(function()
          t.spy(vim.cmd).was.called.with("redrawstatus")
          t.match(bar:generate(ctx), "TERMINAL NORMAL")
        end)

        vim.cmd:revert()

        return coroutine.resume(co, err)
      end, 20)
    end, 20)

    local err = coroutine.yield(co)
    if err then
      error(err)
    end
  end)
end)
