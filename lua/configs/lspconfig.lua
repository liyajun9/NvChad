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

local function peek_definition()
  local implementation_clients = vim.lsp.get_clients { bufnr = 0, method = "textDocument/implementation" }
  local definition_clients = vim.lsp.get_clients { bufnr = 0, method = "textDocument/definition" }
  local client = implementation_clients[1] or definition_clients[1]
  if not client then
    vim.notify("No LSP definition or implementation provider", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
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
        end_line = math.min(line_count, end_line + 8)
        lines = vim.api.nvim_buf_get_lines(target_buf, start_line, end_line, false)
      end

      vim.lsp.util.open_floating_preview(lines, filetype, {
        border = "rounded",
        focusable = true,
        max_height = math.max(8, math.floor(vim.o.lines * 0.6)),
        max_width = math.max(40, math.floor(vim.o.columns * 0.8)),
      })
    end)
    return true
  end

  local function request_definition()
    local definition_client = definition_clients[1]
    if not definition_client then
      vim.notify("Definition not found", vim.log.levels.INFO)
      return
    end

    local definition_params = vim.lsp.util.make_position_params(0, definition_client.offset_encoding)
    vim.lsp.buf_request(0, "textDocument/definition", definition_params, function(err, result)
      if err then
        vim.notify(err.message or "Definition request failed", vim.log.levels.WARN)
      elseif not preview_result(result) then
        vim.notify("Definition not found", vim.log.levels.INFO)
      end
    end)
  end

  if implementation_clients[1] then
    vim.lsp.buf_request(0, "textDocument/implementation", params, function(err, result)
      if not err and preview_result(result) then
        return
      end
      request_definition()
    end)
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
