-- TLA+ setup, called from lua/plugins/tla.lua. init() runs at startup (devicons,
-- autocmds and commands that must exist before the first .tla opens); config()
-- runs when tlaplus-nvim-plugin loads for the first .tla buffer

local symbols = require("tlaplus.symbols")
local keep_number_sets_ascii = symbols.keep_number_sets_ascii
local tla_cheat_sheet = symbols.tla_cheat_sheet
local tla_cmp_source = symbols.tla_cmp_source
local tla_output_symbols = symbols.tla_output_symbols
local completion = require("tlaplus.completion")
local tla_words_source = completion.tla_words_source
local tla_names_source = completion.tla_names_source
local tla_known_name = completion.tla_known_name
local cfg = require("tlaplus.cfg")
local tla_cfg_spec_file = cfg.tla_cfg_spec_file
local tla_cfg_source = cfg.tla_cfg_source
local tla_cfg_check = cfg.tla_cfg_check
local tla_create_cfg = cfg.tla_create_cfg
local tla_watch_new_spec = cfg.tla_watch_new_spec
local tla_map_navigation = require("tlaplus.navigation").tla_map_navigation
local pdf = require("tlaplus.pdf")
local tla_pdf = pdf.tla_pdf
local tla_tex = pdf.tla_tex
local tla_typeset = pdf.tla_typeset
local tla_pdf_live = pdf.tla_pdf_live
local tla_add_snippets = require("tlaplus.snippets").tla_add_snippets
local check = require("tlaplus.check")
local box = require("tlaplus.box")

local cfg_registered = false

local M = {}

