pcall(require, "luacov")

local sep = require("nougat.separator")

local t = require("tests.util")

describe("nougat.separator", function()
  describe("none", function()
    it("works", function()
      local s = sep.none()
      t.type(s, "table")
      t.eq(s.hl, {})
      t.type(s.content, "nil")
    end)
  end)

  for _, name in ipairs({
    "space",
    "vertical",
    "heavy_veritcal",
    "double_vertical",
    "full_block",
    "left_chevron",
    "left_chevron_solid",
    "right_chevron",
    "right_chevron_solid",
    "falling_diagonal",
    "rising_diagonal",
    "left_lower_triangle_solid",
    "left_upper_triangle_solid",
    "right_lower_triangle_solid",
    "right_upper_triangle_solid",
    "left_half_circle",
    "left_half_circle_solid",
    "right_half_circle",
    "right_half_circle_solid",
  }) do
    describe(name, function()
      it("works w/o hl", function()
        local s = sep[name]()
        t.type(s, "table")
        t.type(s.content, "string")
        t.type(s.hl, "nil")
      end)

      it("works w/ hl table", function()
        local hl = { bg = "red", fg = "yellow" }
        local s = sep[name](hl)
        t.type(s.content, "string")
        t.ref(s.hl, hl)
      end)

      it("works w/ hl function", function()
        local hl = function()
          return { bg = "red", fg = "yellow" }
        end
        local s = sep[name](hl)
        t.type(s.content, "string")
        t.ref(s.hl, hl)
      end)

      it("works w/ hl autoblend", function()
        local s = sep[name](true)
        t.type(s.content, "string")
        t.type(s.hl, "table")
        t.eq(vim.tbl_contains({ "nil", "number" }, type(s.hl.bg)), true)
        t.type(s.hl.fg, "nil")
      end)
    end)
  end
end)
