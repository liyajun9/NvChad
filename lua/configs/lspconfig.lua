local nvchad_lsp = require "nvchad.configs.lspconfig"
nvchad_lsp.defaults()

vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "if_many",
    focusable = false,
    header = "",
    prefix = "",
  },
})

local clangd_capabilities = vim.deepcopy(nvchad_lsp.capabilities)
clangd_capabilities.textDocument.completion.completionItem.snippetSupport = false

vim.lsp.config("clangd", {
  cmd = {
    "/usr/local/opt/llvm@15/bin/clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=never",
  },
  capabilities = clangd_capabilities,
})

local peek_previews = {}
local peek_layout
local peek_click_buffers = {}

local function cleanup_peek_click_maps()
  local used_buffers = {}
  for _, preview in ipairs(peek_previews) do
    used_buffers[preview.bufnr] = true
    used_buffers[preview.source_buf] = true
  end

  for bufnr in pairs(peek_click_buffers) do
    if not used_buffers[bufnr] then
      pcall(vim.keymap.del, "n", "<LeftMouse>", { buffer = bufnr })
      peek_click_buffers[bufnr] = nil
    end
  end
end

local function close_peek_after(index)
  for i = #peek_previews, index + 1, -1 do
    local preview = table.remove(peek_previews, i)
    if vim.api.nvim_win_is_valid(preview.winid) then
      pcall(vim.api.nvim_win_close, preview.winid, true)
    end
  end

  cleanup_peek_click_maps()
  if #peek_previews == 0 then
    peek_layout = nil
  end
end

local function handle_peek_click(winid)
  for i, preview in ipairs(peek_previews) do
    if preview.winid == winid then
      close_peek_after(i)
      return
    end

    if preview.parent_win == winid then
      close_peek_after(i - 1)
      return
    end
  end

  close_peek_after(0)
end

local function install_peek_click_map(bufnr)
  if peek_click_buffers[bufnr] then
    return
  end

  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if mapping.lhs == "<LeftMouse>" then
      return
    end
  end

  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    local winid = mouse.winid
    handle_peek_click(winid)

    if vim.api.nvim_win_is_valid(winid) and mouse.line > 0 and mouse.column > 0 then
      vim.api.nvim_set_current_win(winid)
      pcall(vim.api.nvim_win_set_cursor, winid, { mouse.line, mouse.column - 1 })
    end
  end, { buffer = bufnr, silent = true, noremap = true, nowait = true })
  peek_click_buffers[bufnr] = true
end

local function open_peek_window(lines, filetype, level, parent_win)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = filetype
  vim.bo[bufnr].syntax = filetype
  vim.bo[bufnr].modifiable = false

  local content_width = 1
  for _, line in ipairs(lines) do
    content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
  end

  local available_width = math.max(1, vim.o.columns - 4)
  local available_height = math.max(1, vim.o.lines - 4)
  local width = math.min(available_width, math.max(20, content_width + 2))
  local height = math.min(available_height, math.max(8, #lines))
  local max_row = math.max(0, vim.o.lines - height - 2)
  local max_col = math.max(0, vim.o.columns - width - 2)
  local min_col = 0

  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(winid)
    if vim.bo[buf].filetype == "NvimTree" then
      local position = vim.api.nvim_win_get_position(winid)
      min_col = math.max(min_col, position[2] + vim.api.nvim_win_get_width(winid) + 1)
    end
  end
  min_col = math.min(min_col, max_col)

  if not peek_layout and parent_win and vim.api.nvim_win_is_valid(parent_win) then
    local cursor = vim.api.nvim_win_get_cursor(parent_win)
    local cursor_screen = vim.fn.screenpos(parent_win, cursor[1], cursor[2] + 1)
    local anchor_row = math.max(0, cursor_screen.row - 1)
    local anchor_col = math.max(min_col, cursor_screen.col - 1)

    local function fits(direction)
      if direction == "right" then
        return anchor_col + 2 + width <= vim.o.columns - 2
      elseif direction == "left" then
        return anchor_col - width - 2 >= min_col
      elseif direction == "below" then
        return anchor_row + 2 + height <= vim.o.lines - 2
      end
      return anchor_row - height - 2 >= 0
    end

    for _, direction in ipairs { "right", "left", "below", "above" } do
      if fits(direction) then
        peek_layout = {
          direction = direction,
          anchor_row = anchor_row,
          anchor_col = anchor_col,
        }
        break
      end
    end
  end

  peek_layout = peek_layout or {
    direction = "right",
    anchor_row = 1,
    anchor_col = min_col,
  }

  local offset = (level - 1) * 4
  local row_offset = (level - 1) * 2
  local row = peek_layout.anchor_row + row_offset
  local col = peek_layout.anchor_col

  if peek_layout.direction == "right" then
    col = peek_layout.anchor_col + 2 + offset
  elseif peek_layout.direction == "left" then
    col = peek_layout.anchor_col - width - 2 - offset
  elseif peek_layout.direction == "below" then
    row = peek_layout.anchor_row + 2 + offset
    col = peek_layout.anchor_col + row_offset
  else
    row = peek_layout.anchor_row - height - 2 - offset
    col = peek_layout.anchor_col + row_offset
  end

  row = math.min(max_row, math.max(0, row))
  col = math.min(max_col, math.max(min_col, col))

  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    focusable = true,
    zindex = 50 + level,
  })
  vim.wo[winid].wrap = false
  vim.wo[winid].cursorline = true

  return bufnr, winid
