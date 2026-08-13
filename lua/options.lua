require "nvchad.options"

-- add yours here!
local opt = vim.opt
opt.encoding = "utf-8"
opt.fileencodings = { "utf-8", "gbk", "gb2312", "gb18030", "ucs-bom", "cp936" }
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.shiftround = true
opt.shiftwidth = 4
opt.autoindent = true
opt.smartindent = true

opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.selection = "exclusive"
opt.showtabline = 2
opt.equalalways = false
opt.winminwidth = 10

opt.scrolloff = 8
-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!

opt.foldmethod = "manual"
opt.foldexpr = "0"
opt.foldlevel = 99
opt.foldenable = true
opt.foldlevelstart = 99

-- Keep sessions portable across differently-sized terminal windows.
opt.sessionoptions = "blank,buffers,curdir,globals,help,tabpages"
