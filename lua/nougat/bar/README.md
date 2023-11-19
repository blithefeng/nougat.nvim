# NougatBar

_Signature:_ `(type: 'statusline'|'tabline'|'winbar', options?: table) -> NougatBar`

The sweet `NougatBar` represents the `statusline` / `tabline` / `winbar`.

```lua
local Bar = require("nougat.bar")
```

## Parameter: `type`

**Type:** `'statusline'|'tabline'|'winbar'`

Type of the bar.

## Parameter: `options`

### `breakpoints`

**Type:** `integer[]` (optional)

It sets the responsive breakpoints for all the items added to the bar.

The table should be a list of ascending/descending integers.

For ascending list, breakpoints are treated as _min width_ and
the first element must be `0`.

For descending list, breakpoints are treated as _max width_ and
the first element must be `math.huge`.

**Example**

```lua
local breakpoint = { l = 1, m = 2, s = 3 }
local breakpoints = { [breakpoint.l] = math.huge, [breakpoint.m] = 128, [breakpoint.s] = 80 }

local bar = Bar('statusline', { breakpoints = breakpoints })
```

## Methods

### `bar:add_item`

_Signature:_ `(item: string|table|NougatItem) -> NougatItem`

**Example**

```lua
local Item = require("nougat.item")

-- string content
bar:add_item("[nougat.nvim]")
-- or NougatItem options
bar:add_item({
  prefix = "[",
  content = "nougat.nvim",
  suffix = "]",
})
-- or NougatItem
bar:add_item(Item({
  prefix = "[",
  content = "nougat.nvim",
  suffix = "]",
}))
```

## Utilities

`NougatBar` comes with a handful of utils.

```lua
local bar_util = require("nougat.bar.util")
```

### `set_statusline`

_Signature:_ `(bar, opts) -> nil`

`bar` can be a `NougatBar` instance:

```lua
local stl = Bar("statusline")

bar_util.set_statusline(stl)
```

Or a function `(ctx: nougat_core_expression_context) -> NougatBar`.

```lua
local stl = Bar("statusline")
local stl_inactive = Bar("statusline")

-- use separate statusline focused/unfocused window
bar_util.set_statusline(function(ctx)
  return ctx.is_focused and stl or stl_inactive
end)
```

`opts` is a `table` with the shape ` { filetype?: string }`.

If `filetype` is given, the bar will only be used for that filetype.

```lua
local stl_fugitive = Bar("statusline")
local stl_help = Bar("statusline")

-- set filetype specific statusline
for ft, stl_ft in pairs({
  fugitive = stl_fugitive,
  help = stl_help,
}) do
  u.set_statusline(stl_ft, { filetype = ft })
end
```

### `refresh_statusline`

_Signature:_ `(force_all? boolean) -> nil`

### `set_tabline`

_Signature:_ `(bar) -> nil`

`bar` can be a `NougatBar` instance or a function `(ctx: nougat_core_expression_context) -> NougatBar`.

### `refresh_tabline`

_Signature:_ `() -> nil`

### `set_winbar`

_Signature:_ `(bar, opts) -> nil`

`bar` can be a `NougatBar` instance or a function `(ctx: nougat_core_expression_context) -> NougatBar`.

`opts` is a `table` with the shape ` { filetype?: string, global?: boolean }`.

If `filetype` is given, the bar will only be used for that filetype.

If `global` is `true`, the bar will be used for global winbar, otherwise only local winbar is set.

### `refresh_winbar`

_Signature:_ `(force_all?: boolean) -> nil`
