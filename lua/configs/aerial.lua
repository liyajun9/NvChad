local function shorten_cpp_qualified_name(name)
  if type(name) ~= "string" or not name:find("::", 1, true) then
    return name
  end

  local tail = name:match("([^:]+)$")
  if not tail or tail == "" then
    return name
  end

  return "::" .. tail
end

local function should_shorten_symbol(bufnr, item)
  local ft = vim.bo[bufnr].filetype
  if ft ~= "c" and ft ~= "cpp" then
    return false
  end

  return item.kind == "Function" or item.kind == "Method" or item.kind == "Constructor" or item.kind == "Field"
end

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

  post_parse_symbol = function(bufnr, item)
    if should_shorten_symbol(bufnr, item) then
      item.name = shorten_cpp_qualified_name(item.name)
    end

    return true
  end,
}
