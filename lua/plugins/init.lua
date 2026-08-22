return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    event = { "BufReadPre", "BufNewFile" },
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "folke/which-key.nvim",
    lazy = false,
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = function(_, opts)
      opts.view = vim.tbl_deep_extend("force", opts.view or {}, {
        preserve_window_proportions = false,
      })
      return opts
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    opts = function()
      return require "configs.cmp"
    end,
  },

  {
    "windwp/nvim-autopairs",
    opts = {
      map_cr = false,
    },
  },

  {
    "https://codeberg.org/FelipeLema/cmp-async-path.git",
    enabled = false,
  },

  {
    "stevearc/aerial.nvim",
    cmd = { "AerialOpen", "AerialOpenAll", "AerialToggle", "AerialNavToggle" },
    branch = "nvim-0.11",
    opts = require("configs.aerial"),
    keys = {
      { "<C-\\>", "<cmd>AerialToggle<cr>", desc = "Toggle Symbol Outline" },
    },
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      win = {
        wo = {
          winfixwidth = false,
          winfixheight = false,
        },
      },
      preview = {
        type = "split",
        relative = "win",
        position = "right",
        size = 0.5,
        scratch = false,
        wo = {
          winfixwidth = false,
          winfixheight = false,
        },
      },
      modes = {
        lsp_references = {
          auto_refresh = false,
          follow = false,
          pinned = true,
        },
        lsp_incoming_calls = {
          auto_refresh = false,
          follow = false,
          pinned = true,
        },
        lsp_outgoing_calls = {
          auto_refresh = false,
          follow = false,
          pinned = true,
        },
      },
    },
    config = function(_, opts)
      require("trouble").setup(opts)

      local trouble_window = require "trouble.view.window"
      if not trouble_window._nvim_user_winleave_patched then
        local on = trouble_window.on

        trouble_window.on = function(self, events, callback, event_opts)
          local is_trouble_window = self.opts
            and self.opts.bo
            and self.opts.bo.filetype == "trouble"

          if is_trouble_window and events == "WinLeave" then
            return
          end

          return on(self, events, callback, event_opts)
        end
        trouble_window._nvim_user_winleave_patched = true
      end
    end,
  },

  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = require("configs.copilot"),
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    build = "make tiktoken",
    cmd = {
      "CopilotChat",
      "CopilotChatOpen",
      "CopilotChatClose",
      "CopilotChatToggle",
      "CopilotChatExplain",
      "CopilotChatReview",
      "CopilotChatFix",
      "CopilotChatOptimize",
      "CopilotChatDocs",
      "CopilotChatTests",
    },
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    opts = require("configs.copilotchat"),
  },

  {
    "rmagatti/auto-session",
    lazy = false,
    event = "VimEnter",
    opts = require("configs.session"),
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      return require("configs.treesitter").setup(opts)
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  },

  -- 添加 markdown-preview.nvim
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = "cd app && yarn install",
    config = function()
      -- 可选：自定义全局变量（例如自动打开浏览器）
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
    end,
  },

  --{
    --"akinsho/toggleterm.nvim",
    --version = "*",
    --opts = require("configs.toggleterm"),
  --},

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
