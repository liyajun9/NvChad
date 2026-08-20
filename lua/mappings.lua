require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set
local unmap = vim.keymap.del

map("n", "gl", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
local function is_edit_window(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local config = vim.api.nvim_win_get_config(winid)
  if config.relative ~= "" then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  local filetype = vim.bo[bufnr].filetype
  return vim.bo[bufnr].buftype == "" and filetype ~= "NvimTree" and filetype ~= "aerial"
end

map("n", "<leader>cq", function()
  local target_win
  local current_win = vim.api.nvim_get_current_win()

  if is_edit_window(current_win) then
    target_win = current_win
  else
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if is_edit_window(winid) then
        target_win = winid
        break
      end
    end
  end

  pcall(vim.cmd, "cclose")

  if target_win and vim.api.nvim_win_is_valid(target_win) then
    vim.api.nvim_set_current_win(target_win)
  end
end, { desc = "Close quickfix" })

map("n", "<leader>b[", function()
  require("nvchad.tabufline").move_buf(-1)
end, { desc = "Move buffer tab left" })

map("n", "<leader>b]", function()
  require("nvchad.tabufline").move_buf(1)
end, { desc = "Move buffer tab right" })

-- map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

pcall(unmap, "i", "<C-b>")
pcall(unmap, "n", "<C-s>")
pcall(unmap, "n", "<C-c>")
pcall(unmap, "n", "<leader>h")
pcall(unmap, "n", "<leader>v")
pcall(unmap, { "n", "t" }, "<A-v>")

map("i", "<C-a>", "<ESC>^i", { desc = "move beginning of line" })
-- Comment toggle (Ctrl+/)
map("n", "<C-/>", "gcc", { desc = "Toggle Comment", remap = true})
map("n", "<C-_>", "gcc", { desc = "Toggle Comment", remap = true})
map("v", "<C-/>", "gc", { desc = "Toggle Comment", remap = true})
map("v", "<C-_>", "gc", { desc = "Toggle Comment", remap = true})
map("n", "<leader>cp", "<cmd>Copilot panel open<cr>", { desc = "Copilot panel" })
map("n", "<leader>cc", "<cmd>CopilotChatToggle<cr>", { desc = "CopilotChat toggle" })
map("v", "<leader>cc", "<cmd>CopilotChat<cr>", { desc = "CopilotChat prompt selection" })
map("v", "<leader>ce", "<cmd>CopilotChatExplain<cr>", { desc = "CopilotChat explain" })
map("v", "<leader>cf", "<cmd>CopilotChatFix<cr>", { desc = "CopilotChat fix" })
map("v", "<leader>co", "<cmd>CopilotChatOptimize<cr>", { desc = "CopilotChat optimize" })
map("v", "<leader>cd", "<cmd>CopilotChatDocs<cr>", { desc = "CopilotChat docs" })
map("v", "<leader>ct", "<cmd>CopilotChatTests<cr>", { desc = "CopilotChat tests" })

-- 在 Normal 模式下按 <leader>mp 开启/关闭预览
map("n", "<leader>mp", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle Markdown Preview" })

-- auto copy to system clipboard while selection
--[[
vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "v:*",
  callback = function()
    vim.keymap.set("v", "<Esc>", "<cmd>normal! y<cr><Esc>", { silent = true, noremap = true })
  end,
})
--]]
