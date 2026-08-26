local api = vim.api
local fn = vim.fn

local hover = require "configs.tabufline_hover"
local utils = require "nvchad.tabufline.utils"

local txt = utils.txt
local btn = utils.btn
local style_buf = utils.style_buf

local M = {}
local goto_buf_patched = false
local commands_defined = false
local buffer_menu_win
local buffer_menu_buf

local function is_regular_edit_win(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local bufnr = api.nvim_win_get_buf(winid)
  local buftype = vim.bo[bufnr].buftype
  local filetype = vim.bo[bufnr].filetype

  return buftype == "" and filetype ~= "NvimTree" and filetype ~= "aerial"
end

local function patch_goto_buf()
  if goto_buf_patched then
    return
  end

  local ok, tabufline = pcall(require, "nvchad.tabufline")
  if not ok or type(tabufline.goto_buf) ~= "function" then
    return
  end

  local original_goto_buf = tabufline.goto_buf

  tabufline.goto_buf = function(bufnr)
    local cur_win = api.nvim_get_current_win()
    if not is_regular_edit_win(cur_win) then
      for _, winid in ipairs(api.nvim_tabpage_list_wins(0)) do
        if is_regular_edit_win(winid) then
          api.nvim_set_current_win(winid)
          break
        end
      end
    end

    return original_goto_buf(bufnr)
  end

  goto_buf_patched = true
end

patch_goto_buf()

local function tabufline_opts()
  return require("nvconfig").ui.tabufline
end

local function file_tree_width()
  local opts = tabufline_opts()

  for _, win in pairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(win)].ft == opts.treeOffsetFt then
      return api.nvim_win_get_width(win) + 1
    end
  end

  return 0
end

local function available_space()
  local opts = tabufline_opts()
  local reserved = file_tree_width() + 14

  if fn.tabpagenr "$" > 1 then
    reserved = reserved + 8 + fn.tabpagenr("$") * 3
  end

  return math.max(opts.bufwidth, vim.o.columns - reserved)
end

local function visible_count()
  return math.max(1, math.floor(available_space() / tabufline_opts().bufwidth))
end

local function define_navigation_commands()
  if commands_defined then
    return
  end

  vim.cmd [[
    function! TbBufScrollRight(a,b,c,d)
      lua require("configs.tabufline_modules").scroll_right()
    endfunction
    function! TbBufScrollLeft(a,b,c,d)
      lua require("configs.tabufline_modules").scroll_left()
    endfunction
    function! TbBufSelect(a,b,c,d)
      lua require("configs.tabufline_modules").select_buffer()
    endfunction
  ]]

  commands_defined = true
end

local function scroll_button(label, function_name, disabled)
  if disabled then
    return txt(label, "BufScrollDisabled")
  end

  return btn(label, "BufScroll", function_name)
end

