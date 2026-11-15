-- Reads specs: the symbol index behind completion, go to definition, hover
-- and the .cfg tools

-- Symbol index for a spec: VARIABLES, CONSTANTS and definitions with their exact
-- positions, from the spec itself (live buffer text when it's open), local modules
-- it EXTENDS or INSTANCEs, and the standard modules inside tla2tools.jar.
-- Completion, go to definition, hover and the .cfg checker all read from it
local tla_std_dir = vim.fn.stdpath("cache") .. "/tla-std"

local function tla_std_module(name)
	local path = tla_std_dir .. "/" .. name .. ".tla"
	if not vim.uv.fs_stat(tla_std_dir .. "/.extracted") then
		vim.fn.mkdir(tla_std_dir, "p")
		local jar = vim.fn.expand("~/.local/share/tla/tla2tools.jar")
		vim.system({ "unzip", "-o", "-q", "-j", jar, "tla2sany/StandardModules/*.tla", "-d", tla_std_dir }):wait()
		vim.fn.writefile({}, tla_std_dir .. "/.extracted")
	end
	return vim.uv.fs_stat(path) and path or nil
end

local function tla_file_lines(path)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == path then
			return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		end
	end
	return vim.uv.fs_stat(path) and vim.fn.readfile(path) or {}
end

-- The definition text: its first line plus the indented lines that follow
local function tla_def_text(lines, lnum)
	local out = { lines[lnum] }
	for n = lnum + 1, math.min(#lines, lnum + 15) do
		local l = lines[n]
		if l:match("^%S") or l:match("^====") then
			break
		end
		table.insert(out, l)
	end
	while #out > 1 and out[#out]:match("^%s*$") do
		table.remove(out)
	end
	return table.concat(out, "\n")
end

local function tla_parse_module(path, lines, imported, std, symbols, extends)
	local module = vim.fn.fnamemodify(path, ":t:r")
	local section
	for lnum, line in ipairs(lines) do
		local code = line:gsub("\\%*.*$", "")
		local rest, start
		local kw, decl = code:match("^(VARIABLES?)(.*)$")
		if not kw then
			kw, decl = code:match("^(CONSTANTS?)(.*)$")
		end
		if kw then
			section = kw:match("^V") and "Variable" or "Constant"
			rest, start = decl, #kw
		elseif section and code:match("^%s+%S") and not code:match("==") then
			rest, start = code, 0
		else
			section = nil
		end
		if rest then
			-- Blank out argument lists like Max(_) without moving columns
			local stripped = rest:gsub("%b()", function(m)
				return (" "):rep(#m)
			end)
			for pos, name in stripped:gmatch("()([%a_][%w_]*)") do
				table.insert(symbols, {
					name = name, kind = section, path = path, module = module, lnum = lnum,
					col = start + pos - 1, signature = name, doc = line, std = std,
				})
			end
		end

		local lead = code:match("^%s*")
		local body = code:sub(#lead + 1)
		local prefix = body:match("^LOCAL%s+") or body:match("^THEOREM%s+") or ""
		local name, args = body:sub(#prefix + 1):match("^([%a_][%w_]*)(.-)==")
		if not name then
			name, args = body:sub(#prefix + 1):match("^([%a_][%w_]*)(.-)≜")
		end
		args = args and vim.trim(args)
		if name and (args == "" or args:match("^%b()$") or args:match("^%b[]$")) then
			local is_let = #lead > 0
			-- Other modules only export their top-level, non-LOCAL definitions
			if not (imported and (is_let or prefix:match("^LOCAL"))) then
				table.insert(symbols, {
					name = name, kind = is_let and "LET definition" or "Definition", path = path, module = module,
					lnum = lnum, col = #lead + #prefix, signature = name .. args, doc = tla_def_text(lines, lnum),
					std = std, has_args = args ~= "",
				})
			end
		end

		-- LET written inline: Foo == LET d == ... IN ...
		if not imported then
			for pos, let_name, let_args in code:gmatch("LET%s+()([%a_][%w_]*)(.-)==") do
				let_args = vim.trim(let_args)
				if let_args == "" or let_args:match("^%b()$") then
					table.insert(symbols, {
						name = let_name, kind = "LET definition", path = path, module = module, lnum = lnum,
						col = pos - 1, signature = let_name .. let_args, doc = line, std = std, has_args = let_args ~= "",
					})
				end
			end
		end

		local ext = code:match("^EXTENDS%s+(.*)")
		if ext then
			for m in ext:gmatch("[%a_][%w_]*") do
				table.insert(extends, m)
			end
		end
		local inst = code:match("INSTANCE%s+([%a_][%w_]*)")
		if inst then
			table.insert(extends, inst)
		end
	end
end

local tla_index_cache = {}

local function tla_index(path)
	local tick = 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == path then
			tick = vim.api.nvim_buf_get_changedtick(buf)
		end
	end
	local cached = tla_index_cache[path]
	if cached and cached.tick == tick and vim.uv.now() - cached.time < 2000 then
		return cached.symbols
	end
	local symbols, seen = {}, {}
	local function visit(p, imported, std)
		if seen[p] then
			return
		end
		seen[p] = true
		local extends = {}
		tla_parse_module(p, tla_file_lines(p), imported, std, symbols, extends)
		for _, m in ipairs(extends) do
			local here = vim.fn.fnamemodify(p, ":h") .. "/" .. m .. ".tla"
			if not std and vim.uv.fs_stat(here) then
				visit(here, true, false)
			else
				local sp = tla_std_module(m)
				if sp then
					visit(sp, true, true)
				end
			end
		end
	end
	visit(path, false, false)
	tla_index_cache[path] = { tick = tick, time = vim.uv.now(), symbols = symbols }
	return symbols
end

-- What the .cfg checker needs: definitions and constants, standard modules left out
local function tla_spec_names(spec)
	local names = { defs = {}, consts = {} }
	for _, sym in ipairs(tla_index(spec)) do
		local file = vim.fn.fnamemodify(sym.path, ":t")
		if sym.std then
			-- skip
		elseif sym.kind == "Definition" then
			names.defs[sym.name] = names.defs[sym.name] or { file = file, text = sym.doc }
		elseif sym.kind == "Constant" then
			names.consts[sym.name] = names.consts[sym.name] or file
		end
	end
	return names
end

-- The names a .cfg needs, found by shape so prefixed ones work too (TCSpec, TCInit):
-- the spec is the definition containing [][Next]_vars, init/next/type invariant are
-- the definitions named Init, Next, TypeOK or ending in them. Exact names win
local function tla_spec_roles(spec)
	local roles, consts = {}, {}
	local function pick(role, name, exact)
		if not roles[role] or (name == exact and roles[role] ~= exact) then
			roles[role] = name
		end
	end
	for _, sym in ipairs(tla_index(spec)) do
		if sym.path == spec then
			local name = sym.name
			if sym.kind == "Definition" and not sym.has_args then
				local body = sym.doc:gsub("%s+", "")
				if body:find("[][", 1, true) or body:find("□[", 1, true) then
					pick("spec", name, "Spec")
				end
				if name:match("Init$") then
					pick("init", name, "Init")
				elseif name:match("Next$") then
					pick("next", name, "Next")
				elseif name:match("Type[Oo][Kk]$") or name:match("TypeInvariant$") then
					pick("typeok", name, "TypeOK")
				end
			elseif sym.kind == "Constant" and not vim.tbl_contains(consts, name) then
				table.insert(consts, name)
			end
		end
	end
	return roles, consts
end

return {
	tla_std_dir = tla_std_dir,
	tla_std_module = tla_std_module,
	tla_file_lines = tla_file_lines,
	tla_index = tla_index,
	tla_spec_names = tla_spec_names,
	tla_spec_roles = tla_spec_roles,
}