end

local peek_definition

peek_definition = function(source_buf, source_line, source_col, fallback_client)
  source_buf = source_buf or vim.api.nvim_get_current_buf()
  local parent_win = vim.api.nvim_get_current_win()
  if source_line == nil then
    local cursor = vim.api.nvim_win_get_cursor(0)
    source_line = cursor[1] - 1
    source_col = cursor[2]
  end
  source_col = source_col or 0

  local implementation_clients = vim.lsp.get_clients { bufnr = source_buf, method = "textDocument/implementation" }
  local definition_clients = vim.lsp.get_clients { bufnr = source_buf, method = "textDocument/definition" }
  if #implementation_clients == 0 and #definition_clients == 0 and fallback_client then
    if fallback_client:supports_method("textDocument/implementation", source_buf) then
      implementation_clients = { fallback_client }
    elseif fallback_client:supports_method("textDocument/definition", source_buf) then
      definition_clients = { fallback_client }
    end
  end
  local client = implementation_clients[1] or definition_clients[1]
  if not client then
    vim.notify("No LSP definition or implementation provider", vim.log.levels.WARN)
    return
  end

  local source_text = vim.api.nvim_buf_get_lines(source_buf, source_line, source_line + 1, false)[1] or ""
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(source_buf) },
    position = {
      line = source_line,
      character = vim.str_utfindex(source_text, client.offset_encoding, math.min(source_col, #source_text), false),
    },
  }

  local function preview_result(result)
    if not result or vim.tbl_isempty(result) then
      return false
    end

    local location = result[1] or result
    if location.targetUri then
      location = {
        uri = location.targetUri,
        range = location.targetSelectionRange or location.targetRange,
      }
    end

    vim.schedule(function()
      local uri = location.uri
      local range = location.range
      if not uri or not range then
        return
      end

      local filename = vim.uri_to_fname(uri)
      local target_buf = vim.fn.bufadd(filename)
      vim.fn.bufload(target_buf)
      local filetype = vim.bo[target_buf].filetype
      if filetype == "" then
        filetype = vim.filetype.match { filename = filename } or ""
      end

      local start_line = range.start.line
      local display_start_line = start_line
      local end_line = range["end"].line + 1
      local lines

      local function extract_cpp_function()
        local line_count = vim.api.nvim_buf_line_count(target_buf)
        local source = vim.api.nvim_buf_get_lines(target_buf, start_line, line_count, false)
        local depth = 0
        local opened = false

        for offset, line in ipairs(source) do
          for brace in line:gmatch "[{}]" do
            if brace == "{" then
              depth = depth + 1
              opened = true
            else
              depth = depth - 1
            end
          end

          if opened and depth == 0 then
            end_line = start_line + offset
            return vim.list_slice(source, 1, offset)
          end
        end
      end

      if filetype == "cpp" or filetype == "c" then
        local ok, parser = pcall(vim.treesitter.get_parser, target_buf, filetype)
        if ok and parser then
          local tree = parser:parse()[1]
          local node = tree:root():named_descendant_for_range(
            start_line,
            range.start.character,
            start_line,
            range.start.character
          )

          while node and node:type() ~= "function_definition" do
            node = node:parent()
          end

          if node then
            start_line, _, end_line = node:range()
            display_start_line = start_line
            lines = vim.api.nvim_buf_get_lines(target_buf, start_line, end_line, false)
          end
        end

        if not lines then
          lines = extract_cpp_function()
        end
      end

      if not lines then
        local line_count = vim.api.nvim_buf_line_count(target_buf)
        start_line = math.max(0, start_line - 8)
        display_start_line = start_line
        end_line = math.min(line_count, end_line + 8)
        lines = vim.api.nvim_buf_get_lines(target_buf, start_line, end_line, false)
      end

      local preview_buf, preview_win = open_peek_window(lines, filetype, #peek_previews + 1, parent_win)

      local preview = {
        bufnr = preview_buf,
        winid = preview_win,
        parent_win = parent_win,
        source_buf = target_buf,
        source_start_line = display_start_line,
      }
      table.insert(peek_previews, preview)

      vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(preview_win),
        once = true,
        callback = function(args)
          for i, item in ipairs(peek_previews) do
            if item.winid == preview_win then
              table.remove(peek_previews, i)
              cleanup_peek_click_maps()
              if #peek_previews == 0 then
                peek_layout = nil
              end
              break
            end
          end
        end,
      })

      vim.keymap.set("n", "<leader>pd", function()
        if not vim.api.nvim_win_is_valid(preview_win) then
          return
        end
        local cursor = vim.api.nvim_win_get_cursor(preview_win)
        peek_definition(target_buf, display_start_line + cursor[1] - 1, cursor[2], client)
      end, { buffer = preview_buf, desc = "Peek Definition (nested)" })
      vim.keymap.set("n", "q", function()
        for i, item in ipairs(peek_previews) do
          if item.winid == preview_win then
            close_peek_after(i - 1)
            return
          end
        end
      end, { buffer = preview_buf, silent = true, desc = "Close Peek Definition" })
      install_peek_click_map(preview_buf)
      install_peek_click_map(target_buf)
    end)
    return true
  end

  local function request_definition()
    local definition_client = definition_clients[1]
    if not definition_client then
      vim.notify("Definition not found", vim.log.levels.INFO)
      return
    end

    definition_client:request("textDocument/definition", params, function(err, result)
      if err then
        vim.notify(err.message or "Definition request failed", vim.log.levels.WARN)
      elseif not preview_result(result) then
        vim.notify("Definition not found", vim.log.levels.INFO)
      end
    end, source_buf)
  end

  if implementation_clients[1] then
    implementation_clients[1]:request("textDocument/implementation", params, function(err, result)
      if not err and preview_result(result) then
        return
      end
      request_definition()
    end, source_buf)
  else
    request_definition()
  end
