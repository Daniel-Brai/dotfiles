-- TLC .cfg files: completion, diagnostics, syntax and creating one for a spec

local index = require("tlaplus.index")
local tla_index = index.tla_index
local tla_spec_names = index.tla_spec_names
local tla_spec_roles = index.tla_spec_roles
local tla_std_dir = index.tla_std_dir
local completion = require("tlaplus.completion")
local tla_symbol_item = completion.tla_symbol_item

-- TLC .cfg files: keywords, plus the definitions and constants of the spec next to it
local tla_cfg_keywords = {
	{ "INIT", "Initial-state predicate (use with NEXT)" },
	{ "NEXT", "Next-state action (use with INIT)" },
	{ "SPECIFICATION", "Whole spec formula, e.g. Spec; replaces INIT and NEXT" },
	{ "INVARIANT", "Must hold in every reachable state" },
	{ "INVARIANTS", "Must hold in every reachable state" },
	{ "PROPERTY", "Temporal property checked over behaviours" },
	{ "PROPERTIES", "Temporal properties checked over behaviours" },
	{ "CONSTANT", "Values for the spec's CONSTANTS: N = 3, S = {a, b}, Op <- Def" },
	{ "CONSTANTS", "Values for the spec's CONSTANTS: N = 3, S = {a, b}, Op <- Def" },
	{ "CONSTRAINT", "Stop exploring past states where this is false" },
	{ "CONSTRAINTS", "Stop exploring past states where these are false" },
	{ "ACTION_CONSTRAINT", "Only explore steps where this action formula holds" },
	{ "ACTION_CONSTRAINTS", "Only explore steps where these action formulas hold" },
	{ "SYMMETRY", "Treat permutations of model values as the same state" },
	{ "VIEW", "States with the same VIEW value count as one" },
	{ "CHECK_DEADLOCK", "TRUE or FALSE; whether a stuck state is an error" },
	{ "POSTCONDITION", "Checked once after model checking finishes" },
	{ "ALIAS", "Expression shown for each state of an error trace" },
}

-- The spec a .cfg belongs to: same name, or the only .tla in the folder
local function tla_cfg_spec_file(buf)
	local cfg = vim.api.nvim_buf_get_name(buf or 0)
	if not cfg:match("%.cfg$") then
		return nil
	end
	local same = cfg:gsub("%.cfg$", ".tla")
	if vim.uv.fs_stat(same) then
		return same
	end
	local specs = vim.fn.glob(vim.fn.fnamemodify(cfg, ":h") .. "/*.tla", false, true)
	return #specs == 1 and specs[1] or nil
end

-- Diagnostics for TLC .cfg files, checked against the spec next to them
local tla_cfg_ns = vim.api.nvim_create_namespace("tla_cfg")

local tla_cfg_keyword_set = {}
for _, kw in ipairs(tla_cfg_keywords) do
	tla_cfg_keyword_set[kw[1]] = true
end

-- Keywords followed by names of definitions in the spec
local tla_cfg_takes_defs = {
	INIT = true, NEXT = true, SPECIFICATION = true, INVARIANT = true, INVARIANTS = true,
	PROPERTY = true, PROPERTIES = true, CONSTRAINT = true, CONSTRAINTS = true,
	ACTION_CONSTRAINT = true, ACTION_CONSTRAINTS = true, SYMMETRY = true, VIEW = true,
	POSTCONDITION = true, ALIAS = true,
}

