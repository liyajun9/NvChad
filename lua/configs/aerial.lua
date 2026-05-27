return {
  backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },
  disable_max_lines = 50000,

  layout = {
    min_width = 28,
    max_width = 40,
    placement = "edge",
    default_direction = "right",
  },

  attach_mode = "global",
  close_on_select = false,

  show_guides = true,
  guides = {
    mid_item = "├ ",
    last_item = "└ ",
    nested_top = "│ ",
    whitespace = "  ",
  },

  filter_kind = false,
}
