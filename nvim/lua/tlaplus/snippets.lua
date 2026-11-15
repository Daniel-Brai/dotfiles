-- TLA+ and PlusCal snippets for LuaSnip

-- TLA+ snippets, written the way tlafmt lays code out (80-column module header,
-- 4-space bullets, "x \in S: P"). Operators are typed in ASCII; the conceal
-- rules still show them as symbols
local tla_snippets = {
	-- Module level
	{ "ext", "EXTENDS", "EXTENDS ${1:Naturals}" },
	{ "extends", "EXTENDS the common modules", "EXTENDS Naturals, Sequences, FiniteSets, TLC" },
	{ "const", "CONSTANTS", "CONSTANTS ${1:N}" },
	{ "var", "VARIABLES", "VARIABLES ${1:x}" },
	{ "vars", "Tuple of every variable", "vars == << ${1:x} >>" },
	{ "assume", "ASSUME about constants", "ASSUME ${1:N \\in Nat}" },
	{ "def", "Definition", "${1:Name} == ${0:TRUE}" },
	{ "op", "Operator with arguments", "${1:Op}(${2:a}) == ${0:a}" },
	{ "fun", "Function definition f[x \\in S]", "${1:f}[${2:n} \\in ${3:Nat}] == ${0:n}" },
	{ "local", "LOCAL definition", "LOCAL ${1:Name} == ${0:TRUE}" },
	{ "instance", "INSTANCE ... WITH", "${1:M} == INSTANCE ${2:Module} WITH ${3:p} <- ${0:e}" },
	{ "theorem", "THEOREM", "THEOREM ${1:Spec} => []${0:TypeOK}" },
	-- Spec structure
	{ "typeok", "Type invariant", "TypeOK ==\n    /\\ ${1:x} \\in ${0:Nat}" },
	{ "init", "Initial state", "Init ==\n    /\\ ${1:x} = ${0:0}" },
	{ "action", "Action: guard, change, UNCHANGED", "${1:Action} ==\n    /\\ ${2:x < 10}\n    /\\ ${3:x}' = ${4:x + 1}\n    /\\ UNCHANGED << ${0:y} >>" },
	{ "next", "Next as a choice of actions", "Next ==\n    \\/ ${1:A}\n    \\/ ${0:B}" },
	{ "spec", "Spec == Init /\\ [][Next]_vars", "Spec == Init /\\ [][Next]_vars" },
	{ "specwf", "Spec with weak fairness", "Spec == Init /\\ [][Next]_vars /\\ WF_vars(${0:Next})" },
	{ "unchanged", "UNCHANGED << >>", "UNCHANGED << ${0:x} >>" },
	{ "wf", "Weak fairness", "WF_vars(${0:Next})" },
	{ "sf", "Strong fairness", "SF_vars(${0:Next})" },
	-- Expressions
	{ "if", "IF THEN ELSE", "IF ${1:TRUE} THEN ${2:1} ELSE ${0:2}" },
	{ "let", "LET ... IN", "LET ${1:a} == ${2:1} IN ${0:a}" },
	{ "case", "CASE with OTHER", "CASE ${1:x = 0} -> ${2:1}\n    [] OTHER -> ${0:2}" },
	{ "choose", "CHOOSE x \\in S: P", "CHOOSE ${1:x} \\in ${2:S}: ${0:TRUE}" },
	{ "forall", "\\A x \\in S: P", "\\A ${1:x} \\in ${2:S}: ${0:TRUE}" },
	{ "exists", "\\E x \\in S: P", "\\E ${1:x} \\in ${2:S}: ${0:TRUE}" },
	{ "filter", "Set filter {x \\in S: P}", "{${1:x} \\in ${2:S}: ${0:TRUE}}" },
	{ "map", "Set map {e: x \\in S}", "{${1:e}: ${2:x} \\in ${0:S}}" },
	{ "func", "Function [x \\in S |-> e]", "[${1:x} \\in ${2:S} |-> ${0:e}]" },
	{ "funcset", "Set of functions [S -> T]", "[${1:S} -> ${0:T}]" },
	{ "rec", "Record [a |-> e]", "[${1:a} |-> ${0:1}]" },
	{ "recset", "Set of records [a: S]", "[${1:a}: ${0:S}]" },
	{ "except", "[f EXCEPT ![x] = e]", "[${1:f} EXCEPT ![${2:x}] = ${0:e}]" },
	{ "tuple", "Tuple << a, b >>", "<< ${1:a}, ${0:b} >>" },
	-- PlusCal, as in Practical TLA+
	{ "algorithm", "PlusCal algorithm", "(*--algorithm ${1:name}\nvariables\n    ${2:x = 0};\n\nbegin\n    ${3:Step}:\n        ${0:skip};\nend algorithm;*)" },
	{ "process", "PlusCal process", "process ${1:Name} \\in ${2:1..2}\nvariables ${3:local = 0};\nbegin\n    ${4:Step}:\n        ${0:skip};\nend process;" },
	{ "fairprocess", "PlusCal fair process", "fair process ${1:Name} \\in ${2:1..2}\nbegin\n    ${3:Step}:\n        ${0:skip};\nend process;" },
	{ "procedure", "PlusCal procedure (spec needs EXTENDS Sequences)","procedure ${1:name}(${2:arg})\nbegin\n    ${3:Step}:\n        ${0:skip};\n        return;\nend procedure;" },
	{ "macro", "PlusCal macro", "macro ${1:name}(${2:arg})\nbegin\n    ${0:skip};\nend macro;" },
	{ "define", "PlusCal define block", "define\n    ${1:Inv} == ${0:TRUE}\nend define;" },
	{ "either", "PlusCal either/or", "either\n    ${1:skip};\nor\n    ${0:skip};\nend either;" },
	{ "with", "PlusCal with", "with ${1:x} \\in ${2:S} do\n    ${0:skip};\nend with;" },
	-- PlusCal requires a label on every while
	{ "while", "PlusCal while (with its label)", "${1:Loop}:\n    while ${2:TRUE} do\n        ${0:skip};\n    end while;" },
	{ "ifp", "PlusCal if", "if ${1:TRUE} then\n    ${0:skip};\nend if;" },
}

