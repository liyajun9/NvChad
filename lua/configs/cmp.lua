local cmp = require "cmp"
local opts = require "nvchad.configs.cmp"

opts.sources = cmp.config.sources({
  { name = "nvim_lsp" },
  { name = "luasnip" },
  { name = "buffer" },
  { name = "nvim_lua" },
})

local function confirm_or_fallback(fallback)
  if cmp.visible() then
    cmp.confirm {
      behavior = cmp.ConfirmBehavior.Insert,
      select = true,
    }
  elseif require("luasnip").expand_or_jumpable() then
    require("luasnip").expand_or_jump()
  else
    fallback()
  end
end

local function confirm_or_jump_back(fallback)
  if cmp.visible() then
    cmp.confirm {
      behavior = cmp.ConfirmBehavior.Insert,
      select = true,
    }
  elseif require("luasnip").jumpable(-1) then
    require("luasnip").jump(-1)
  else
    fallback()
  end
end

opts.mapping["<Up>"] = cmp.mapping.select_prev_item()
opts.mapping["<Down>"] = cmp.mapping.select_next_item()
opts.mapping["<Tab>"] = cmp.mapping(confirm_or_fallback, { "i", "s" })
opts.mapping["<S-Tab>"] = cmp.mapping(confirm_or_jump_back, { "i", "s" })

return opts
