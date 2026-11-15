-- SANY (the TLA+ parser in tla2tools.jar): syntax, unknown names, arity and missing
-- modules, without model checking. Runs from the spec's folder so local EXTENDS resolve.
local function sany_parse(output, bufnr)
	local severities = vim.diagnostic.severity
	local module = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t:r")
	local lines = vim.split(output, "\n")
	local diagnostics, seen = {}, {}

	-- SANY counts columns in characters; diagnostics want bytes
	local function byte_col(lnum, col)
		local text = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
		local ok, b = pcall(vim.str_byteindex, text, "utf-32", col - 1, false)
		return ok and b or col - 1
	end

	local function add(l, c, el, ec, message, severity)
		local key = table.concat({ l, c, message }, ":")
		if seen[key] then
			return
		end
		seen[key] = true
		local col = byte_col(l - 1, c)
		local end_col = byte_col(el - 1, ec + 1)
		if el == l and end_col < col then
			end_col = col
		end
		table.insert(diagnostics, {
			lnum = l - 1,
			col = col,
			end_lnum = el - 1,
			end_col = end_col,
			severity = severity,
			message = message,
			source = "sany",
		})
	end

	local severity = severities.ERROR
	for i, line in ipairs(lines) do
		if line:match("^Semantic errors:") then
			severity = severities.ERROR
		elseif line:match("^Semantic warnings:") then
			severity = severities.WARN
		end

		local l, c, el, ec, mod = line:match("^line (%d+), col (%d+) to line (%d+), col (%d+) of module (%S+)")
		if l then
			local message = {}
			for j = i + 1, #lines do
				if lines[j] == "" and #message > 0 then
					break
				elseif lines[j] ~= "" then
					table.insert(message, lines[j])
				end
			end
			if mod == module then
				add(tonumber(l), tonumber(c), tonumber(el), tonumber(ec), table.concat(message, " "), severity)
			else
				add(1, 1, 1, 1, "In module " .. mod .. ": " .. table.concat(message, " "), severity)
			end
		end

		local pl, pc = line:match('^Encountered ".-" at line (%d+), column (%d+)')
		if pl then
			local expecting = (lines[i - 1] or ""):match("^Was expecting .*")
			local message = vim.trim(line:gsub(" at line %d+, column %d+", ""))
			add(tonumber(pl), tonumber(pc), tonumber(pl), tonumber(pc), (expecting and expecting .. ". " or "") .. message, severities.ERROR)
		end

		local cl, cc, cel, cec = line:match("^%s*Precedence conflict .- in block line (%d+), col (%d+) to line (%d+), col (%d+)")
		if cl then
			local message = vim.trim(line:gsub(" in block line %d+, col %d+ to line %d+, col %d+ of module %S+", ""))
			add(tonumber(cl), tonumber(cc), tonumber(cel), tonumber(cec), message .. " (add parentheses)", severities.ERROR)
		end

		local ll, lc, rest = line:match("^Lexical error at line (%d+), column (%d+)%.%s*(.*)")
		if ll then
			add(tonumber(ll), tonumber(lc), tonumber(ll), tonumber(lc), "Lexical error. " .. rest, severities.ERROR)
		end

		local missing = line:match("^File does not exist: (%S+)")
		if missing then
			local name = vim.fn.fnamemodify(missing, ":t:r")
			local at = 1
			for n, text in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
				if text:match("^%s*EXTENDS") or text:match("INSTANCE") then
					if text:match("%f[%w_]" .. vim.pesc(name) .. "%f[^%w_]") then
						at = n
						break
					end
				end
			end
			add(at, 1, at, 1, "Module " .. name .. " not found (no " .. name .. ".tla next to this spec or in the standard modules)", severities.ERROR)
		end
	end

	if #diagnostics == 0 and (output:match("Fatal errors") or output:match("%*%*%* Errors")) then
		add(1, 1, 1, 1, "SANY could not parse this spec; run :TlaCheck to see its full output", severities.ERROR)
	end

	-- TLA+ has no forward references: say where an "unknown" name is declared
	-- later in the file, or that it isn't declared at all
	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local function defines(text, name)
		return text:match("^" .. vim.pesc(name) .. "[^=]-==") or text:match("^" .. vim.pesc(name) .. ".-≜")
	end
	-- SANY's level errors in plain words. Levels: constant, state (variables),
	-- action (primes, UNCHANGED), temporal ([], <>, ~>, WF/SF)
	local level_hints = {
		{ "assumptions must be level 0", "ASSUME can only talk about constants, not variables, primes or temporal operators" },
		{ "operator '", "Only a state expression can be primed; this one already has a prime or a temporal operator" },
		{ "operator %$SquareAct", "In [][A]_v, A must be an action; it can't contain [] or <>" },
		{ "operator %$AngleAct", "In <<A>>_v, A must be an action; it can't contain [] or <>" },
		{ "has both temporal formula and action", "A formula can't mix temporal operators ([], <>) with primed variables; put the action inside [][...]_vars" },
		{ "Level error", "A variable, prime or temporal operator is used where it isn't allowed" },
	}
	for _, d in ipairs(diagnostics) do
		for _, h in ipairs(level_hints) do
			if d.message:find(h[1]) and (d.message:find("Level error") or d.message:find("temporal formula and action")) then
				d.message = h[2] .. ". (SANY: " .. d.message .. ")"
				break
			end
		end
		local name = d.message:match("^Unknown operator: `([%a_][%w_]*)'")
		-- An operator that calls itself needs RECURSIVE before its definition
		if name then
			for n = d.lnum + 1, 1, -1 do
				local text = buf_lines[n] or ""
				if text:match("^[%a_]") then
					if defines(text, name) then
						d.message = ("%s calls itself, so it needs RECURSIVE %s(...) above its definition (one _ per argument, e.g. RECURSIVE %s(_))"):format(name, name, name)
						name = nil
					end
					break
				end
			end
		end
		if name then
			local word = "%f[%w_]" .. vim.pesc(name) .. "%f[^%w_]"
			local hint
			for n = d.lnum + 2, #buf_lines do
				local text = buf_lines[n]
				local kind = text:match("^%s*(VARIABLES?)%s") or text:match("^%s*(CONSTANTS?)%s")
				if kind and text:match(word) then
					hint = ("%s is used before it is declared (%s on line %d). Move that line above line %d"):format(name, kind, n, d.lnum + 1)
				elseif text:match("^" .. vim.pesc(name) .. "[^=]-==") or text:match("^" .. vim.pesc(name) .. ".-≜") then
					hint = ("%s is used before it is defined (line %d). Move the definition above line %d"):format(name, n, d.lnum + 1)
				end
				if hint then
					break
				end
			end
			d.message = hint or ("%s is not declared. Add it to VARIABLES or CONSTANTS, or define it with %s == ..."):format(name, name)
		end
	end
	return diagnostics
end

return {
	cmd = "sh",
	args = {
		"-c",
		'cd "$(dirname "$1")" && exec java -cp "$2" tla2sany.SANY "$(basename "$1")"',
		"sany",
		function()
			return vim.api.nvim_buf_get_name(0)
		end,
		vim.fn.expand("~/.local/share/tla/tla2tools.jar"),
	},
	stdin = false,
	append_fname = false,
	stream = "both",
	ignore_exitcode = true,
	parser = sany_parse,
}
