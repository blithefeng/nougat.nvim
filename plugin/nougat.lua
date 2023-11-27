local cmd_completion_store = {
  [""] = { "profile" },
  profile = { "bench", "start", "stop", "inspect" },
  ["profile:inspect"] = {
    "bar",
    "item",
  },
}

local commands
commands = {
  profile = {
    bench = function()
      require("nougat.profiler").bench()
    end,
    start = function()
      require("nougat.profiler").start()
    end,
    stop = function()
      require("nougat.profiler").stop()
    end,
    inspect = function(params)
      print(vim.inspect(require("nougat.profiler").inspect(unpack(params.args))))
    end,
  },
}

local function eval_luastring(value)
  local ok, result = pcall(loadstring("return " .. value, value))
  return (not ok or result == nil) and value or result
end

local function make_params(info, args)
  local params = {
    bang = info.bang,
    args = {},
  }

  local tbl_arg
  for _, arg in ipairs(args) do
    if tbl_arg then
      tbl_arg = tbl_arg .. arg
      if string.find(tbl_arg, "}$") then
        table.insert(params.args, eval_luastring(tbl_arg))
        tbl_arg = nil
      end
    elseif string.find(arg, "^{") then
      tbl_arg = arg
      if string.find(tbl_arg, "}$") then
        table.insert(params.args, eval_luastring(tbl_arg))
        tbl_arg = nil
      end
    elseif string.find(arg, "=") and (not params.args[1] or type(params.args[1]) == "table") then
      if not params.args[1] then
        params.args[1] = {}
      end

      local parts = vim.split(arg, "=")
      local key = table.remove(parts, 1)
      local value = table.concat(parts, "=")
      params.args[1][key] = eval_luastring(value)
    else
      table.insert(params.args, eval_luastring(arg))
    end
  end

  return params
end

vim.api.nvim_create_user_command("Nougat", function(info)
  local args = info.fargs

  ---@type string|nil
  local cmd_name = table.remove(args, 1)
  if not cmd_name then
    return vim.api.nvim_err_writeln("[Nougat] missing command")
  end

  local cmd = commands[cmd_name]
  if type(cmd) == "function" then
    return cmd(make_params(info, args))
  end

  if type(cmd) ~= "table" then
    return vim.api.nvim_err_writeln(string.format("[Nougat] unknown command: %s", cmd_name))
  end

  if cmd[args[1]] then
    local subcmd_name = table.remove(args, 1)
    local subcmd = cmd[subcmd_name]

    if type(subcmd) == "function" then
      return subcmd(make_params(info, args))
    end

    if type(subcmd) ~= "table" then
      return vim.api.nvim_err_writeln(string.format("[Nougat] unknown subcommand: %s", subcmd_name))
    end

    if subcmd[args[1]] then
      local subsubcmd_name = table.remove(args, 1)
      local subsubcmd = subcmd[subsubcmd_name]

      if type(subsubcmd) ~= "function" then
        return vim.api.nvim_err_writeln(
          string.format("[Neotest] unknown subcommand: %s %s", subcmd_name, subsubcmd_name)
        )
      end

      return subsubcmd(make_params(info, args))
    end

    if not subcmd[1] then
      return vim.api.nvim_err_writeln("[Nougat] missing subcommand")
    end

    return subcmd[1](make_params(info, args))
  end

  if not cmd[1] then
    return vim.api.nvim_err_writeln("[Nougat] missing subcommand")
  end

  return cmd[1](make_params(info, args))
end, {
  bang = true,
  nargs = "*",
  complete = function(_, cmd_line)
    local args = vim.split(cmd_line, "%s+", { trimempty = true })
    local last_idx = #args
    local last_arg = args[last_idx]

    local is_partial = not string.match(cmd_line, "%s$")

    local cmd_scope = ""

    -- command
    if last_idx == 1 then
      return cmd_completion_store[cmd_scope]
    elseif last_idx == 2 and is_partial then
      return vim.tbl_filter(function(cmd)
        return not not string.find(cmd, "^" .. last_arg)
      end, cmd_completion_store[cmd_scope])
    end

    -- sub-command
    cmd_scope = args[2]
    if last_idx == 2 and cmd_completion_store[cmd_scope] then
      return cmd_completion_store[cmd_scope]
    elseif #args == 3 and is_partial and cmd_completion_store[cmd_scope] then
      local items = vim.tbl_filter(function(cmd)
        return not not string.find(cmd, "^" .. last_arg)
      end, cmd_completion_store[cmd_scope])
      if #items > 0 then
        return
      end
    end

    -- sub-sub-command
    cmd_scope = string.format("%s:%s", args[2], args[3])
    if last_idx == 3 and cmd_completion_store[cmd_scope] then
      return cmd_completion_store[cmd_scope]
    elseif #args == 4 and is_partial and cmd_completion_store[cmd_scope] then
      local items = vim.tbl_filter(function(cmd)
        return not not string.find(cmd, "^" .. last_arg)
      end, cmd_completion_store[cmd_scope])
      if #items > 0 then
        return
      end
    end
  end,
})
