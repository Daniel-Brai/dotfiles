return {
	{
		"numToStr/Comment.nvim",
		config = function()
			local comment_ft = require("Comment.ft")
			require("Comment").setup({
				-- Comment.nvim expects get_parser to throw when a buffer has no treesitter
				-- parser; on Neovim 0.12 it returns nil and gcc fails with "[Comment.nvim] nil"
				-- (TLC .cfg files, plain text ...). Answer for those buffers here instead:
				-- the plugin's table first, then the buffer's 'commentstring' for line comments
				pre_hook = function(ctx)
					if vim.treesitter.get_parser(0, nil, { error = false }) then
						return nil
					end
					local cstr = comment_ft.get(vim.bo.filetype, ctx.ctype)
					if cstr then
						return cstr
					end
					if ctx.ctype == require("Comment.utils").ctype.linewise then
						return vim.bo.commentstring
					end
				end,
			})
			-- TLA+: gcc / gc comment with \* (line), gbc / gb with (* *) (block).
			-- Registered under both names because Comment.nvim looks the language up
			-- by treesitter parser first ("tlaplus") and by filetype second ("tla")
			local tla_comments = { "\\*%s", "(*%s*)" }
			require("Comment.ft").set("tla", tla_comments).set("tlaplus", tla_comments)
		end,
	},
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		lazy = true,
		opts = {},
	},
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
		},
	},
	{
		"NeogitOrg/neogit",
		lazy = true,
		dependencies = {
			"sindrets/diffview.nvim",
			"m00qek/baleia.nvim",
			"nvim-telescope/telescope.nvim",
		},
		cmd = "Neogit",
		opts = {},
		-- Space + your zsh git alias runs the same command (gs, ga, gac, gph...)
		keys = function()
			-- Like require("neogit").action, but runs the action inside Neogit's async
			-- context (the built-in one crashes on commit)
			local function action(popup, name)
				return function()
					local a = require("neogit.lib.async")
					local fn = require("neogit.popups." .. popup .. ".actions")[name]
					local fake_popup = {
						close = function() end,
						state = { env = {} },
						get_arguments = function() return {} end,
						get_internal_arguments = function() return {} end,
					}
					a.void(function()
						require("neogit.lib.git").repo:dispatch_refresh({
							source = "action",
							callback = a.void(function() fn(fake_popup) end),
						})
					end)()
				end
			end
			local function popup(name)
				return function()
					require("neogit").open({ name })
				end
			end
			local function repo_dir()
				local dir = vim.fn.expand("%:p:h")
				return vim.fn.isdirectory(dir) == 1 and dir or vim.fn.getcwd()
			end
			local function git(args)
				local title = "git " .. table.concat(args, " ")
				vim.system(vim.list_extend({ "git" }, args), { cwd = repo_dir(), text = true }, function(out)
					local msg = vim.trim((out.stdout or "") .. "\n" .. (out.stderr or ""))
					vim.schedule(function()
						local level = out.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
						vim.notify(msg ~= "" and msg or "done", level, { title = title })
					end)
				end)
			end
			local function run(...)
				local args = { ... }
				return function()
					git(args)
				end
			end
			return {
				{ "<leader>gn", "<cmd>Neogit<cr>", desc = "Show Neogit UI" },
				{ "<leader>gs", "<cmd>Neogit<cr>", desc = "git status" },
				{ "<leader>ga", function() git({ "add", vim.fn.expand("%:p") }) end, desc = "git add (this file)" },
				{
					"<leader>gac",
					function()
						vim.system({ "git", "add", "." }, { cwd = repo_dir() }):wait()
						action("commit", "commit")()
					end,
					desc = "git add . && git commit",
				},
				{ "<leader>gb", popup("branch"), desc = "git branch" },
				{ "<leader>gbd", action("branch", "delete_branch"), desc = "git branch -D" },
				{ "<leader>gch", action("branch", "checkout_branch_revision"), desc = "git checkout" },
				{ "<leader>gsw", action("branch", "checkout_local_branch"), desc = "git switch" },
				{ "<leader>gfo", run("fetch", "origin"), desc = "git fetch origin" },
				{ "<leader>gpl", run("pull", "origin"), desc = "git pull origin" },
				{ "<leader>gph", run("push", "-u", "origin", "HEAD"), desc = "git push -u origin" },
				{ "<leader>glog", action("log", "log_current"), desc = "git log" },
				{ "<leader>grlog", action("log", "reflog_current"), desc = "git reflog" },
				{ "<leader>grs", run("remote", "show", "origin"), desc = "git remote show origin" },
			}
		end,
	},
	{
		"NMAC427/guess-indent.nvim",
	},
	{
		-- Ctrl+h/j/k/l mappings live in core/keymaps.lua
		"christoomey/vim-tmux-navigator",
		lazy = false,
		init = function()
			vim.g.tmux_navigator_no_mappings = 1
		end,
	},
	{
		"Pocco81/auto-save.nvim",
		config = function()
			require("auto-save").setup({})
		end,
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		opts = {
			indent = {
				char = "▏", -- or "│", "╎"
			},
			scope = {
				show_start = false,
				show_end = false,
				show_exact_scope = false,
			},
			exclude = {
				filetypes = {
					"help",
					"startify",
					"dashboard",
					"Trouble",
					"NeoTree",
				},
			},
		},
	},
	{
		"folke/which-key.nvim",
		event = "VimEnter", -- Sets the loading event to 'VimEnter'
		opts = {
			-- delay between pressing a key and opening which-key (milliseconds)
			-- this setting is independent of vim.o.timeoutlen
			delay = 0,
			icons = {
				-- set icon mappings to true if you have a Nerd Font
				mappings = vim.g.have_nerd_font,
				-- If you are using a Nerd Font: set icons.keys to an empty table which will use the
				-- default which-key.nvim defined Nerd Font icons, otherwise define a string table
				keys = vim.g.have_nerd_font and {} or {
					Up = "<Up> ",
					Down = "<Down> ",
					Left = "<Left> ",
					Right = "<Right> ",
					C = "<C-…> ",
					M = "<M-…> ",
					D = "<D-…> ",
					S = "<S-…> ",
					CR = "<CR> ",
					Esc = "<Esc> ",
					ScrollWheelDown = "<ScrollWheelDown> ",
					ScrollWheelUp = "<ScrollWheelUp> ",
					NL = "<NL> ",
					BS = "<BS> ",
					Space = "<Space> ",
					Tab = "<Tab> ",
					F1 = "<F1>",
					F2 = "<F2>",
					F3 = "<F3>",
					F4 = "<F4>",
					F5 = "<F5>",
					F6 = "<F6>",
					F7 = "<F7>",
					F8 = "<F8>",
					F9 = "<F9>",
					F10 = "<F10>",
					F11 = "<F11>",
					F12 = "<F12>",
				},
			},

			-- Document existing key chains
			spec = {
				{ "<leader>s", group = "[S]earch" },
				{ "<leader>t", group = "[T]oggle" },
				{ "<leader>c", group = "[C]/C++" },
				{ "<leader>g", group = "[G]it (zsh aliases)" },
				{ "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
				{ "<leader>d", group = "[D]ebug / diagnostics" },
			},
		},
	},
	{
		-- Opening an image or PDF shows it rendered instead of binary.
		-- Needs a kitty-graphics terminal (Ghostty), ImageMagick, and Ghostscript for PDFs.
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			image = { enabled = true },
		},
	},
}
