pcall(require, "luacov")

local Bar = require("nougat.bar")

local t = require("tests.util")

describe("nut.git.status", function()
  local bar, ctx

  local nut

  before_each(function()
    require("nougat.store")._clear()

    bar = Bar("statusline")
    ctx = t.make_ctx(0, {
      ctx = {},
      width = vim.api.nvim_win_get_width(0),
    })

    nut = require("nougat.nut.git.status")
  end)

  after_each(function()
    if ctx.bufnr then
      vim.api.nvim_buf_delete(ctx.bufnr, { force = true })
    end
  end)

  describe("w/ gitsigns", function()
    before_each(function()
      package.loaded["gitsigns"] = {}
    end)

    after_each(function()
      package.loaded["gitsigns"] = nil
    end)

    it("works", function()
      bar:add_item(nut.create({
        prefix = " ",
        content = {
          nut.count("added", { prefix = "+", suffix = " " }),
          nut.count("changed", { prefix = "~", suffix = " " }),
          nut.count("removed", { prefix = "-", suffix = " " }),
        },
      }))

      vim.b[ctx.bufnr].gitsigns_status_dict = {
        added = 1,
      }
      vim.api.nvim_exec_autocmds("User", { pattern = "GitSignsUpdate" })
      vim.wait(0)

      t.eq(bar:generate(ctx), " +1 ")

      vim.b[ctx.bufnr].gitsigns_status_dict = {
        added = 0,
        changed = 2,
        removed = 3,
      }
      vim.api.nvim_exec_autocmds("User", { pattern = "GitSignsUpdate" })
      vim.wait(0)

      t.eq(bar:generate(ctx), " ~2 -3 ")
    end)

    it("can handle missing gitstatus", function()
      bar:add_item(nut.create({
        prefix = " ",
        content = {
          nut.count("added", { prefix = "+", suffix = " " }),
        },
      }))

      vim.b[ctx.bufnr].gitsigns_status_dict = nil
      vim.api.nvim_exec_autocmds("User", { pattern = "GitSignsUpdate" })
      vim.wait(0)

      t.eq(bar:generate(ctx), "")
    end)
  end)

  describe("w/ vim-gitgutter", function()
    before_each(function()
      t.stub(vim.fn, "exists").on_call_with("*GitGutterGetHunkSummary").returns(1)
    end)

    after_each(function()
      vim.fn.exists:revert()

      if type(vim.fn.GitGutterGetHunkSummary) == "table" and vim.fn.GitGutterGetHunkSummary.revert then
        vim.fn.GitGutterGetHunkSummary:revert()
      end
    end)

    it("works", function()
      bar:add_item(nut.create({
        prefix = " ",
        content = {
          nut.count("added", { prefix = "+", suffix = " " }),
          nut.count("changed", { prefix = "~", suffix = " " }),
          nut.count("removed", { prefix = "-", suffix = " " }),
        },
      }))

      t.stub(vim.fn, "GitGutterGetHunkSummary").returns({ 1 })

      vim.g.gitgutter_hook_context = { bufnr = ctx.bufnr }
      vim.api.nvim_exec_autocmds("User", { pattern = "GitGutter" })
      vim.wait(0)

      t.eq(bar:generate(ctx), " +1 ")

      vim.fn.GitGutterGetHunkSummary:revert()

      t.stub(vim.fn, "GitGutterGetHunkSummary").returns({ 2, 4, 6 })

      vim.g.gitgutter_hook_context = { bufnr = ctx.bufnr }
      vim.api.nvim_exec_autocmds("User", { pattern = "GitGutter" })
      vim.wait(0)

      t.eq(bar:generate(ctx), " +2 ~4 -6 ")
    end)

    it("can handle missing gitstatus", function()
      bar:add_item(nut.create({
        prefix = " ",
        content = {
          nut.count("added", { prefix = "+", suffix = " " }),
        },
      }))

      t.stub(vim.fn, "GitGutterGetHunkSummary")

      vim.g.gitgutter_hook_context = { bufnr = ctx.bufnr }
      vim.api.nvim_exec_autocmds("User", { pattern = "GitGutter" })
      vim.wait(0)

      t.eq(bar:generate(ctx), "")
    end)
  end)

  it("can handle missing provider", function()
    bar:add_item(nut.create({
      prefix = " ",
      content = {
        nut.count("added", { prefix = "+", suffix = " " }),
      },
    }))

    t.eq(bar:generate(ctx), "")
  end)
end)
