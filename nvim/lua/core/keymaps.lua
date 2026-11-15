local functions = require("core.functions")

-- Set space character as our leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opts = { noremap = true, silent = true }

-- Disable space key default behaviour
functions.keymap("<Space>", "<Nop>", { "n", "v" }, { silent = true })

-- Save file in current buffer
functions.keymap("<C-s>", "<cmd> w <CR>", "n", functions.merge(opts, { desc = "[S]ave Current File" }))

-- Save file in current buffer with formatting
functions.keymap(
	"<leader>sn",
	"<cmd>noautocmd w <CR>",
	"n",
	functions.merge(opts, { desc = "Save Current File (No Formatting)" })
)

functions.keymap("<leader>rv", function()
	for name, _ in pairs(package.loaded) do
		if name:match("^plugins") or name:match("^config") then
			package.loaded[name] = nil
		end
	end
	dofile(vim.env.MYVIMRC)
	vim.notify("Config reloaded!", vim.log.levels.INFO)
end, "n", { desc = "Reload config" })

-- Quit file
functions.keymap("<C-q>", "<cmd> q <CR>", "n", functions.merge(opts, { desc = "[Q]uit File" }))

-- Delete a character without copy
functions.keymap("x", '"_x', "n", opts)

-- haractes
functions.keymap("<leader>li", ":set list!<CR>", "n", { desc = "Toggle invisible characters" })

-- Terminal
functions.keymap("<leader>th", ":split | terminal<CR>", "n", { desc = "Open terminal below" })
functions.keymap("<leader>tv", ":vsplit | terminal<CR>", "n", { desc = "Open terminal right" })
functions.keymap("<leader>tc", "<C-\\><C-n>:bd!<CR>", "t", { desc = "Close terminal" })
functions.keymap("<Esc><Esc>", "<C-\\><C-n>", "t", { desc = "Exit terminal mode" })
functions.keymap("<C-h>", "<C-\\><C-n><cmd>TmuxNavigateLeft<CR>", "t", functions.merge(opts, { desc = "Go to Left Split" }))
functions.keymap("<C-j>", "<C-\\><C-n><cmd>TmuxNavigateDown<CR>", "t", functions.merge(opts, { desc = "Go to Bottom Split" }))
functions.keymap("<C-k>", "<C-\\><C-n><cmd>TmuxNavigateUp<CR>", "t", functions.merge(opts, { desc = "Go to Top Split" }))
functions.keymap("<C-l>", "<C-\\><C-n><cmd>TmuxNavigateRight<CR>", "t", functions.merge(opts, { desc = "Go to Right Split" }))

-- Start typing straight away in terminals, both new ones and ones you move back into
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter" }, {
	pattern = "term://*",
	command = "startinsert",
})

-- Vertical scroll and center
functions.keymap("<C-d>", "<C-d>zz", "n", opts)
functions.keymap("<C-u>", "<C-u>zz", "n", opts)

-- Resize split via arrows
functions.keymap("<C-Up>", ":resize -2<CR>", "n", opts)
functions.keymap("<C-Down>", ":resize +2<CR>", "n", opts)
functions.keymap("<C-Left>", ":vertical resize -2<CR>", "n", opts)
functions.keymap("<C-Right>", ":vertical resize +2<CR>", "n", opts)

-- Window Management
functions.keymap("<leader>v", "<C-w>v", "n", functions.merge(opts, { desc = "Split window vertically" }))
functions.keymap("<leader>h", "<C-w>s", "n", functions.merge(opts, { desc = "Split window horizontally" }))
functions.keymap("<leader>se", "<C-w>=", "n", functions.merge(opts, { desc = "Increase current split width" }))
functions.keymap("<leader>xs", ":close <CR>", "n", functions.merge(opts, { desc = "Close split" }))

