-- TLA+ Unicode symbols: the RFC 5 table, the cheat sheet, operator completion
-- and the symbols drawn over TLC output

-- TLA+ Unicode standard (RFC 5): ASCII forms, symbol, meaning. Same table as
-- tlaplus-nvim-plugin; used by the completion menu and :TlaCheatSheet
local tla_symbols = {
	{ "Definitions and structure" },
	{ { "==" }, "≜", "defined as" },
	{ { "\\in" }, "∈", "element of" },
	{ { "\\notin" }, "∉", "not an element of" },
	{ { "<-" }, "←", "substitution (INSTANCE WITH)" },
	{ { "\\A", "\\forall" }, "∀", "for all" },
	{ { "\\E", "\\exists" }, "∃", "there exists" },
	{ { "|->" }, "↦", "function / record field maps to" },
	{ { "->" }, "→", "function set, CASE arrow" },
	{ { "<<" }, "⟨", "tuple open" },
	{ { ">>" }, "⟩", "tuple close" },
	{ { ">>_" }, "⟩_", "angle action subscript" },
	{ { "[]" }, "□", "CASE separator, always" },
	{ { "::" }, "∷", "label" },
	{ "Logic and temporal" },
	{ { "/\\", "\\land" }, "∧", "and" },
	{ { "\\/", "\\lor" }, "∨", "or" },
	{ { "~", "\\lnot", "\\neg" }, "¬", "not" },
	{ { "=>" }, "⇒", "implies" },
	{ { "<=>" }, "⇔", "if and only if" },
	{ { "\\equiv" }, "≡", "equivalent" },
	{ { "<>" }, "◇", "eventually" },
	{ { "~>" }, "↝", "leads to" },
	{ { "-+->" }, "⇸", "guarantees" },
	{ "Relations" },
	{ { "/=", "#" }, "≠", "not equal" },
	{ { "<=", "=<", "\\leq" }, "≤", "less or equal" },
	{ { ">=", "\\geq" }, "≥", "greater or equal" },
	{ { "\\approx" }, "≈", "approximately" },
	{ { "\\asymp" }, "≍", "asymptotic" },
	{ { "\\cong" }, "≅", "congruent" },
	{ { "\\doteq" }, "≐", "approaches the limit" },
	{ { "\\gg" }, "≫", "much greater" },
	{ { "\\ll" }, "≪", "much less" },
	{ { "\\prec" }, "≺", "precedes" },
	{ { "\\succ" }, "≻", "succeeds" },
	{ { "\\preceq" }, "⪯", "precedes or equal" },
	{ { "\\succeq" }, "⪰", "succeeds or equal" },
	{ { "\\propto" }, "∝", "proportional to" },
	{ { "\\sim" }, "∼", "similar" },
	{ { "\\simeq" }, "≃", "similar or equal" },
	{ { "|-" }, "⊢", "proves" },
	{ { "|=" }, "⊨", "models" },
	{ { "-|" }, "⊣", "left tack" },
	{ { "=|" }, "⫤", "left double tack" },
	{ "Sets" },
	{ { "\\subset" }, "⊂", "proper subset" },
	{ { "\\supset" }, "⊃", "proper superset" },
	{ { "\\subseteq" }, "⊆", "subset or equal" },
	{ { "\\supseteq" }, "⊇", "superset or equal" },
	{ { "\\sqsubset" }, "⊏", "square subset" },
	{ { "\\sqsupset" }, "⊐", "square superset" },
	{ { "\\sqsubseteq" }, "⊑", "square subset or equal" },
	{ { "\\sqsupseteq" }, "⊒", "square superset or equal" },
	{ { "\\cap", "\\intersect" }, "∩", "intersection" },
	{ { "\\cup", "\\union" }, "∪", "union" },
	{ { "\\sqcap" }, "⊓", "square cap" },
	{ { "\\sqcup" }, "⊔", "square cup" },
	{ { "\\uplus" }, "⊎", "multiset union" },
	{ { "Nat" }, "ℕ", "natural numbers (display only)" },
	{ { "Int" }, "ℤ", "integers (display only)" },
	{ { "Real" }, "ℝ", "real numbers (display only)" },
	{ "Arithmetic and other operators" },
	{ { "\\X", "\\times" }, "×", "cartesian product" },
	{ { "\\div" }, "÷", "integer division" },
	{ { "\\o", "\\circ" }, "∘", "sequence concatenation" },
	{ { "\\cdot" }, "⋅", "action composition" },
	{ { "(+)", "\\oplus" }, "⊕", "circled plus" },
	{ { "(-)", "\\ominus" }, "⊖", "circled minus" },
	{ { "(.)", "\\odot" }, "⊙", "circled dot" },
	{ { "(/)", "\\oslash" }, "⊘", "circled slash" },
	{ { "(\\X)", "\\otimes" }, "⊗", "circled times" },
	{ { "\\bigcirc" }, "◯", "big circle" },
	{ { "\\bullet" }, "●", "bullet" },
	{ { "\\star" }, "⋆", "star" },
	{ { "\\wr" }, "≀", "wreath" },
	{ { "||" }, "‖", "parallel" },
	{ { "!!" }, "‼", "double bang" },
	{ { "??" }, "⁇", "double question" },
	{ { ".." }, "‥", "integer range" },
	{ { "..." }, "…", "ellipsis" },
	{ { ":=" }, "≔", "assign" },
	{ { "::=" }, "⩴", "BNF rule" },
	{ { "^+" }, "⁺", "transitive closure" },
}

