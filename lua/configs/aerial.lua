return {
  backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },
  disable_max_lines = 50000,

  layout = {
    width = 30,
    min_width = 30,
    max_width = 30,
    placement = "edge",
    default_direction = "right",
    resize_to_content = false,
    preserve_equality = false,
  },

  attach_mode = "window",
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
