return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = true, lsp_format = "fallback" })
			end,
			mode = "",
			desc = "[F]ormat buffer",
		},
	},
	opts = {
		notify_on_error = false,
		format_on_save = function(bufnr)
			-- Disable "format_on_save lsp_fallback" for languages that don't
			-- have a well standardized coding style. You can add additional
			-- languages here or re-enable it for the disabled ones.
			-- tla: tlafmt rewrites hand-aligned specs, and auto-save writes while typing,
			-- so TLA+ only formats on <leader>f
			local disable_filetypes = { tla = true }
			if disable_filetypes[vim.bo[bufnr].filetype] then
				return nil
			else
				return {
					timeout_ms = 500,
					lsp_format = "fallback",
				}
			end
		end,
		formatters_by_ft = {
			lua = { "stylua" },
			go = { "goimports", "gomodifytags" },
			-- Conform can also run multiple formatters sequentially
			-- python = { "isort", "black" },
			python = { "ruff", "black", "isort" },
			c = { "clang-format" },
			cpp = { "clang-format" },
			cmake = { "gersemi" },
			yaml = { "yamlfmt" },
			ruby = { "erb_formatter", "rubocop", "rufo" },
			heex = { "mix" },
			tla = { "tlafmt" },
			--
			-- You can use 'stop_after_first' to run the first available formatter from the list
			javascript = { "prettierd", "prettier", stop_after_first = true },
			typescript = { "prettierd", "prettier", stop_after_first = true },
		},
		formatters = {
			erb_formatter = {
				command = "bundle",
				args = { "exec", "erb-format", "--stdin" },
			},
			-- Uses the project's .clang-format when there is one, this style otherwise
			["clang-format"] = {
				prepend_args = {
					"--style=file",
					"--fallback-style={BasedOnStyle: LLVM, IndentWidth: 4, ColumnLimit: 100, AllowShortFunctionsOnASingleLine: Empty, PointerAlignment: Left}",
				},
			},
			mix = {
				command = "mix",
				args = { "format" },
			},
			-- cargo install tlafmt
			tlafmt = {
				command = "tlafmt",
				args = { "--stdin" },
			},
		},
	},
}
