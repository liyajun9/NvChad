require("nvchad.configs.lspconfig").defaults()

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

vim.lsp.config("clangd", {
  cmd = {
    "/usr/local/opt/llvm@15/bin/clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=never",
  },
})


local servers = { "html", "cssls", "clangd", "cmake", "pyright", "lua_ls", "bashls", "marksman", "lemminx", "yamlls" }
vim.lsp.enable(servers)

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    local rename_opts = { buffer = args.buf, desc = "LSP Rename" }
    local rename = require "nvchad.lsp.renamer"
    local client = vim.lsp.get_client_by_id(args.data.client_id)

    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "<leader>cR", rename, rename_opts)
    vim.keymap.set("n", "<leader>rn", rename, rename_opts)
    vim.keymap.set("n", "<leader>ra", rename, rename_opts)

    if client and client.name == "clangd" then
      vim.keymap.set("n", "<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", {
        buffer = args.buf,
        desc = "Switch C/C++ source/header",
      })
    end
  end,
})

-- read :h vim.lsp.config for changing options of lsp servers 
