local restore_layout_active = false
local restore_resize_timer
local restore_deactivate_timer

local function unlock_nvim_tree_layout()
  local ok_view_state, view_state = pcall(require, "nvim-tree.view-state")
  if ok_view_state and view_state.Active then
    view_state.Active.winopts.winfixwidth = false
    view_state.Active.winopts.winfixheight = false
  end
end

local function tree_width_for_ratio(ratio)
  ratio = tonumber(ratio) or 0.18
  return math.floor(vim.o.columns * ratio)
end

local function resize_restored_tree()
  if not restore_layout_active then
    return
  end

  local ok_tree, nvim_tree = pcall(require, "nvim-tree.api")
  if not ok_tree or not nvim_tree.tree.is_visible() then
    return
  end

  local data = vim.g.session_restore_layout
  local ratio = type(data) == "table" and data.nvim_tree_width_ratio or 0.18
  local width = tree_width_for_ratio(ratio)
  unlock_nvim_tree_layout()

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "NvimTree" then
        vim.api.nvim_set_option_value("winfixwidth", false, { scope = "local", win = win })
        vim.api.nvim_set_option_value("winfixheight", false, { scope = "local", win = win })
        pcall(vim.api.nvim_win_set_width, win, width)
        break
      end
    end
  end
end

local function schedule_restored_tree_resize(width)
  vim.schedule(function()
    vim.defer_fn(function()
      unlock_nvim_tree_layout()

      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "NvimTree" then
            vim.api.nvim_set_option_value("winfixwidth", false, { scope = "local", win = win })
            vim.api.nvim_set_option_value("winfixheight", false, { scope = "local", win = win })
            pcall(vim.api.nvim_win_set_width, win, width)
            break
          end
        end
      end
    end, 50)
  end)
end

local function schedule_restore_deactivation()
  if restore_deactivate_timer then
    pcall(restore_deactivate_timer.stop, restore_deactivate_timer)
    pcall(restore_deactivate_timer.close, restore_deactivate_timer)
  end

  -- Keep correcting asynchronous startup layouts briefly, then allow manual resizing.
  restore_deactivate_timer = vim.defer_fn(function()
    restore_layout_active = false
    restore_deactivate_timer = nil
  end, 2000)
end

vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
  group = vim.api.nvim_create_augroup("UserSessionLayout", { clear = true }),
  callback = function()
    if not restore_layout_active then
      return
    end

    if restore_resize_timer then
      pcall(restore_resize_timer.stop, restore_resize_timer)
      pcall(restore_resize_timer.close, restore_resize_timer)
      restore_resize_timer = nil
    end

    restore_resize_timer = vim.defer_fn(resize_restored_tree, 100)
  end,
})

return {
  auto_restore = false,
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
        local tree_win
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "NvimTree" then
            tree_win = win
            break
          end
        end

        if tree_win and vim.o.columns > 0 then
          local data = vim.g.session_sidebar_state
          if type(data) ~= "table" then
            data = {}
          end

          data.nvim_tree_open = true
          data.nvim_tree_width_ratio = vim.api.nvim_win_get_width(tree_win) / vim.o.columns
          vim.g.session_sidebar_state = data
        else
          local data = vim.g.session_sidebar_state
          if type(data) ~= "table" then
            data = {}
          end
          data.nvim_tree_open = false
          vim.g.session_sidebar_state = data
        end

        nvim_tree.tree.close()
      end
    end,
  },
  post_restore_cmds = {
    function()
      vim.defer_fn(function()
        local data = vim.g.session_restore_layout
        restore_layout_active = type(data) == "table"

        local edit_win
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype
            if vim.bo[buf].buftype == "" and filetype ~= "NvimTree" and filetype ~= "aerial" and filetype ~= "trouble" then
              edit_win = edit_win or win
            end
          end
        end

        -- Close only sidebars created during startup; keep all editor windows.
        local ok_tree, nvim_tree = pcall(require, "nvim-tree.api")
        if ok_tree and nvim_tree.tree.is_visible() then
          pcall(nvim_tree.tree.close)
        end
        pcall(vim.cmd, "silent! AerialClose")

        if edit_win and vim.api.nvim_win_is_valid(edit_win) then
          vim.api.nvim_set_current_win(edit_win)
        end

        if edit_win and type(data) == "table" and data.nvim_tree_open and ok_tree then
          local width = tree_width_for_ratio(data.nvim_tree_width_ratio)
          unlock_nvim_tree_layout()
          local ok_view_state, view_state = pcall(require, "nvim-tree.view-state")
          if ok_view_state then
            view_state.Active.width = width
            view_state.Active.initial_width = width
          end

          nvim_tree.tree.open()
          schedule_restored_tree_resize(width)
          schedule_restore_deactivation()
          vim.api.nvim_set_current_win(edit_win)
        end

        vim.g.session_restore_layout = data
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

    vim.g.session_restore_layout = data
  end,
}