function M.init()
	-- TLA+ has no official logo and no Nerd Font glyph, so .tla files get ∀ in
	-- Neo-tree, the tab bar and Telescope. Runs before anything else sets up devicons
	require("nvim-web-devicons").setup({
		override_by_extension = {
			tla = { icon = "∀", color = "#7aa2f7", cterm_color = "111", name = "TlaPlus" },
		},
	})
	require("nvim-web-devicons").set_icon_by_filetype({ tla = "tla" })
	vim.g.tlaplus_mappings_enable = true
	-- gcc / gc comment mappings for TLA+ live in plugins/misc.lua (Comment.nvim)
	-- and after/ftplugin/tla.lua (commentstring)
	-- tla.nvim names its TLC output buffer "<spec>.tla " and re-sets filetype=help
	-- (which reloads syntax) on every run
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "help",
		callback = function(args)
			if vim.api.nvim_buf_get_name(args.buf):match("%.tla $") then
				tla_output_symbols(args.buf)
				vim.api.nvim_create_autocmd("BufWinEnter", {
					group = vim.api.nvim_create_augroup("TlaOutputSymbols" .. args.buf, { clear = true }),
					buffer = args.buf,
					callback = function()
						tla_output_symbols(args.buf)
					end,
				})
			end
		end,
	})
	-- Show existing ASCII operators as symbols (after/queries/tlaplus/highlights.scm);
	-- the cursor line stays ASCII so it can be edited
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "tla",
		callback = function(args)
			vim.opt_local.conceallevel = vim.g.tlaplus_mappings_enable and 2 or 0
			tla_map_navigation(args.buf)
			-- Buffer-local, so it wins over tla.nvim's global :TlaCheck
			check.commands(args.buf, "Model check this spec with TLC")
			box.map(args.buf)
			-- After the plugin has added its mappings for this buffer
			vim.schedule(function()
				keep_number_sets_ascii(args.buf)
			end)
		end,
	})

	-- :TlaSymbolsToggle switches every TLA+ buffer between symbols (display and
	-- typing) and plain ASCII
	vim.api.nvim_create_user_command("TlaSymbolsToggle", function()
		local on = not vim.g.tlaplus_mappings_enable
		vim.g.tlaplus_mappings_enable = on
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].filetype == "tla" then
				vim.wo[win].conceallevel = on and 2 or 0
			end
		end
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.bo[buf].filetype == "tla" then
				vim.api.nvim_buf_call(buf, function()
					vim.cmd(on and "TlaMappingsAdd" or "TlaMappingsRemove")
				end)
				keep_number_sets_ascii(buf)
			end
		end
		vim.notify("TLA+ " .. (on and "symbols" or "ASCII"))
	end, { desc = "Toggle TLA+ Unicode symbols and plain ASCII" })

	vim.api.nvim_create_user_command("TlaCheatSheet", tla_cheat_sheet, { desc = "Show TLA+ ASCII and Unicode symbols" })

	-- TLC .cfg files get keyword and spec-name completion. Set up from init because
	-- this plugin only loads for .tla buffers
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "cfg",
		callback = function(args)
			if not tla_cfg_spec_file(args.buf) then
				return
			end
			tla_cfg_check(args.buf)
			tla_map_navigation(args.buf)
			-- :TlaCheck from the .cfg checks its spec with this .cfg
			check.commands(args.buf, "Model check the spec with this .cfg")
			box.map(args.buf)
			-- TLC configs comment like TLA+, not with #
			vim.bo[args.buf].commentstring = "\\* %s"
			vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "InsertLeave", "BufWritePost" }, {
				buffer = args.buf,
				callback = function()
					tla_cfg_check(args.buf)
				end,
			})
			local cmp = require("cmp")
			if not cfg_registered then
				cmp.register_source("tla_cfg", tla_cfg_source)
				cmp.setup.filetype("cfg", {
					sources = cmp.config.sources({ { name = "tla_cfg" }, { name = "buffer" } }),
				})
				cfg_registered = true
			end
		end,
	})

	-- New specs get a Name.cfg once they're saved looking like a spec
	vim.api.nvim_create_autocmd("BufNewFile", {
		pattern = "*.tla",
		callback = function(args)
			tla_watch_new_spec(args.buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufReadPost", {
		pattern = "*.tla",
		callback = function(args)
			local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(args.buf))
			if stat and stat.size == 0 then
				tla_watch_new_spec(args.buf)
			end
		end,
	})
	-- :TlaCfg opens this spec's .cfg beside it, creating it first if needed
	vim.api.nvim_create_user_command("TlaCfg", function()
		local spec = vim.api.nvim_buf_get_name(0)
		if not spec:match("%.tla$") then
			return vim.notify("Not a .tla file", vim.log.levels.WARN, { title = "TLA+" })
		end
		if vim.bo.modified then
			vim.cmd("write")
		end
		local cfg_path = tla_create_cfg(spec)
		vim.cmd("vsplit " .. vim.fn.fnameescape(cfg_path))
	end, { desc = "Open this spec's TLC .cfg, creating it if needed" })

	vim.api.nvim_create_user_command("TlaPdf", tla_pdf, { desc = "Typeset this spec as a PDF and open it" })
	vim.api.nvim_create_user_command("TlaTex", tla_tex, { desc = "Typeset this spec and open the LaTeX" })
	-- After :TlaPdf, every save rebuilds the PDF so the open viewer stays current
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*.tla",
		callback = function(args)
			if tla_pdf_live[args.buf] then
				tla_typeset(args.buf, function() end)
			end
			-- Definitions may have changed; recheck open .cfg files
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "cfg" then
					tla_cfg_check(buf)
				end
			end
		end,
	})
end

function M.config()
	local cmp = require("cmp")
	cmp.register_source("tla_symbols", tla_cmp_source)
	cmp.register_source("tla_words", tla_words_source)
	cmp.register_source("tla_names", tla_names_source)
	cmp.setup.filetype("tla", {
		sources = cmp.config.sources({
			{ name = "tla_symbols" },
			{ name = "tla_names" },
			{ name = "luasnip" },
			{ name = "tla_words" },
			{
				name = "buffer",
				-- Spec names come from tla_names with their kind; keep the rest (strings, bound variables)
				entry_filter = function(entry)
					return not tla_known_name(entry:get_completion_item().label)
				end,
			},
			{ name = "path" },
		}),
	})
	tla_add_snippets()
end

return M
