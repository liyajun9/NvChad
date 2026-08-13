local M = {}

local api = vim.api
local fn = vim.fn

M.segments = {}
M.winid = nil

local function close()
  if M.winid and api.nvim_win_is_valid(M.winid) then
    api.nvim_win_close(M.winid, true)
  end

  M.winid = nil
end

local function show(text, row, col)
  close()

  local max_width = math.min(#text, math.max(20, vim.o.columns - 4))
  local lines = { text }
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  M.winid = api.nvim_open_win(buf, false, {
    relative = "editor",
    row = math.min(row, vim.o.lines - 3),
    col = math.max(0, math.min(col, vim.o.columns - max_width - 2)),
    width = max_width,
    height = 1,
    style = "minimal",
    border = "rounded",
    focusable = false,
    noautocmd = true,
    zindex = 80,
  })
end

function M.record(start_col, end_col, bufnr)
  M.segments[#M.segments + 1] = {
    start_col = start_col,
    end_col = end_col,
    bufnr = bufnr,
  }
end

function M.reset()
  M.segments = {}
end

function M.find(col)
  for _, segment in ipairs(M.segments) do
    if col >= segment.start_col and col <= segment.end_col then
      return segment.bufnr
    end
  end
end

function M.on_mouse_move()
  local pos = fn.getmousepos()

  if pos.screenrow ~= 1 then
    close()
    return
  end

  local bufnr = M.find(pos.screencol)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    close()
    return
  end

  local path = api.nvim_buf_get_name(bufnr)
  if path == "" then
    path = "[No Name]"
  else
    path = fn.fnamemodify(path, ":p")
  end

  show(path, 1, pos.screencol - 1)
end

function M.show_current()
  local path = api.nvim_buf_get_name(0)
  if path == "" then
    path = "[No Name]"
  else
    path = fn.fnamemodify(path, ":p")
  end

  vim.notify(path, vim.log.levels.INFO, { title = "Buffer path" })
end

function M.setup()
  vim.o.mousemoveevent = true

  vim.keymap.set({ "n", "i" }, "<MouseMove>", function()
    M.on_mouse_move()
  end, { silent = true, desc = "Show full tab buffer path on hover" })

  vim.keymap.set("n", "<leader>bn", M.show_current, { desc = "Show current buffer full path" })
end

return M
