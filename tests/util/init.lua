local mod = {}

function mod.eq(...)
  return assert.are.same(...)
end

function mod.neq(...)
  return assert["not"].are.same(...)
end

function mod.type(v, t)
  return mod.eq(type(v), t)
end

---@param tbl table
---@param keys string[]
function mod.tbl_pick(tbl, keys)
  if not keys or #keys == 0 then
    return tbl
  end

  local new_tbl = {}
  for _, key in ipairs(keys) do
    new_tbl[key] = tbl[key]
  end
  return new_tbl
end

---@param tbl table
---@param keys string[]
function mod.tbl_omit(tbl, keys)
  if not keys or #keys == 0 then
    return tbl
  end

  local new_tbl = vim.deepcopy(tbl)
  for _, key in ipairs(keys) do
    rawset(new_tbl, key, nil)
  end
  return new_tbl
end

return mod