-- TLC/SANY 1.8.0 read Unicode operators but not ℕ ℤ ℝ (the standard modules only
-- define Nat, Int, Real), so drop tlaplus-nvim-plugin's typing abbreviations for those
local function keep_number_sets_ascii(buf)
	for _, name in ipairs({ "Nat", "Int", "Real" }) do
		pcall(vim.keymap.del, "ia", name, { buffer = buf })
	end
end

local function tla_cheat_sheet()
	local lines = { " TLA+ symbols   (q to close, :TlaSymbolsToggle for ASCII/symbols)", "" }
	for _, s in ipairs(tla_symbols) do
		if #s == 1 then
			if #lines > 2 then
				table.insert(lines, "")
			end
			table.insert(lines, " " .. s[1])
		else
			local ascii = table.concat(s[1], "  ")
			local symbol = s[2] .. string.rep(" ", 3 - vim.fn.strdisplaywidth(s[2]))
			table.insert(lines, string.format("   %s  %-24s %s", symbol, ascii, s[3]))
		end
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	local width = math.min(76, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 6)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " TLA+ cheat sheet ",
		title_pos = "center",
	})
	vim.wo[win].cursorline = true
	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, nowait = true })
	end
	vim.fn.matchadd("Title", [[^ \S.*]], 10, -1, { window = win })
	vim.fn.matchadd("Special", [[^   \zs\S\+]], 10, -1, { window = win })
end

-- nvim-cmp source: after typing the start of an ASCII operator (\su, <=, /\ ...),
-- the menu lists every matching operator with its symbol. Picking one inserts the
-- symbol, or the ASCII form while :TlaSymbolsToggle is on ASCII
local tla_cmp_source = {}

-- Nat/Int/Real are left out: they start like ordinary identifiers (Init, Next ...)
local tla_cmp_entries = {}
for _, s in ipairs(tla_symbols) do
	if #s > 1 then
		for _, ascii in ipairs(s[1]) do
			if not ascii:match("^%a") then
				table.insert(tla_cmp_entries, { ascii = ascii, symbol = s[2], meaning = s[3] })
			end
		end
	end
end

function tla_cmp_source:is_available()
	return vim.bo.filetype == "tla"
end

function tla_cmp_source:get_trigger_characters()
	return { "\\", "/", "<", ">", "=", "~", "|", ":", "#", ".", "(", "!", "?", "^", "[", "-" }
end

function tla_cmp_source:get_keyword_pattern()
	return [[[\\/<>=~|:#.()!?^\[\]+\-]\+\a*]]
end

function tla_cmp_source:complete(params, callback)
	local before = params.context.cursor_before_line
	local line = params.context.cursor.line
	-- Longest suffix that starts with an operator character and begins some ASCII form
	for start = math.max(1, #before - 11), #before do
		local typed = before:sub(start)
		if typed:match("^[^%w%s]") then
			local items = {}
			-- cmp expects UTF-16 positions; symbols earlier on the line are multi-byte
			local range = {
				start = { line = line, character = vim.str_utfindex(before, "utf-16", start - 1) },
				["end"] = { line = line, character = vim.str_utfindex(before, "utf-16", #before) },
			}
			for _, e in ipairs(tla_cmp_entries) do
				if vim.startswith(e.ascii, typed) then
					table.insert(items, {
						label = e.symbol .. "  " .. e.ascii,
						filterText = e.ascii,
						sortText = string.format("%03d", #e.ascii),
						kind = require("cmp").lsp.CompletionItemKind.Operator,
						documentation = e.meaning,
						textEdit = {
							newText = vim.g.tlaplus_mappings_enable and e.symbol or e.ascii,
							range = range,
						},
					})
				end
			end
			if #items > 0 then
				return callback(items)
			end
		end
	end
	callback({})
end

-- TLC output (the :TlaCheck window) shows states and traces as ASCII TLA+.
-- Conceal rules draw them with the same symbols as the spec; the text itself is untouched
local function tla_output_symbols(buf)
	local forms = {}
	for _, entry in ipairs(tla_symbols) do
		-- Single-character symbols only (conceal draws one cell), and only operator
		-- spellings: words like Nat stay as they are
		if #entry > 1 and vim.fn.strchars(entry[2]) == 1 then
			for _, ascii in ipairs(entry[1]) do
				if not ascii:match("^%a") then
					table.insert(forms, { ascii = ascii, symbol = entry[2] })
				end
			end
		end
	end
	-- Shorter first: at the same column a later rule wins, so <=> beats <= and =>
	table.sort(forms, function(a, b)
		return #a.ascii < #b.ascii
	end)
	vim.api.nvim_buf_call(buf, function()
		for i, f in ipairs(forms) do
			local pattern = "\\V" .. f.ascii:gsub("\\", "\\\\")
			-- \in must not match the start of \intersect
			if f.ascii:match("%a$") then
				pattern = pattern .. "\\>"
			end
			vim.cmd(("syntax match TlaOutSym%d /%s/ conceal cchar=%s"):format(
				i, pattern:gsub("/", "\\/"), f.symbol))
		end
	end)
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.wo[win].conceallevel = 2
		vim.wo[win].concealcursor = "nc"
	end
end

return {
	tla_symbols = tla_symbols,
	keep_number_sets_ascii = keep_number_sets_ascii,
	tla_cheat_sheet = tla_cheat_sheet,
	tla_cmp_source = tla_cmp_source,
	tla_output_symbols = tla_output_symbols,
}
