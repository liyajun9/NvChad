require "nvchad.autocmds"
require("configs.tabufline_hover").setup()

local resizeable_sidebar_filetypes = {
  NvimTree = true,
  aerial = true,
  trouble = true,
}

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
  callback = function(args)
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    if resizeable_sidebar_filetypes[vim.bo[buf].filetype] then
      vim.api.nvim_set_option_value("winfixwidth", false, { scope = "local", win = win })
      vim.api.nvim_set_option_value("winfixheight", false, { scope = "local", win = win })
    end
  end,
})

if vim.treesitter and vim.treesitter.foldexpr then
  vim.treesitter.foldexpr = function()
    return "0"
  end
end

local function update_session_sidebar_state(force)
  if vim.g.session_sidebar_state_frozen and not force then
    return
  end

  local data = {
    nvim_tree_open = false,
  }

  local ok_tree, nvim_tree = pcall(require, "nvim-tree.api")
  if ok_tree then
    data.nvim_tree_open = nvim_tree.tree.is_visible()
  end

  vim.g.session_sidebar_state = data
end

local session_launch_arg = vim.g.session_launch_arg or vim.fn.argv(0)

local function absolute_dir(dir)
  if type(dir) ~= "string" or dir == "" then
    return nil
  end

  return vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.g.session_sidebar_state_frozen = false
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      if vim.g.SessionLoad then
        return
      end

      local ok_as, auto_session = pcall(require, "auto-session")
      local ok_config, auto_session_config = pcall(require, "auto-session.config")
      local ok_lib, lib = pcall(require, "auto-session.lib")
      if not ok_as or not ok_lib then
        return
      end

      local function get_session_start_dir()
        if type(vim.g.session_launch_dir) == "string" and vim.g.session_launch_dir ~= "" then
          return absolute_dir(vim.g.session_launch_dir), true
        end

        local arg = session_launch_arg
        if type(arg) == "string" and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
          return absolute_dir(arg), true
        end

        return absolute_dir(vim.fn.getcwd()), false
      end

      local function session_dirs_by_absolute_path()
        local sessions = {}
        local root_dir = auto_session.get_root_dir()

        for _, session_path in ipairs(vim.fn.globpath(root_dir, "*.vim", false, true)) do
          if not session_path:match("x%.vim$") then
            local encoded = vim.fn.fnamemodify(session_path, ":t:r")
            local decoded = lib.unescape_session_name(encoded)
            local abs = absolute_dir(decoded)

            if abs then
              sessions[abs] = decoded
            end
          end
        end

        return sessions
      end

      local function find_nearest_session_dir(start_dir)
        local dir = absolute_dir(start_dir)
        local home = vim.fn.expand("~"):gsub("/$", "")
        local sessions = session_dirs_by_absolute_path()

        while dir and dir ~= "" do
          if dir == home then
            break
          end

          if sessions[dir] then
            return sessions[dir], dir
          end

          local parent = vim.fn.fnamemodify(dir, ":h")
          if parent == dir then
            break
          end

          dir = parent
        end
      end

      local start_dir, from_dir_arg = get_session_start_dir()
      if not from_dir_arg or not start_dir then
        return
      end

      if start_dir ~= absolute_dir(vim.fn.getcwd()) then
        vim.cmd("cd " .. vim.fn.fnameescape(start_dir))
      end

      local restore_dir, restore_abs_dir = find_nearest_session_dir(start_dir)
      if restore_dir then
        if restore_abs_dir and restore_abs_dir ~= absolute_dir(vim.fn.getcwd()) then
          vim.cmd("cd " .. vim.fn.fnameescape(restore_abs_dir))
        end

        local ok_restore, restored = pcall(function()
          return auto_session.restore_session(restore_dir)
        end)
        if ok_restore and restored and ok_config then
          auto_session_config.auto_save = true
        end
      end
    end, 100)
  end,
})

--关闭lua文件的tab
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua" },
  callback = function()
  vim.opt_local.expandtab = true
  vim.opt_local.tabstop = 2
  vim.opt_local.shiftwidth = 2
  vim.opt_local.softtabstop = 2
end,
})

--关闭markdown等文本文件的拼写检查
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "txt", "log", "csv" },
  callback = function()
  vim.opt_local.spell = false
end,
})

--解决ctrl-d,ctrl-u滚动步距随着窗口大小改变而改变的问题
vim.api.nvim_create_autocmd({ "VimEnter", "WinEnter", "BufWinEnter", "WinResized" }, {
  callback = function()
    local cfg = vim.api.nvim_win_get_config(0)
    if cfg.relative ~= "" then
      return
    end

    vim.opt_local.scroll = 3
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter", "WinClosed" }, {
  callback = function()
    update_session_sidebar_state()
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    update_session_sidebar_state(true)
    vim.g.session_sidebar_state_frozen = true
  end,
})
