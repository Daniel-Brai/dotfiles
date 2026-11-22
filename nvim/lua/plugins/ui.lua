return {
	{
		"goolord/alpha-nvim",
		config = function()
			local alpha = require("alpha")
			local dashboard = require("alpha.themes.dashboard")

			dashboard.section.header.val = {
				[[                                                                       ]],
				[[  ██████   █████                   █████   █████  ███                  ]],
				[[ ░░██████ ░░███                   ░░███   ░░███  ░░░                   ]],
				[[  ░███░███ ░███   ██████   ██████  ░███    ░███  ████  █████████████   ]],
				[[  ░███░░███░███  ███░░███ ███░░███ ░███    ░███ ░░███ ░░███░░███░░███  ]],
				[[  ░███ ░░██████ ░███████ ░███ ░███ ░░███   ███   ░███  ░███ ░███ ░███  ]],
				[[  ░███  ░░█████ ░███░░░  ░███ ░███  ░░░█████░    ░███  ░███ ░███ ░███  ]],
				[[  █████  ░░█████░░██████ ░░██████     ░░███      █████ █████░███ █████ ]],
				[[ ░░░░░    ░░░░░  ░░░░░░   ░░░░░░       ░░░      ░░░░░ ░░░░░ ░░░ ░░░░░  ]],
				[[                                                                       ]],
			}

			dashboard.section.buttons.val = {
				dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
				dashboard.button("r", "  Recent files", ":Telescope oldfiles<CR>"),
				dashboard.button("f", "󰈞  Find files", ":Telescope find_files<CR>"),
				dashboard.button("g", "󱎸  Live grep", ":Telescope live_grep<CR>"),
				dashboard.button("q", "󰅚  Quit NVIM", ":qa<CR>"),
			}

			alpha.setup(dashboard.opts)
		end,
	},
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("tokyonight").setup({
				style = "moon",
				transparent = true,
				styles = {
					comments = { italic = false },
					sidebars = "transparent",
					floats = "transparent",
				},
			})

			vim.cmd.colorscheme("tokyonight-moon")
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local mode = {
				"mode",
				fmt = function(str)
					return " " .. str
				end,
			}

			local filename = {
				"filename",
				file_status = true,
				path = 0,
			}

			local hide_in_width = function()
				return vim.fn.winwidth(0) > 100
			end

			local diff = {
				"diff",
				colored = false,
				symbols = { added = " ", modified = " ", removed = " " },
				cond = hide_in_width,
			}

			local diagnostics = {
				"diagnostics",
				sources = { "nvim_diagnostic" },
				sections = { "error", "warn" },
				colored = false,
				symbols = { error = " ", warn = " ", info = " ", hint = " " },
				update_in_insert = false,
				always_visible = false,
				cond = hide_in_width,
			}

			local lsp = {
				function()
					local clients = vim.lsp.get_clients({ bufnr = 0 })
					if #clients == 0 then
						return "No LSP"
					end
					return " " .. clients[1].name
				end,
				colored = true,
				color = { fg = "#98c379" },
				cond = hide_in_width,
			}

			local lines_from_edges = {
				function()
					local current = vim.fn.line(".")
					local total = vim.fn.line("$")
					return "↑" .. (current - 1) .. " ↓" .. (total - current)
				end,
			}

			require("lualine").setup({
				options = {
					icons_enabled = true,
					section_separators = { left = "", right = "" },
					component_separators = { left = "", right = "" },
					always_divide_middle = true,
					disabled_filetypes = { "alpha", "neo-tree" },
				},
				sections = {
					lualine_a = { mode },
					lualine_b = { "branch" },
					lualine_c = { filename },
					lualine_x = {
						diagnostics,
						diff,
						lsp,
						{
							function()
								return require("core.cc").statusline()
							end,
							cond = function()
								return vim.bo.filetype == "c" or vim.bo.filetype == "cpp"
							end,
						},
						{ "encoding", cond = hide_in_width },
						{ "filetype", cond = hide_in_width },
					},
					lualine_y = { lines_from_edges, "location" },
					lualine_z = { "progress" },
				},
				inactive_sections = {
					lualine_a = {},
					lualine_b = {},
					lualine_c = { { "filename", path = 0 } },
					lualine_x = { { "location", padding = 0 } },
					lualine_y = {},
					lualine_z = {},
				},
				-- extensions = {'fugitive'}
			})
		end,
	},
	{
		"nvim-neo-tree/neo-tree.nvim",
		version = "*",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
		lazy = false,
		keys = {
			{ "\\", ":Neotree reveal<CR>", desc = "NeoTree reveal", silent = true },
		},
		opts = {
			filesystem = {
				-- Pick up files created or deleted outside Neovim, e.g. from a terminal split
				use_libuv_file_watcher = true,
				filtered_items = {
					visible = true,
					hide_dotfiles = false,
					hide_gitignored = false,
				},
				window = {
					mappings = {
						["\\"] = "close_window",
					},
				},
			},
		},
	},
	{
		"akinsho/bufferline.nvim",
		version = "*",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"moll/vim-bbye",
		},
		config = function()
			require("bufferline").setup({
				options = {
					mode = "buffers",
					themable = true,
					numbers = "none",
					close_command = "Bdelete! %d",
					path_components = 1,
				},
			})
		end,
	},
}
