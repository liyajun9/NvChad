local api = vim.api
local fn = vim.fn

local hover = require "configs.tabufline_hover"
local utils = require "nvchad.tabufline.utils"

local txt = utils.txt
local btn = utils.btn
local style_buf = utils.style_buf

local M = {}
local goto_buf_patched = false

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
  local reserved = file_tree_width() + 8

  if fn.tabpagenr "$" > 1 then
    reserved = reserved + 8 + fn.tabpagenr("$") * 3
  end

  return math.max(opts.bufwidth, vim.o.columns - reserved)
end

function M.buffers()
  local opts = tabufline_opts()
  local buffers = {}
  local has_current = false

  hover.reset()
  vim.t.bufs = vim.tbl_filter(api.nvim_buf_is_valid, vim.t.bufs or {})

  for i, nr in ipairs(vim.t.bufs) do
    if ((#buffers + 1) * opts.bufwidth) > available_space() then
      if has_current then
        break
      end

      table.remove(buffers, 1)
    end

    has_current = api.nvim_get_current_buf() == nr or has_current

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

  return table.concat(texts) .. txt("%=", "Fill")
end

return M