local function tla_edit_distance(a, b)
	a, b = a:lower(), b:lower()
	local prev = {}
	for j = 0, #b do
		prev[j] = j
	end
	for i = 1, #a do
		local cur = { [0] = i }
		for j = 1, #b do
			cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a:sub(i, i) == b:sub(j, j) and 0 or 1))
		end
		prev = cur
	end
	return prev[#b]
end

local function tla_closest(word, candidates)
	local best, best_d
	for _, c in ipairs(candidates) do
		local d = tla_edit_distance(word, c)
		if d <= math.max(2, math.floor(#word / 3)) and (not best_d or d < best_d) then
			best, best_d = c, d
		end
	end
	return best
end

-- Words, "=", "<-" and other symbols with their positions; \* and (* *) comments skipped
local function tla_cfg_tokens(lines)
	local tokens, in_block = {}, false
	for lnum, line in ipairs(lines) do
		local col = 1
		while col <= #line do
			if in_block then
				local close = line:find("*)", col, true)
				if not close then
					break
				end
				in_block, col = false, close + 2
			elseif line:sub(col, col + 1) == "(*" then
				in_block, col = true, col + 2
			elseif line:sub(col, col + 1) == "\\*" then
				break
			elseif line:sub(col, col) == '"' then
				-- Strings are values, never names
				local close = line:find('"', col + 1, true)
				col = close and close + 1 or #line + 1
			else
				local word = line:match("^[%a_][%w_]*", col)
				local sym = line:match("^<%-", col) or line:match("^[^%s%w_]", col)
				if word then
					table.insert(tokens, { text = word, word = true, lnum = lnum - 1, col = col - 1 })
					col = col + #word
				elseif line:match("^%d", col) then
					col = col + #line:match("^%d+", col)
				elseif sym then
					table.insert(tokens, { text = sym, lnum = lnum - 1, col = col - 1 })
					col = col + #sym
				else
					col = col + 1
				end
			end
		end
	end
	return tokens
end

-- Syntax highlighting for TLC .cfg files. Names from the spec are coloured by what
-- they are, so a typo shows up uncoloured before the diagnostic even appears
local function tla_cfg_syntax(buf, names)
	vim.api.nvim_buf_call(buf, function()
		vim.cmd([[
			syntax clear
			syntax case match
			syntax keyword tlacfgKeyword INIT NEXT SPECIFICATION INVARIANT INVARIANTS PROPERTY PROPERTIES
			syntax keyword tlacfgKeyword CONSTANT CONSTANTS CONSTRAINT CONSTRAINTS ACTION_CONSTRAINT ACTION_CONSTRAINTS
			syntax keyword tlacfgKeyword SYMMETRY VIEW CHECK_DEADLOCK POSTCONDITION POSTCONDITIONS ALIAS
			syntax keyword tlacfgBoolean TRUE FALSE
			syntax match tlacfgNumber "\<\d\+\>"
			syntax match tlacfgOperator "<-\|="
			syntax match tlacfgDelimiter "[{}(),]"
			syntax region tlacfgString start=/"/ end=/"/ oneline
			syntax match tlacfgComment "\\\*.*$"
			syntax region tlacfgComment start="(\*" end="\*)"
			highlight default link tlacfgKeyword Keyword
			highlight default link tlacfgBoolean Boolean
			highlight default link tlacfgNumber Number
			highlight default link tlacfgOperator Operator
			highlight default link tlacfgDelimiter Delimiter
			highlight default link tlacfgString String
			highlight default link tlacfgComment Comment
			highlight default link tlacfgDefinition Function
			highlight default link tlacfgConstant Constant
		]])
		local defs, consts = vim.tbl_keys(names.defs), vim.tbl_keys(names.consts)
		if #defs > 0 then
			vim.cmd("syntax keyword tlacfgDefinition " .. table.concat(defs, " "))
		end
		if #consts > 0 then
			vim.cmd("syntax keyword tlacfgConstant " .. table.concat(consts, " "))
		end
		vim.b.current_syntax = "tlacfg"
	end)
end

local function tla_cfg_check(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local spec = tla_cfg_spec_file(buf)
	if not spec then
		vim.diagnostic.reset(tla_cfg_ns, buf)
		return
	end
	local spec_name = vim.fn.fnamemodify(spec, ":t")
	local names = tla_spec_names(spec)
	local def_list, const_list = vim.tbl_keys(names.defs), vim.tbl_keys(names.consts)
	local diags = {}
	local function add(tok, msg, severity)
		table.insert(diags, {
			lnum = tok.lnum, col = tok.col, end_col = tok.col + #tok.text,
			message = msg, severity = severity or vim.diagnostic.severity.ERROR, source = "tla-cfg",
		})
	end

	local tokens = tla_cfg_tokens(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
	local section, seen_kw, assigned = nil, {}, {}
	local in_value = false -- inside the value after "=" in CONSTANTS
	for idx, tok in ipairs(tokens) do
		local nxt = tokens[idx + 1]
		local starts_line = idx == 1 or tokens[idx - 1].lnum ~= tok.lnum
		if tok.text == "=" and (section == "CONSTANT" or section == "CONSTANTS") then
			in_value = true
		end
		if tok.word and tla_cfg_keyword_set[tok.text] then
			section, in_value = tok.text, false
			seen_kw[tok.text] = seen_kw[tok.text] or tok
		elseif tok.word and starts_line and tok.text:match("^[%u_]+$") and #tok.text > 2
			and not names.defs[tok.text] and not names.consts[tok.text] then
			local guess = tla_closest(tok.text, vim.tbl_keys(tla_cfg_keyword_set))
			add(tok, ("%s is not a TLC config keyword%s"):format(tok.text, guess and (". Did you mean " .. guess .. "?") or ""))
			section = nil
		elseif section == "CHECK_DEADLOCK" then
			if tok.text ~= "TRUE" and tok.text ~= "FALSE" then
				add(tok, "CHECK_DEADLOCK takes TRUE or FALSE")
			end
		elseif (section == "CONSTANT" or section == "CONSTANTS") and tok.word then
			local op = nxt and nxt.lnum == tok.lnum and nxt.text
			if op == "=" or op == "<-" then
				in_value = false
				assigned[tok.text] = true
				if op == "=" and not names.consts[tok.text] then
					local guess = tla_closest(tok.text, const_list)
					add(tok, ("%s is not a CONSTANT in %s%s"):format(tok.text, spec_name,
						guess and (". Did you mean " .. guess .. "?") or (". Declare it with CONSTANT " .. tok.text)))
				elseif op == "<-" and not names.consts[tok.text] and not names.defs[tok.text] then
					add(tok, ("%s is not a CONSTANT or definition in %s"):format(tok.text, spec_name))
				end
			elseif tokens[idx - 1] and tokens[idx - 1].text == "<-" then
				if not names.defs[tok.text] then
					local guess = tla_closest(tok.text, def_list)
					add(tok, ("%s is not defined in %s%s"):format(tok.text, spec_name,
						guess and (". Did you mean " .. guess .. "?") or (". Add " .. tok.text .. " == ... to the spec")))
				end
			elseif not in_value then
				add(tok, ("%s needs a value: %s = ... or %s <- Definition"):format(tok.text, tok.text, tok.text))
			end
		elseif section and tla_cfg_takes_defs[section] and tok.word then
			if not names.defs[tok.text] then
				local guess = tla_closest(tok.text, def_list)
				local hint = guess and (". Did you mean " .. guess .. "?") or (". Add " .. tok.text .. " == ... to the spec")
				if names.consts[tok.text] then
					hint = ". It is a CONSTANT; " .. section .. " needs a definition"
				end
				add(tok, ("%s is not defined in %s%s"):format(tok.text, spec_name, hint))
			end
		end
	end

	-- Whole-file rules
	local first = tokens[1] or { text = "", lnum = 0, col = 0 }
	if seen_kw.SPECIFICATION and (seen_kw.INIT or seen_kw.NEXT) then
		add(seen_kw.INIT or seen_kw.NEXT, "Use either SPECIFICATION or INIT/NEXT, not both")
	elseif seen_kw.INIT and not seen_kw.NEXT then
		add(seen_kw.INIT, "INIT needs a NEXT")
	elseif seen_kw.NEXT and not seen_kw.INIT then
		add(seen_kw.NEXT, "NEXT needs an INIT")
	elseif not seen_kw.SPECIFICATION and not seen_kw.INIT and #tokens > 0 then
		add(first, "TLC needs INIT and NEXT, or SPECIFICATION", vim.diagnostic.severity.WARN)
	end
	local missing = {}
	for c in pairs(names.consts) do
		if not assigned[c] then
			table.insert(missing, c)
		end
	end
	if #missing > 0 then
		table.sort(missing)
		add(seen_kw.CONSTANTS or seen_kw.CONSTANT or first, ("No value for CONSTANT %s. Add %s = ... under CONSTANTS"):format(
			table.concat(missing, ", "), missing[1]))
	end
	vim.diagnostic.set(tla_cfg_ns, buf, diags)
	tla_cfg_syntax(buf, names)
end

local tla_cfg_source = {}

function tla_cfg_source:is_available()
	return tla_cfg_spec_file() ~= nil
end

-- Space opens the menu right after a keyword (CHECK_DEADLOCK , INVARIANT ...)
function tla_cfg_source:get_trigger_characters()
	return { " " }
end

-- What the values after each keyword are
local tla_cfg_value_kind = {
	CHECK_DEADLOCK = "boolean", CONSTANT = "constant", CONSTANTS = "constant",
}
for kw in pairs(tla_cfg_takes_defs) do
	tla_cfg_value_kind[kw] = "definition"
end

-- The keyword whose section the cursor is in: the last keyword before the cursor
-- on this line, else the nearest one above (CONSTANTS and INVARIANTS span lines)
local function tla_cfg_section(before)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_get_lines(0, 0, row - 1, false)
	table.insert(lines, before)
	for n = #lines, 1, -1 do
		local code = lines[n]:gsub("\\%*.*$", "")
		local last
		for word in code:gmatch("[%a_]+") do
			if tla_cfg_keyword_set[word] then
				last = word
			end
		end
		if last then
			return last, n == #lines
		end
	end
end

-- Snippets that fill in the keyword's value too, from the spec next to this .cfg
local function tla_cfg_keyword_snippet(kw, roles)
	if kw == "CHECK_DEADLOCK" then
		return kw .. " ${1:FALSE}"
	end
	local default = ({
		SPECIFICATION = roles.spec, INIT = roles.init, NEXT = roles.next,
		INVARIANT = roles.typeok, INVARIANTS = roles.typeok,
	})[kw]
	return default and (kw .. " ${1:" .. default .. "}") or (kw .. " ")
end

function tla_cfg_source:complete(params, callback)
	local cmp = require("cmp")
	local kinds = cmp.lsp.CompletionItemKind
	local before = params.context.cursor_before_line
	local trigger = params.completion_context and params.completion_context.triggerCharacter
	local spec = tla_cfg_spec_file()
	local items = {}

	local section, same_line = tla_cfg_section(before)
	local value_kind = section and tla_cfg_value_kind[section]
	local at_line_start = before:match("^%s*[%a_]*$") ~= nil
	-- A word at the very start of the line can be a new keyword
	if at_line_start and not before:match("^%s+") then
		if trigger == " " then
			return callback({})
		end
		local roles = tla_spec_roles(spec)
		for _, kw in ipairs(tla_cfg_keywords) do
			table.insert(items, {
				label = kw[1], kind = kinds.Keyword, data = { tla_kind = "Keyword" }, documentation = kw[2],
				insertText = tla_cfg_keyword_snippet(kw[1], roles),
				insertTextFormat = cmp.lsp.InsertTextFormat.Snippet,
			})
		end
		if not same_line then
			value_kind = nil -- a fresh line under a section: keywords, or names below
		end
	end

	-- Inside CONSTANTS: N = <value> takes nothing, Op <- Def takes a definition
	if value_kind == "constant" then
		if before:match("<%-%s*[%a_]*$") then
			value_kind = "operator" -- Op <- Def: Def may take arguments
		elseif before:match("=") then
			return callback(items)
		end
	end

	if value_kind == "boolean" then
		for _, b in ipairs({ { "FALSE", "Don't report states with no next step as errors" }, { "TRUE", "Report a deadlock as an error (TLC's default)" } }) do
			table.insert(items, { label = b[1], kind = kinds.Value, data = { tla_kind = "Boolean" }, documentation = b[2] })
		end
		return callback(items)
	end

	-- Names from the spec: only the kind this section takes
	if trigger == " " and not value_kind then
		return callback(items)
	end
	local assigned = {}
	if value_kind == "constant" then
		for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
			local name = l:gsub("\\%*.*$", ""):match("([%a_][%w_]*)%s*[=<]")
			if name then
				assigned[name] = true
			end
		end
	end
	local seen = {}
	for _, sym in ipairs(tla_index(spec)) do
		local fits = (value_kind == "constant" and sym.kind == "Constant" and not assigned[sym.name])
			-- INVARIANT, NEXT ... take formulas, so operators with arguments don't fit
			or (value_kind == "definition" and sym.kind == "Definition" and not sym.has_args)
			or (value_kind == "operator" and sym.kind == "Definition")
			or (not value_kind and (sym.kind == "Definition" or sym.kind == "Constant"))
		if fits and not sym.std and not seen[sym.name] then
			seen[sym.name] = true
			table.insert(items, tla_symbol_item(sym, spec))
		end
	end
	callback(items)
end

-- TLC model config for a spec, written as Name.cfg next to Name.tla: the spec
-- formula (or INIT/NEXT), its CONSTANTS to give values to, and the type invariant
local function tla_cfg_lines(spec)
	local roles, consts = tla_spec_roles(spec)
	local lines = {}
	if roles.spec then
		table.insert(lines, "SPECIFICATION " .. roles.spec)
	elseif roles.init and roles.next then
		vim.list_extend(lines, { "INIT " .. roles.init, "NEXT " .. roles.next })
	else
		table.insert(lines, "SPECIFICATION Spec")
	end
	if #consts > 0 then
		vim.list_extend(lines, { "", "\\* Give each constant a value, e.g. N = 3 or Procs = {p1, p2}", "CONSTANTS" })
		for _, c in ipairs(consts) do
			table.insert(lines, "    " .. c .. " = ")
		end
	end
	if roles.typeok then
		vim.list_extend(lines, { "", "INVARIANT " .. roles.typeok })
	end
	return lines
end

-- Writes Name.cfg unless it already exists; returns its path and whether it's new
local function tla_create_cfg(spec)
	local cfg = spec:gsub("%.tla$", ".cfg")
	if vim.uv.fs_stat(cfg) then
		return cfg, false
	end
	vim.fn.writefile(tla_cfg_lines(spec), cfg)
	vim.notify("Created " .. vim.fn.fnamemodify(cfg, ":t"), vim.log.levels.INFO, { title = "TLA+" })
	return cfg, true
end

-- A spec is a module with a [][Next]_vars formula, or with Init and Next. Helper modules that
-- only define operators never get a .cfg on their own
local function tla_looks_like_spec(spec)
	local roles = tla_spec_roles(spec)
	return roles.spec or (roles.init and roles.next)
end

-- New .tla files (:e Name.tla, or an empty file made by Neo-tree or touch) get
-- their .cfg on the first save where the module looks like a spec
local function tla_watch_new_spec(buf)
	local file = vim.api.nvim_buf_get_name(buf)
	if file:match("_TTrace_") or file:find(tla_std_dir, 1, true) then
		return
	end
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = vim.api.nvim_create_augroup("TlaNewSpecCfg" .. buf, { clear = true }),
		buffer = buf,
		callback = function()
			local spec = vim.api.nvim_buf_get_name(buf)
			if vim.uv.fs_stat((spec:gsub("%.tla$", ".cfg"))) then
				return true -- someone made it already; stop watching
			end
			if tla_looks_like_spec(spec) then
				tla_create_cfg(spec)
				return true
			end
		end,
	})
end

return {
	tla_cfg_keywords = tla_cfg_keywords,
	tla_cfg_spec_file = tla_cfg_spec_file,
	tla_cfg_source = tla_cfg_source,
	tla_cfg_check = tla_cfg_check,
	tla_create_cfg = tla_create_cfg,
	tla_watch_new_spec = tla_watch_new_spec,
}
