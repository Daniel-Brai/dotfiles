-- Go to definition and hover (K) for .tla and .cfg buffers

local index = require("tlaplus.index")
local tla_index = index.tla_index
local tla_std_module = index.tla_std_module
local tla_file_lines = index.tla_file_lines
local cfg = require("tlaplus.cfg")
local tla_cfg_spec_file = cfg.tla_cfg_spec_file
local tla_cfg_keywords = cfg.tla_cfg_keywords
local completion = require("tlaplus.completion")
local tla_std_modules = completion.tla_std_modules

-- Go to definition (grd, gd, Ctrl-], Ctrl+click) and hover (K) for .tla and .cfg
local function tla_lookup(word)
	local cfg = vim.bo.filetype == "cfg"
	local root = cfg and tla_cfg_spec_file() or vim.api.nvim_buf_get_name(0)
	if not root then
		return nil
	end
	local current = vim.api.nvim_buf_get_name(0)
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local top, nearest_let
	for _, sym in ipairs(tla_index(root)) do
		if sym.name == word then
			if sym.kind ~= "LET definition" then
				top = top or sym
			elseif sym.path == current and sym.lnum <= line then
				nearest_let = sym
			end
		end
	end
	-- A LET definition above the cursor shadows the top-level one
	return nearest_let or top
end

local function tla_goto_definition()
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end
	local sym = tla_lookup(word)
	if not sym and vim.bo.filetype == "tla" then
		-- Bound variables: \A x \in S, {x \in S: ...}, [x \in S |-> ...]
		local pos = vim.fn.searchpos([[\V\<]] .. word .. [[\>\s\*\(\\in\|∈\)]], "bnW")
		if pos[1] > 0 then
			vim.cmd("normal! m'")
			vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] - 1 })
			return
		end
	end
	if not sym then
		vim.notify("No definition found for " .. word, vim.log.levels.WARN, { title = "TLA+" })
		return
	end
	vim.cmd("normal! m'")
	if sym.path ~= vim.api.nvim_buf_get_name(0) then
		vim.cmd("edit " .. vim.fn.fnameescape(sym.path))
		if sym.std then
			vim.bo.readonly = true
		end
	end
	vim.api.nvim_win_set_cursor(0, { sym.lnum, sym.col })
end

-- The file of a module named in EXTENDS or INSTANCE: a .tla next to the current
-- file first, then the standard modules inside tla2tools.jar (same order as tla_index)
local function tla_module_path(name)
	if not name:match("^[%a_][%w_]*$") then
		return nil
	end
	local here = vim.fn.expand("%:p:h") .. "/" .. name .. ".tla"
	if vim.uv.fs_stat(here) then
		return here, false
	end
	local sp = tla_std_module(name)
	if sp then
		return sp, true
	end
end

-- Hover text for a module: what it's for, what it extends, and every operator it
-- exports (top-level, non-LOCAL definitions, infix ones like a + b included)
local function tla_module_hover(name)
	local path, std = tla_module_path(name)
	if not path then
		return nil
	end
	local lines = { "---- MODULE " .. name .. " ----" }
	for _, m in ipairs(tla_std_modules) do
		if std and m[1] == name then
			table.insert(lines, "\\* " .. m[2])
		end
	end
	local defs = {}
	for _, line in ipairs(tla_file_lines(path)) do
		local code = line:gsub("\\%*.*$", "")
		local ext = code:match("^EXTENDS%s+.*")
		if ext then
			table.insert(lines, vim.trim(ext))
		end
		-- Top-level definitions only: indented lines belong to the one above
		local head = code:match("^(%S.-)%s*==") or code:match("^(%S.-)%s*≜")
		-- Skips the closing ==== line, LOCAL definitions and comment banners
		if head and not head:match("^=") and not head:match("^LOCAL%s") and not head:match("^%(%*") then
			table.insert(defs, (head:gsub("^THEOREM%s+", ""):gsub("%s+", " ")))
		end
	end
	if #defs > 0 then
		table.insert(lines, "")
		vim.list_extend(lines, defs)
	end
	table.insert(lines, "")
	table.insert(lines, "\\* " .. (std and "Standard module" or "Module in this folder") .. ", " .. vim.fn.fnamemodify(path, ":~"))
	return lines
end

local function tla_hover()
	local word = vim.fn.expand("<cword>")
	local sym = word ~= "" and tla_lookup(word)
	if not sym and word ~= "" and vim.bo.filetype == "tla" then
		local lines = tla_module_hover(word)
		if lines then
			return vim.lsp.util.open_floating_preview(lines, "tla", { border = "rounded", max_height = 30 })
		end
	end
	if not sym then
		for _, kw in ipairs(tla_cfg_keywords) do
			if vim.bo.filetype == "cfg" and kw[1] == word then
				return vim.lsp.util.open_floating_preview({ kw[2] }, "markdown", { border = "rounded" })
			end
		end
		return
	end
	local lines = vim.split(sym.doc, "\n")
	table.insert(lines, "")
	table.insert(lines, "\\* " .. sym.kind .. ", " .. sym.module .. ".tla line " .. sym.lnum)
	vim.lsp.util.open_floating_preview(lines, "tla", { border = "rounded" })
end

local function tla_map_navigation(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
	end
	map("grd", tla_goto_definition, "TLA+: go to definition")
	map("gd", tla_goto_definition, "TLA+: go to definition")
	map("<C-]>", tla_goto_definition, "TLA+: go to definition")
	map("<C-LeftMouse>", function()
		local pos = vim.fn.getmousepos()
		if pos.winid ~= 0 then
			vim.api.nvim_set_current_win(pos.winid)
			vim.api.nvim_win_set_cursor(pos.winid, { pos.line, math.max(pos.column - 1, 0) })
		end
		tla_goto_definition()
	end, "TLA+: go to definition")
	map("K", tla_hover, "TLA+: show definition")
end

return {
	tla_map_navigation = tla_map_navigation,
}
