-- :TlaPdf and :TlaTex

-- :TlaPdf and :TlaTex typeset the spec with tla2tex (part of tla2tools.jar) and
-- pdflatex. The .pdf and .tex land next to the spec
local tla_jar = vim.fn.expand("~/.local/share/tla/tla2tools.jar")
local tla_pdf_live = {} -- buffers whose PDF rebuilds on save
local tla_pdf_running = {}

-- tla2tex only reads ASCII, so Unicode specs go through tlauc (cargo install tlauc)
-- into a temporary copy first; the spec itself is never rewritten
local function tla_ascii_source(file, name)
	local text = table.concat(vim.fn.readfile(file), "\n")
	if not text:find("[\128-\255]") then
		return file
	end
	local tmp = vim.fn.tempname()
	vim.fn.mkdir(tmp, "p")
	local ascii = tmp .. "/" .. name .. ".tla"
	local res = vim.system({ "tlauc", "--ascii", "--force", file, "--output", ascii }, { text = true }):wait()
	if res.code ~= 0 then
		return nil, vim.trim((res.stderr or "") .. (res.stdout or ""))
	end
	return ascii
end

local function tla_typeset(buf, on_done)
	if tla_pdf_running[buf] then
		return
	end
	local file = vim.api.nvim_buf_get_name(buf)
	local dir, name = vim.fn.fnamemodify(file, ":h"), vim.fn.fnamemodify(file, ":t:r")
	local source, err = tla_ascii_source(file, name)
	if not source then
		vim.notify("tlauc couldn't convert to ASCII:\n" .. err, vim.log.levels.ERROR, { title = "TLA+ PDF" })
		return
	end
	local base = dir .. "/" .. name
	local pdf, tex = base .. ".pdf", base .. ".tex"
	local started = os.time()
	tla_pdf_running[buf] = true
	vim.system({
		"java", "-cp", tla_jar, "tla2tex.TLA", "-shade", "-nops",
		"-latexCommand", "pdflatex", "-metadir", dir, vim.fn.fnamemodify(source, ":t"),
	}, { cwd = vim.fn.fnamemodify(source, ":h"), text = true }, function(res)
		vim.schedule(function()
			tla_pdf_running[buf] = nil
			os.remove(base .. ".aux")
			os.remove(base .. ".log")
			if source ~= file then
				vim.fn.delete(vim.fn.fnamemodify(source, ":h"), "rf")
			end
			-- tla2tex's exit code is unreliable; a freshly written PDF means success
			local stat = vim.uv.fs_stat(pdf)
			if stat and stat.mtime.sec >= started then
				on_done(pdf, tex)
			else
				-- Keep tla2tex's message, drop the Java stack trace
				local lines = vim.tbl_filter(function(l)
					return l ~= "" and not l:match("^%s+at ") and not l:match("^Exception in thread")
				end, vim.split((res.stdout or "") .. "\n" .. (res.stderr or ""), "\n"))
				local tail = table.concat(vim.list_slice(lines, math.max(1, #lines - 5)), "\n")
				vim.notify("tla2tex failed:\n" .. tail, vim.log.levels.ERROR, { title = "TLA+ PDF" })
			end
		end)
	end)
end

local function tla_pdf()
	local buf = vim.api.nvim_get_current_buf()
	vim.cmd("silent update")
	tla_typeset(buf, function(pdf)
		tla_pdf_live[buf] = true
		-- Evince reloads by itself when later saves rebuild the file
		vim.ui.open(pdf)
	end)
end

local function tla_tex()
	vim.cmd("silent update")
	tla_typeset(vim.api.nvim_get_current_buf(), function(_, tex)
		vim.cmd("tabedit " .. vim.fn.fnameescape(tex))
		vim.bo.readonly = true
	end)
end

return {
	tla_pdf = tla_pdf,
	tla_tex = tla_tex,
	tla_typeset = tla_typeset,
	tla_pdf_live = tla_pdf_live,
}