local function set_offset(offset)
  local bufs = vim.tbl_filter(api.nvim_buf_is_valid, vim.t.bufs or {})
  local max_offset = math.max(1, #bufs - visible_count() + 1)
  vim.t.tabufline_offset = math.min(math.max(1, offset), max_offset)
  vim.cmd.redrawtabline()
end

function M.scroll_right()
  set_offset((vim.t.tabufline_offset or 1) + 1)
end

function M.scroll_left()
  set_offset((vim.t.tabufline_offset or 1) - 1)
end

local function close_buffer_menu()
  if buffer_menu_win and api.nvim_win_is_valid(buffer_menu_win) then
    api.nvim_win_close(buffer_menu_win, true)
  end
  buffer_menu_win = nil
  buffer_menu_buf = nil
end

local function choose_buffer(bufs, index)
  local bufnr = bufs[index]
  close_buffer_menu()
  if bufnr and api.nvim_buf_is_valid(bufnr) then
    require("nvchad.tabufline").goto_buf(bufnr)
  end
end

local function mouse_menu_line()
  local pos = vim.fn.getmousepos()
  if pos.line and pos.line > 0 then
    return pos.line
  end

  if buffer_menu_win and api.nvim_win_is_valid(buffer_menu_win) then
    local row = api.nvim_win_get_position(buffer_menu_win)[1]
    return math.max(1, (pos.screenrow or 1) - row - 1)
  end

  return 1
end

function M.select_buffer()
  local bufs = vim.tbl_filter(api.nvim_buf_is_valid, vim.t.bufs or {})
  local items = vim.tbl_map(function(bufnr)
    local name = api.nvim_buf_get_name(bufnr)
    return name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":~:.")
  end, bufs)

  if #items == 0 then
    return
  end

  close_buffer_menu()
  local pos = vim.fn.getmousepos()
  local width = 1
  for _, item in ipairs(items) do
    width = math.max(width, vim.fn.strdisplaywidth(item))
  end
  width = math.min(width + 2, math.max(1, vim.o.columns - 2))

  buffer_menu_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buffer_menu_buf, 0, -1, false, items)
  vim.bo[buffer_menu_buf].buftype = "nofile"
  vim.bo[buffer_menu_buf].bufhidden = "wipe"
  vim.bo[buffer_menu_buf].modifiable = false

  local col = math.max(0, math.min((pos.screencol or 1) - 1, vim.o.columns - width - 1))
  buffer_menu_win = api.nvim_open_win(buffer_menu_buf, true, {
    relative = "editor",
    row = 1,
    col = col,
    width = width,
    height = math.min(#items, 12),
    style = "minimal",
    border = "rounded",
    title = " Buffers ",
    title_pos = "center",
  })

  vim.wo[buffer_menu_win].cursorline = true
  vim.wo[buffer_menu_win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
  api.nvim_create_autocmd("WinLeave", {
    buffer = buffer_menu_buf,
    once = true,
    callback = close_buffer_menu,
  })

  local opts = { buffer = buffer_menu_buf, silent = true, nowait = true }
  vim.keymap.set("n", "<CR>", function()
    choose_buffer(bufs, vim.fn.line("."))
  end, opts)
  vim.keymap.set("n", "<LeftMouse>", function()
    choose_buffer(bufs, mouse_menu_line())
  end, opts)
  vim.keymap.set("n", "q", close_buffer_menu, opts)
  vim.keymap.set("n", "<Esc>", close_buffer_menu, opts)
end

function M.buffers()
  local opts = tabufline_opts()
  local buffers = {}
  local bufs = vim.tbl_filter(api.nvim_buf_is_valid, vim.t.bufs or {})
  local count = visible_count()
  local current_buf = api.nvim_get_current_buf()

  hover.reset()
  vim.t.bufs = bufs

  local current_index = 1
  for i, nr in ipairs(bufs) do
    if current_buf == nr then
      current_index = i
      break
    end
  end

  local offset = vim.t.tabufline_offset or 1
  if vim.t.tabufline_last_buf ~= current_buf then
    if current_index < offset then
      offset = current_index
    elseif current_index >= offset + count then
      offset = current_index - count + 1
    end
  end
  offset = math.min(math.max(1, offset), math.max(1, #bufs - count + 1))
  vim.t.tabufline_offset = offset
  vim.t.tabufline_last_buf = current_buf

  for i = offset, math.min(#bufs, offset + count - 1) do
    local nr = bufs[i]
    local segment = style_buf(nr, i, opts.bufwidth)
    table.insert(buffers, {
      bufnr = nr,
      text = segment,
    })
  end

  local visual_col = file_tree_width() + 1
  local texts = {}

  for _, segment in ipairs(buffers) do
    local width = api.nvim_eval_statusline(segment.text, { use_tabline = true }).width
    hover.record(visual_col, visual_col + width - 1, segment.bufnr)

    visual_col = visual_col + width
    table.insert(texts, segment.text)
  end

  define_navigation_commands()
  vim.api.nvim_set_hl(0, "TbBufScroll", { link = "TabLine" })
  vim.api.nvim_set_hl(0, "TbBufScrollDisabled", { link = "Comment" })

  local controls = btn(" ≡ ", "BufScroll", "BufSelect")
  if #bufs > count then
    local max_offset = math.max(1, #bufs - count + 1)
    controls = scroll_button(" < ", "BufScrollLeft", offset <= 1)
      .. scroll_button(" > ", "BufScrollRight", offset >= max_offset)
      .. controls
  end

  return table.concat(texts) .. txt("%=", "Fill") .. controls
end

return M