-- Navigate between splits, falling through to tmux panes at the edges
functions.keymap("<C-k>", "<cmd>TmuxNavigateUp<CR>", "n", functions.merge(opts, { desc = "Go to Top Split" }))
functions.keymap("<C-j>", "<cmd>TmuxNavigateDown<CR>", "n", functions.merge(opts, { desc = "Go to Bottom Split" }))
functions.keymap("<C-h>", "<cmd>TmuxNavigateLeft<CR>", "n", functions.merge(opts, { desc = "Go to Left Split" }))
functions.keymap("<C-l>", "<cmd>TmuxNavigateRight<CR>", "n", functions.merge(opts, { desc = "Go to Right Split" }))

-- Buffers
functions.keymap("<leader>bo", "<cmd> :enew <CR>", "n", functions.merge(opts, { desc = "[O]pen new [B]uffer" }))
functions.keymap("<leader>be", ":Bdelete!<CR>", "n", functions.merge(opts, { desc = "[E]xit [B]uffer" }))
functions.keymap("<leader>bn", ":bnext<CR>", "n", functions.merge(opts, { desc = "[N]ext [B]uffer" }))
functions.keymap("<leader>bp", ":bprev<CR>", "n", functions.merge(opts, { desc = "[P]revious [B]uffer" }))

-- Tabs
functions.keymap("<leader>to", ":tabnew<CR>", "n", functions.merge(opts, { desc = "[O]pen new [T]ab" }))
functions.keymap("<leader>tx", ":tabclose<CR>", "n", functions.merge(opts, { desc = "[C]lose [T]ab" }))
functions.keymap("<leader>tn", ":tabn<CR>", "n", functions.merge(opts, { desc = "Go To [N]ext [T]ab" }))
functions.keymap("<leader>tp", ":tabp<CR>", "n", functions.merge(opts, { desc = "Go To [P]revious [T]ab" }))

-- Toggle line wrapping
functions.keymap("<leader>lw", "<cmd>set wrap!<CR>", "n", functions.merge(opts, { desc = "Toggle [L]ine [W]rap" }))

-- Stay in indent mode
functions.keymap("<", "<gv", "v", opts)
functions.keymap(">", ">gv", "v", opts)

-- Clear Highlight on search
functions.keymap("<Esc>", "<cmd>nohlsearch<CR>")

-- Keep last yanked when pasting
functions.keymap("p", '"_dP', "v", opts)

-- In your `plugins/lsp.lua` file, inside the `LspAttach` callback

-- Diagnostics
functions.keymap("[d", function()
	vim.diagnostic.goto_prev({ float = true })
end, "n", { desc = "Go To Previous [D]iagnostics" })

functions.keymap("]d", function()
	vim.diagnostic.goto_next({ float = true })
end, "n", { desc = "Go To Next [D]iagnostics" })

-- Diagnostic floating window
functions.keymap("<leader>dp", vim.diagnostic.open_float, "n", { desc = "Open Floating [D]iagnostics" })

-- Diagnostic list (quickfix or location list)
functions.keymap("<leader>dn", function()
	vim.diagnostic.setqflist() -- or setloclist()
end, "n", { desc = "Open Diagnostic [Q]uickfix List" })

-- Optional: <CR> confirms selection without inserting a newline
-- functions.keymap("<CR>", function()
-- 	if vim.fn.pumvisible() == 1 then
-- 		return "<C-y>"
-- 	end
-- 	return "<CR>"
-- end, "i", { expr = true, noremap = true })
--
-- -- Navigate completion menu
-- functions.keymap("<C-n>", function()
-- 	if vim.fn.pumvisible() == 1 then
-- 		return "<C-n>"
-- 	end
-- 	return "<C-x><C-o>"
-- end, "i", { expr = true, noremap = true })
--
-- functions.keymap("<C-p>", "<C-p>", "i", { noremap = true })
-- functions.keymap("<C-Space>", "<C-x><C-o>", "i", { noremap = true, desc = "Trigger completion" })
