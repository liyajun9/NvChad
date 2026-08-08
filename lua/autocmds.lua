require "nvchad.autocmds"

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
      local ok_lib, lib = pcall(require, "auto-session.lib")
      if not ok_as or not ok_lib then
        return
      end

      local function get_session_start_dir()
        if type(vim.g.session_launch_dir) == "string" and vim.g.session_launch_dir ~= "" then
          return vim.g.session_launch_dir, true
        end

        local arg = session_launch_arg
        if type(arg) == "string" and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
          return (vim.fn.fnamemodify(arg, ":p"):gsub("/$", "")), true
        end

        return vim.fn.getcwd(), false
      end

      local function find_nearest_session_dir(start_dir, exact_only)
        local dir = start_dir
        local session_path = auto_session.get_root_dir() .. lib.escape_session_name(dir) .. ".vim"
        if exact_only then
          return vim.fn.filereadable(session_path) == 1 and dir or nil
        end

        local root = vim.fs.root(dir, { ".git", "compile_commands.json", "CMakeLists.txt", "SConstruct" })
        root = root or dir

        while dir and dir ~= "" do
          session_path = auto_session.get_root_dir() .. lib.escape_session_name(dir) .. ".vim"
          local readable = vim.fn.filereadable(session_path) == 1
          if readable then
            return dir
          end
          if dir == root then
            break
          end
          local parent = vim.fn.fnamemodify(dir, ":h")
          if parent == dir then
            break
          end
          dir = parent
        end
      end

      local start_dir, from_dir_arg = get_session_start_dir()
      if not from_dir_arg then
        return
      end

      if start_dir ~= vim.fn.getcwd() then
        vim.cmd("cd " .. vim.fn.fnameescape(start_dir))
      end

      local restore_dir = find_nearest_session_dir(start_dir, true)
      if restore_dir then
        pcall(function()
          auto_session.restore_session(restore_dir)
        end)
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
