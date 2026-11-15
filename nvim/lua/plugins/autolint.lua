return { -- Linting
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")
		lint.linters_by_ft = {
			markdown = { "markdownlint" },
			python = { "ruff" },
			ruby = { "ruby" },
			haskell = { "hlint" },
			go = { "staticcheck" },
			tla = { "sany" },
		}

		-- SANY, the TLA+ parser (lua/tlaplus/sany.lua)
		lint.linters.sany = require("tlaplus.sany")

		-- staticcheck reports some issues (e.g. U1000) with an empty end position,
		-- which the parser turns into end_lnum = -1 and Neovim rejects.
		local staticcheck_parse = lint.linters.staticcheck.parser
		lint.linters.staticcheck.parser = function(output, bufnr, cwd)
			local diagnostics = staticcheck_parse(output, bufnr, cwd)
			for _, d in ipairs(diagnostics) do
				if d.end_lnum < 0 then
					d.end_lnum, d.end_col = d.lnum, d.col
				end
			end
			return diagnostics
		end

		-- To allow other plugins to add linters to require('lint').linters_by_ft,
		-- instead set linters_by_ft like this:
		-- lint.linters_by_ft = lint.linters_by_ft or {}
		-- lint.linters_by_ft['markdown'] = { 'markdownlint' }
		--
		-- However, note that this will enable a set of default linters,
		-- which will cause errors unless these tools are available:
		-- {
		--   clojure = { "clj-kondo" },
		--   dockerfile = { "hadolint" },
		--   inko = { "inko" },
		--   janet = { "janet" },
		--   json = { "jsonlint" },
		--   markdown = { "vale" },
		--   rst = { "vale" },
		--   terraform = { "tflint" },
		--   text = { "vale" }
		-- }
		--
		-- You can disable the default linters by setting their filetypes to nil:
		-- lint.linters_by_ft['clojure'] = nil
		-- lint.linters_by_ft['dockerfile'] = nil
		-- lint.linters_by_ft['inko'] = nil
		-- lint.linters_by_ft['janet'] = nil
		-- lint.linters_by_ft['json'] = nil
		-- lint.linters_by_ft['markdown'] = nil
		-- lint.linters_by_ft['rst'] = nil
		-- lint.linters_by_ft['ruby'] = nil
		-- lint.linters_by_ft['terraform'] = nil
		-- lint.linters_by_ft['text'] = nil

		-- Create autocommand which carries out the actual linting
		-- on the specified events.
		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				-- Only run the linter in buffers that you can modify in order to
				-- avoid superfluous noise, notably within the handy LSP pop-ups that
				-- describe the hovered symbol using Markdown.
				if vim.bo.modifiable then
					local ok, names = pcall(function()
						return lint._resolve_linter_by_ft(vim.bo.filetype)
					end)
					if not ok then
						return
					end
					-- Skip linters whose executable is not installed.
					names = vim.tbl_filter(function(n)
						local l = lint.linters[n]
						return l and vim.fn.executable(type(l) == "function" and l().cmd or l.cmd) == 1
					end, names or {})
					if #names > 0 then
						lint.try_lint(names)
					end
				end
			end,
		})
	end,
}
