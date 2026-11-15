-- nvim-cmp sources for .tla buffers: keywords, standard modules and spec names

local index = require("tlaplus.index")
local tla_index = index.tla_index

-- Keywords and standard-module operators for the completion menu
local tla_words = {
	{ "Keywords", {
		"ASSUME", "ASSUMPTION", "AXIOM", "BOOLEAN", "CASE", "CHOOSE", "CONSTANT", "CONSTANTS",
		"DOMAIN", "ELSE", "ENABLED", "EXCEPT", "EXTENDS", "FALSE", "IF", "IN", "INSTANCE", "LAMBDA",
		"LET", "LOCAL", "MODULE", "OTHER", "RECURSIVE", "STRING", "SUBSET", "THEN", "THEOREM",
		"TRUE", "UNCHANGED", "UNION", "VARIABLE", "VARIABLES", "WITH",
	} },
	{ "Naturals", { "Nat" } },
	{ "Integers", { "Int" } },
	{ "Reals", { "Real", "Infinity" } },
	{ "Sequences", { "Seq(S)", "Len(s)", "Append(s, e)", "Head(s)", "Tail(s)", "SubSeq(s, m, n)", "SelectSeq(s, Test(_))" } },
	{ "FiniteSets", { "IsFiniteSet(S)", "Cardinality(S)" } },
	{ "Bags", {
		"IsABag(B)", "BagToSet(B)", "SetToBag(S)", "BagIn(e, B)", "EmptyBag", "BagUnion(S)",
		"SubBag(B)", "BagCardinality(B)", "CopiesIn(e, B)",
	} },
	{ "TLC", {
		"Print(out, val)", "PrintT(out)", "Assert(val, out)", "JavaTime", "TLCGet(i)", "TLCSet(i, v)",
		"Permutations(S)", "SortSeq(s, Op(_, _))", "RandomElement(s)", "Any", "ToString(v)", "TLCEval(v)",
	} },
}

-- Modules offered after EXTENDS and INSTANCE: the ones in tla2tools.jar, then any
-- .tla next to the current file
local tla_std_modules = {
	{ "Naturals", "Nat, arithmetic, \\div, %, comparisons, a..b ranges" },
	{ "Integers", "Int and unary minus, plus everything in Naturals" },
	{ "Reals", "Real, /, Infinity, plus everything in Integers" },
	{ "Sequences", "Seq, Len, Append, Head, Tail, SubSeq, SelectSeq, \\o" },
	{ "FiniteSets", "IsFiniteSet, Cardinality" },
	{ "Bags", "Multisets: SetToBag, BagToSet, BagIn, (+), (-), CopiesIn ..." },
	{ "TLC", "Print, Assert, Permutations, SortSeq, ToString, :>, @@, RandomElement ..." },
	{ "TLCExt", "AssertEq, AssertError, Trace, CounterExample, TLCModelValue ..." },
	{ "Json", "ToJson, JsonSerialize, JsonDeserialize ..." },
	{ "Randomization", "RandomSubset, RandomSetOfSubsets" },
	{ "RealTime", "RTBound, RTnow (real-time specs)" },
}

local tla_words_source = {}

function tla_words_source:is_available()
	return vim.bo.filetype == "tla"
end

-- Space and comma open the menu, but only after EXTENDS / INSTANCE
function tla_words_source:get_trigger_characters()
	return { " ", "," }
end

local function tla_module_items(line)
	local kinds = require("cmp").lsp.CompletionItemKind
	local listed = {}
	for m in line:gmatch("[%a_][%w_]*") do
		listed[m] = true
	end
	local items = {}
	for n, m in ipairs(tla_std_modules) do
		if not listed[m[1]] then
			table.insert(items, {
				label = m[1], kind = kinds.Module, sortText = ("%02d"):format(n),
				documentation = { kind = "plaintext", value = "Standard module: " .. m[2] },
			})
		end
	end
	local file = vim.api.nvim_buf_get_name(0)
	local here = vim.fn.fnamemodify(file, ":t:r")
	for _, path in ipairs(vim.fn.glob(vim.fn.fnamemodify(file, ":h") .. "/*.tla", false, true)) do
		local m = vim.fn.fnamemodify(path, ":t:r")
		-- Skip this file, PlusCal/TLC trace files, and modules already listed
		if m ~= here and not listed[m] and not m:match("_TTrace_") and m:match("^[%a_][%w_]*$") then
			table.insert(items, { label = m, kind = kinds.Module, sortText = "99" .. m, documentation = "Module in this folder" })
		end
	end
	return items
end

function tla_words_source:complete(params, callback)
	local before = params.context.cursor_before_line
	if before:match("^%s*EXTENDS[%s,%w_]*$") or before:match("INSTANCE%s+[%w_]*$") then
		return callback(tla_module_items(before))
	end
	-- A space or comma anywhere else shouldn't pop the menu up
	local trigger = params.completion_context and params.completion_context.triggerCharacter
	if trigger == " " or trigger == "," then
		return callback({})
	end
	local kinds = require("cmp").lsp.CompletionItemKind
	local items = {}
	for _, group in ipairs(tla_words) do
		for _, word in ipairs(group[2]) do
			local name = word:match("^[%w_]+")
			table.insert(items, {
				label = word,
				filterText = name,
				insertText = name,
				kind = group[1] == "Keywords" and kinds.Keyword or kinds.Function,
				documentation = group[1] == "Keywords" and "TLA+ keyword" or ("From EXTENDS " .. group[1]),
			})
		end
	end
	callback(items)
end

local tla_kind_labels = { Variable = "Variable", Constant = "Constant", Definition = "Definition", ["LET definition"] = "LET" }

local function tla_symbol_item(sym, current)
	local kinds = require("cmp").lsp.CompletionItemKind
	local where = sym.path == current and ("line " .. sym.lnum) or (sym.module .. ".tla, line " .. sym.lnum)
	local kind = ({ Variable = kinds.Variable, Constant = kinds.Constant })[sym.kind]
		or (sym.has_args and kinds.Function or kinds.Value)
	return {
		label = sym.signature,
		filterText = sym.name,
		insertText = sym.name,
		kind = kind,
		data = { tla_kind = tla_kind_labels[sym.kind] .. (sym.path ~= current and (" · " .. sym.module) or "") },
		documentation = {
			kind = "markdown",
			value = "```tla\n" .. sym.doc .. "\n```\n" .. sym.kind .. ", " .. where,
		},
	}
end

-- Completion for .tla buffers: every variable, constant and definition in scope
local tla_names_source = {}

function tla_names_source:is_available()
	return vim.bo.filetype == "tla"
end

function tla_names_source:complete(_, callback)
	local current = vim.api.nvim_buf_get_name(0)
	local items, seen = {}, {}
	for _, sym in ipairs(tla_index(current)) do
		-- Standard-module operators come from tla_words with their module noted
		if not sym.std and not seen[sym.name] and (sym.kind ~= "LET definition" or sym.path == current) then
			seen[sym.name] = true
			table.insert(items, tla_symbol_item(sym, current))
		end
	end
	callback(items)
end

-- Names the index knows, so the plain buffer source doesn't list them again
local function tla_known_name(word)
	for _, sym in ipairs(tla_index(vim.api.nvim_buf_get_name(0))) do
		if sym.name == word then
			return true
		end
	end
	return false
end

return {
	tla_words = tla_words,
	tla_std_modules = tla_std_modules,
	tla_words_source = tla_words_source,
	tla_symbol_item = tla_symbol_item,
	tla_names_source = tla_names_source,
	tla_known_name = tla_known_name,
}
