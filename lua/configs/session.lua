return {
  auto_restore = true,
  auto_save = true,
  auto_restore_last_session = false,
  args_allow_files_auto_save = true,
  close_unsupported_windows = true,
  git_use_branch_name = false,
  suppressed_dirs = {
    vim.fn.expand "~",
    vim.fn.expand "~/Downloads",
    vim.fn.expand "~/Desktop",
  },
  session_lens = {
    load_on_setup = false,
  },
  pre_save_cmds = {
    function()
      local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("/$", "")
      if cwd ~= vim.fn.getcwd() then
        vim.cmd("cd " .. vim.fn.fnameescape(cwd))
      end

      pcall(vim.cmd, "AerialClose")

      local ok_tree, nvim_tree = pcall(require, "nvim-tree.api")
      if ok_tree and nvim_tree.tree.is_visible() then
        nvim_tree.tree.close()
      end
    end,
  },
  post_restore_cmds = {
    function()
      vim.defer_fn(function()
        pcall(vim.cmd, "silent! only")
        pcall(vim.cmd, "redraw!")
      end, 50)
    end,
  },
  save_extra_data = function()
    local data = vim.g.session_sidebar_state
    if type(data) ~= "table" then
      data = {
        nvim_tree_open = false,
      }
    end

    return vim.json.encode(data)
  end,
  restore_extra_data = function(_, extra_data)
    local ok_decode, data = pcall(vim.json.decode, extra_data)
    if not ok_decode or type(data) ~= "table" then
      return
    end

    vim.defer_fn(function()
      if data.nvim_tree_open then
        local ok_tree, nvim_tree = pcall(require, "nvim-tree.api")
        if ok_tree then
          if not nvim_tree.tree.is_visible() then
            nvim_tree.tree.open()
          end

          -- Apply the width after NvimTree finishes its own layout pass.
          vim.defer_fn(function()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local buf = vim.api.nvim_win_get_buf(win)
              if vim.bo[buf].filetype == "NvimTree" then
                pcall(vim.api.nvim_win_set_width, win, 30)
                break
              end
            end
          end, 100)
        end
      end
    end, 200)
  end,
}
