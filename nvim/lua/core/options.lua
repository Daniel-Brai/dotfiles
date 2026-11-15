vim.g.have_nerd_font = true -- For proper display for nerd font

vim.o.number = true -- Show line number
vim.o.relativenumber = true -- Relative Display of line numbers
vim.o.wrap = true -- line wrapping
vim.o.linebreak = true -- Don't split words
vim.o.mouse = "a" -- Enable mouse mode
vim.o.showmode = false -- Disable the show mode of Nvim
vim.o.breakindent = true -- Enable break indent
vim.o.showtabline = 2 -- Show tab lines always
vim.o.shiftwidth = 4 -- The number of spaces for each indent
vim.o.tabstop = 4 -- Replace 4 spaces for a tab
vim.o.scrolloff = 10 -- Minimize screen line to 4
vim.o.expandtab = true -- Convert tabs to spaces
vim.o.undofile = true -- Save undo history
vim.o.ignorecase = true -- Case-insensitive searching
vim.o.smartcase = true
vim.o.signcolumn = "yes" -- Keep signcolumn on by default
vim.o.updatetime = 250 -- Decrease update time
vim.o.timeoutlen = 300 -- Decrease mapped sequence wait time
vim.o.splitright = true -- Configure how new splits should be opened
vim.o.splitbelow = true
vim.o.backspace = "indent,eol,start" -- Allow backspace on

-- Use omni completion fallback for path/buffer sources
-- vim.opt.completeopt = { "menuone", "noselect", "popup" }

vim.o.list = false -- Character Display Options
vim.o.inccommand = "split" -- Preview substitutions live, as you type!
vim.o.cursorline = true -- Show which line your cursor is on
vim.o.confirm = true -- Show dialog when an operation fails in a buffer
-- vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.listchars = { trail = "·", nbsp = "␣" }
vim.opt.listchars:append({
	leadmultispace = "│   ",
	space = "·",
	-- eol = "↴",
})
vim.opt.termguicolors = true -- Enable termguicolors for highlighting

-- Sync clipboard between OS and Neovim.
vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)

-- vim.tbl_flatten is deprecated in 0.12 and tla.nvim still calls it, which
-- prints a warning on every TLC run. Same behaviour, no warning.
vim.tbl_flatten = function(t)
	local result = {}
	local function flatten(tbl)
		for _, v in ipairs(tbl) do
			if type(v) == "table" then
				flatten(v)
			else
				table.insert(result, v)
			end
		end
	end
	flatten(t)
	return result
end
