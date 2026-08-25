local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    c = { "clang_format" },
    cpp = { "clang_format" },
    python = { "black" },
    -- css = { "prettier" },
    -- html = { "prettier" },
  },

  formatters = {
    clang_format = {
      prepend_args = {
        "--style={BasedOnStyle: LLVM, BreakBeforeBraces: Allman}",
      },
    },
  },

  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

return options