-- "---- MODULE Name ----" padded to 80 columns, as tlafmt writes it
local function tla_module_header()
	local name = vim.fn.expand("%:t:r")
	if name == "" then
		name = "Spec"
	end
	local middle = " MODULE " .. name .. " "
	local left = math.max(4, math.floor((80 - #middle) / 2))
	local right = math.max(4, 80 - #middle - left)
	return ("-"):rep(left) .. middle .. ("-"):rep(right)
end
local tla_module_footer = ("="):rep(80)

-- Indent of the line the snippet was typed on; LuaSnip indents the later lines to match
local function box_indent(parent)
	return #(parent.snippet.env.TM_CURRENT_LINE or ""):match("^%s*")
end

local function box_border(_, parent)
	return "(" .. ("*"):rep(require("tlaplus.box").WIDTH - box_indent(parent) - 2) .. ")"
end

local function box_padding(args, parent)
	local inner = require("tlaplus.box").WIDTH - box_indent(parent) - 6
	return (" "):rep(math.max(0, inner - vim.fn.strdisplaywidth(args[1][1] or "")))
end

local function tla_add_snippets()
	local ls = require("luasnip")
	local s, t, i, f = ls.snippet, ls.text_node, ls.insert_node, ls.function_node
	local rep = require("luasnip.extras").rep
	local list = {
		-- Named after the file, so TLC and SANY accept it
		s({ trig = "module", dscr = "Module named after this file" }, {
			f(tla_module_header), t({ "", "" }), i(0), t({ "", "", tla_module_footer }),
		}),
		-- Box comment whose right edge stays at column 77 while you type
		s({ trig = "box", dscr = "Box comment (* ... *)" }, {
			f(box_border), t({ "", "(* " }), i(1), f(box_padding, { 1 }), t({ " *)", "" }), f(box_border), i(0),
		}),
		s({ trig = "modulefull", dscr = "Module with EXTENDS, VARIABLES, TypeOK, Init, Next and Spec" }, {
			f(tla_module_header),
			t({ "", "EXTENDS " }), i(1, "Naturals"),
			t({ "", "", "VARIABLES " }), i(2, "x"),
			t({ "", "", "vars == << " }), rep(2), t(" >>"),
			t({ "", "", "TypeOK ==", "    /\\ " }), rep(2), t(" \\in "), i(3, "Nat"),
			t({ "", "", "Init ==", "    /\\ " }), rep(2), t(" = "), i(4, "0"),
			t({ "", "", "Next ==", "    /\\ " }), rep(2), t("' = "), i(5, "x + 1"),
			t({ "", "", "Spec == Init /\\ [][Next]_vars", "", tla_module_footer }), i(0),
		}),
	}
	for _, sn in ipairs(tla_snippets) do
		table.insert(list, ls.parser.parse_snippet({ trig = sn[1], dscr = sn[2] }, sn[3]))
	end
	ls.add_snippets("tla", list, { key = "tla_snippets" })
end

return {
	tla_add_snippets = tla_add_snippets,
}
