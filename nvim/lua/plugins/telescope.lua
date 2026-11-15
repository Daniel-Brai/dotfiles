return {
	"nvim-telescope/telescope.nvim",
	event = "VimEnter",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
			cond = function()
				return vim.fn.executable("make") == 1
			end,
		},
		{ "nvim-telescope/telescope-ui-select.nvim" },

		{ "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
	},
	config = function()
		require("telescope").setup({
			-- defaults = {
			--   mappings = {
			--     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
			--   },
			-- },
			pickers = {
				find_files = {
					file_ignore_patterns = { "node_modules", ".git", ".venv" },
					hidden = true,
				},
			},
			live_grap = {
				file_ignore_patterns = { "node_modules", ".git", ".venv" },
				additional_args = function(_)
					return { "--hidden" }
				end,
			},
			extensions = {
				["ui-select"] = {
					require("telescope.themes").get_dropdown(),
				},
			},
		})

		pcall(require("telescope").load_extension, "fzf")
		pcall(require("telescope").load_extension, "ui-select")

		local builtin = require("telescope.builtin")
		local keymap = require("core.functions").keymap

		keymap("<leader>sh", builtin.help_tags, "n", { desc = "[S]earch [H]elp" })
		keymap("<leader>sk", builtin.keymaps, "n", { desc = "[S]earch [K]eymaps" })
		keymap("<leader>sf", builtin.find_files, "n", { desc = "[S]earch [F]iles" })
		keymap("<leader>ss", builtin.builtin, "n", { desc = "[S]earch [S]elect Telescope" })
		keymap("<leader>sw", builtin.grep_string, "n", { desc = "[S]earch current [W]ord" })
		keymap("<leader>sg", builtin.live_grep, "n", { desc = "[S]earch by [G]rep" })
		keymap("<leader>sd", builtin.diagnostics, "n", { desc = "[S]earch [D]iagnostics" })
		keymap("<leader>sr", builtin.resume, "n", { desc = "[S]earch [R]esume" })
		keymap("<leader>s.", builtin.oldfiles, "n", { desc = '[S]earch Recent Files ("." for repeat)' })
		keymap("<leader><leader>", builtin.buffers, "n", { desc = "[ ] Find existing buffers" })

		keymap("<leader>/", function()
			builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
				winblend = 10,
				previewer = false,
			}))
		end, "n", { desc = "[/] Fuzzily search in current buffer" })

		keymap("<leader>s/", function()
			builtin.live_grep({
				grep_open_files = true,
				prompt_title = "Live Grep in Open Files",
			})
		end, "n", { desc = "[S]earch [/] in Open Files" })

		keymap("<leader>sn", function()
			builtin.find_files({ cwd = vim.fn.stdpath("config") })
		end, "n", { desc = "[S]earch [N]eovim files" })
	end,
}
