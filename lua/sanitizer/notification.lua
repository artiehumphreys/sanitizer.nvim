local M = {}

local defaults = {
  glyphs = { running = "⟳", ok = "✓", fail = "✗" },
  close_delay = 4000,
  relative = "editor",
  anchor = "NE",
  border = "rounded",
}

local config = defaults

local TITLE = "Sanitizer"
local SEPARATOR_CHAR = "─"
local RUNNING_HL = "DiagnosticInfo"
local MS_PER_SEC = 1000
local TICK_MS = 1000 -- elapsed-counter refresh interval
local WIN_ROW = 1 -- rows below the top editor edge
local WIN_ZINDEX = 50

-- static float options, identical every open
local FLOAT_OPTS = {
  style = "minimal",
  focusable = false,
  noautocmd = true,
  zindex = WIN_ZINDEX,
}

local buf, win, start_time
local counter_timer, close_timer

local ns = vim.api.nvim_create_namespace("sanitizer_notification") -- required by nvim_buf_set_extmark

---@param opts table
M.setup = function(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})
end

---@return string
local function elapsed()
  return math.floor((vim.uv.now() - start_time) / MS_PER_SEC) .. "s"
end

-- create-or-reuse the float
---@param glyph string
---@param hl string
---@param label string
local function draw(glyph, hl, label)
  local message = glyph .. "  " .. label .. " " .. elapsed()
  local width = math.max(vim.fn.strdisplaywidth(TITLE), vim.fn.strdisplaywidth(message))
  local lines = { TITLE, string.rep(SEPARATOR_CHAR, width), message }

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- glyph sits on the last line (0-indexed)
  vim.api.nvim_buf_set_extmark(buf, ns, #lines - 1, 0, { end_col = #glyph, hl_group = hl })

  local geo = {
    relative = config.relative,
    anchor = config.anchor,
    row = WIN_ROW,
    col = vim.o.columns,
    width = width,
    height = #lines,
  }
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_config(win, geo)
  else
    win = vim.api.nvim_open_win(
      buf,
      false,
      vim.tbl_extend("error", geo, FLOAT_OPTS, { border = config.border })
    )
  end

  -- debounce: every draw resets the close countdown.
  if not close_timer then
    close_timer = vim.uv.new_timer()
  end
  ---@diagnostic disable: need-check-nil
  close_timer:stop()
  close_timer:start(config.close_delay, 0, function()
    vim.schedule(M.close)
  end)
  ---@diagnostic enable: need-check-nil
end

---@param get_label fun() : string
M.start = function(get_label)
  start_time = vim.uv.now()
  draw(config.glyphs.running, RUNNING_HL, get_label())

  if not counter_timer then
    counter_timer = vim.uv.new_timer()
  end
  ---@diagnostic disable: need-check-nil
  counter_timer:stop() -- always non-nil
  counter_timer:start(TICK_MS, TICK_MS, function()
    vim.schedule(function()
      draw(config.glyphs.running, RUNNING_HL, get_label())
    end)
  end)
  ---@diagnostic enable: need-check-nil
end

---@param get_label fun() : string
---@param ok boolean
M.finish = function(get_label, ok)
  if counter_timer then
    counter_timer:stop()
    counter_timer:close()
    counter_timer = nil
  end
  local glyph = ok and config.glyphs.ok or config.glyphs.fail
  local hl = ok and "DiagnosticOk" or "DiagnosticError"
  draw(glyph, hl, get_label())
end

M.close = function()
  for _, t in ipairs({ counter_timer, close_timer }) do
    if t then
      t:stop()
      t:close()
    end
  end
  counter_timer, close_timer = nil, nil
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  win, buf = nil, nil
end

return M