end


local servers = { "html", "cssls", "clangd", "cmake", "pyright", "lua_ls", "bashls", "marksman", "lemminx", "yamlls" }
vim.lsp.enable(servers)

local document_highlight_group = vim.api.nvim_create_augroup("user_lsp_document_highlight", { clear = true })

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
  group = document_highlight_group,
  callback = function()
    vim.lsp.buf.clear_references()
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    local rename_opts = { buffer = args.buf, desc = "LSP Rename" }
    local rename = require "nvchad.lsp.renamer"
    local client = vim.lsp.get_client_by_id(args.data.client_id)

    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "grr", function()
      require("telescope.builtin").lsp_references {
        include_current_line = true,
        include_declaration = true,
        preview = {
          timeout = 2000,
        },
      }
    end, {
      buffer = args.buf,
      desc = "LSP References (Telescope)",
    })
    vim.keymap.set("n", "grR", "<cmd>Trouble lsp_references toggle focus=true<cr>", {
      buffer = args.buf,
      desc = "LSP References (Trouble)",
    })
    vim.keymap.set("n", "grI", "<cmd>Trouble lsp_incoming_calls toggle focus=true<cr>", {
      buffer = args.buf,
      desc = "LSP Incoming Calls (Trouble)",
    })
    vim.keymap.set("n", "grO", "<cmd>Trouble lsp_outgoing_calls toggle focus=true<cr>", {
      buffer = args.buf,
      desc = "LSP Outgoing Calls (Trouble)",
    })
    vim.keymap.set("n", "<leader>pd", peek_definition, {
      buffer = args.buf,
      desc = "Peek Definition",
    })
    vim.keymap.set("n", "<leader>cR", rename, rename_opts)
    vim.keymap.set("n", "<leader>rn", rename, rename_opts)
    vim.keymap.set("n", "<leader>ra", rename, rename_opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {
      buffer = args.buf,
      desc = "LSP Code Action",
    })
    vim.keymap.set({ "n", "v" }, "<2-LeftMouse>", function()
      for _, active_client in ipairs(vim.lsp.get_clients { bufnr = args.buf }) do
        if active_client:supports_method("textDocument/documentHighlight", args.buf) then
          vim.lsp.buf.document_highlight()
          return
        end
      end
    end, {
      buffer = args.buf,
      desc = "Highlight symbol references",
    })

    if client and client.name == "clangd" then
      vim.keymap.set("n", "<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", {
        buffer = args.buf,
        desc = "Switch C/C++ source/header",
      })
    end
  end,
})

-- read :h vim.lsp.config for changing options of lsp servers 
