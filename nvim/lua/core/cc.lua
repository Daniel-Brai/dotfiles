-- C / C++: the language standard follows the code in each file.
--
-- Every C/C++ buffer gets the newest standard it still compiles under:
--   C++23 (C23 for C) by default, C++26 when the file uses C++26-only features, and
--   lower when it uses something a newer standard removed (std::auto_ptr -> C++14,
--   std::result_of -> C++17, gets() -> C99, your own `bool` typedef -> C17 ...).
-- clangd gets that standard per file, :CRun / <leader>cr compiles with it, and the
-- statusline shows it.
--
-- Overrides, strongest first:
--   1. compile_commands.json / compile_flags.txt in the project: the build system decides
--      for clangd (detection still drives :CRun)
--   2. :CStd c++17 pins a project to a standard (writes a .clangd); :CStd auto unpins

local M = {}

M.latest = { c = "c23", cpp = "c++23" }

M.standards = {
	c = { "c89", "c99", "c11", "c17", "c23" },
	cpp = { "c++11", "c++14", "c++17", "c++20", "c++23", "c++26" },
}

local RANK = {}
for _, l in pairs(M.standards) do
	for i, s in ipairs(l) do
		RANK[s] = i
	end
end

-- { pattern, standard, reason }. Lua patterns, matched on code with comments removed and
-- string contents emptied. %f[%w_] = start of a word, %f[^%w_] = end of a word.
local RULES = {
	cpp = {
		-- needs a newer standard than the default
		newer = {
			{ "#%s*embed%f[^%w_]", "c++26", "#embed" },
			{ "%f[%w_]delete%s*%(%s*\"", "c++26", "= delete(\"reason\")" },
			{ "%.%.%.%[", "c++26", "pack indexing" },
			{ "inplace_vector", "c++26", "std::inplace_vector" },
			{ "<linalg>", "c++26", "<linalg>" },
			{ "<hazard_pointer>", "c++26", "<hazard_pointer>" },
			{ "<rcu>", "c++26", "<rcu>" },
			{ "<debugging>", "c++26", "<debugging>" },
			{ "<text_encoding>", "c++26", "<text_encoding>" },
			{ "views::concat", "c++26", "views::concat" },
			{ "submdspan", "c++26", "std::submdspan" },
			{ "contract_assert", "c++26", "contracts" },
		},
		-- removed from a later standard: cap at the last one that still has it
		removed = {
			{ "auto_ptr", "c++14", "std::auto_ptr (removed in C++17)" },
			{ "random_shuffle", "c++14", "std::random_shuffle (removed in C++17)" },
			{ "%f[%w_]bind[12]st%f[^%w_]", "c++14", "std::bind1st/bind2nd (removed in C++17)" },
			{ "%f[%w_]ptr_fun%f[^%w_]", "c++14", "std::ptr_fun (removed in C++17)" },
			{ "%f[%w_]mem_fun%f[^%w_]", "c++14", "std::mem_fun (removed in C++17)" },
			{ "%f[%w_]mem_fun_ref%f[^%w_]", "c++14", "std::mem_fun_ref (removed in C++17)" },
			{ "%f[%w_]unary_function%f[^%w_]", "c++14", "std::unary_function (removed in C++17)" },
			{ "%f[%w_]binary_function%f[^%w_]", "c++14", "std::binary_function (removed in C++17)" },
			{ "set_unexpected", "c++14", "std::set_unexpected (removed in C++17)" },
			{ "%f[%w_]register%s+[%a_]", "c++14", "`register` (removed in C++17)" },
			{ "%)%s*throw%s*%(%s*[%a_]", "c++14", "throw(type) specification (removed in C++17)" },
			{ "%f[%w_]result_of%f[^%w_]", "c++17", "std::result_of (removed in C++20)" },
			{ "is_literal_type", "c++17", "std::is_literal_type (removed in C++20)" },
			{ "raw_storage_iterator", "c++17", "std::raw_storage_iterator (removed in C++20)" },
			{ "get_temporary_buffer", "c++17", "std::get_temporary_buffer (removed in C++20)" },
			{ "uncaught_exception%f[^%w_]", "c++17", "std::uncaught_exception (removed in C++20)" },
			{ "%f[%w_]not[12]%s*%(", "c++17", "std::not1/not2 (removed in C++20)" },
			{ "%)%s*throw%s*%(%s*%)", "c++17", "throw() specification (removed in C++20)" },
			{ "declare_reachable", "c++20", "std::declare_reachable (removed in C++23)" },
			{ "declare_no_pointers", "c++20", "std::declare_no_pointers (removed in C++23)" },
			{ "get_pointer_safety", "c++20", "std::get_pointer_safety (removed in C++23)" },
		},
	},
	c = {
		newer = {},
		removed = {
			-- bool/true/false/nullptr/static_assert... became keywords in C23
			{ "typedef[^;]-%f[%w_]bool%s*;", "c17", "your own `bool` type (a keyword in C23)" },
			{ "#%s*define%s+bool%f[^%w_]", "c17", "#define bool (a keyword in C23)" },
			{ "#%s*define%s+true%f[^%w_]", "c17", "#define true (a keyword in C23)" },
			{ "#%s*define%s+false%f[^%w_]", "c17", "#define false (a keyword in C23)" },
			{ "enum[%s%w_]*{%s*false%s*,%s*true%f[^%w_]", "c17", "enum { false, true } (keywords in C23)" },
			{ "#%s*define%s+nullptr%f[^%w_]", "c17", "#define nullptr (a keyword in C23)" },
			-- K&R definition: f(a, b) newline `int a, b;` (removed in C23)
			{
				"%f[%w_][%a_][%w_]*%s*%(%s*[%a_][%w_]*[%s,%w_]*%)%s*\n%s*[%a_][%w_%s%*,%[%]]*;",
				"c17",
				"K&R-style function definition (removed in C23)",
			},
			{ "%f[%w_]gets%s*%(", "c99", "gets() (removed in C11)" },
			{ "\n%s*main%s*%(", "c89", "implicit int `main()` (removed in C99)" },
		},
	},
}

local function lang(ft)
	return ft == "c" and "c" or "cpp"
end

local function strip(src)
	src = src:gsub("'\\.'", "''"):gsub("'[^'\\\n]'", "''") -- char literals
	src = src:gsub('"[^"\n]*"', '""') -- string contents
	src = src:gsub("/%*.-%*/", " "):gsub("//[^\n]*", "") -- comments
	return "\n" .. src
end

--- Newest standard the code compiles under, and why it isn't the default
---@return string std, string|nil reason
function M.detect(src, language)
	local rules = RULES[language]
	local code = strip(src)
	local std, reason = M.latest[language], nil

	for _, r in ipairs(rules.newer) do
		if RANK[r[2]] > RANK[std] and code:find(r[1]) then
			std, reason = r[2], "uses " .. r[3]
		end
	end
	local raised = reason
	for _, r in ipairs(rules.removed) do
		if RANK[r[2]] < RANK[std] and code:find(r[1]) then
			std, reason = r[2], "uses " .. r[3]
		end
	end
	if raised and reason ~= raised then
		reason = reason .. ", but also " .. raised:gsub("^uses ", "") .. ": pick one with :CStd"
	end
	return std, reason
end


function M.root(buf)
	buf = buf or 0
	return vim.fs.root(buf, { ".clangd", "compile_commands.json", "compile_flags.txt", "CMakeLists.txt", "Makefile", ".git" })
		or vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
end

local MARKER = "# Managed by :CStd in Neovim"
local CPP_EXT = [[.*\.(cc|cpp|cxx|c\+\+|hh|hpp|hxx|h\+\+|ixx|cppm|tpp|ipp)$]]

local function read_clangd(root)
	local path = root .. "/.clangd"
	local f = io.open(path, "r")
	if not f then
		return nil, path
	end
	local text = f:read("*a")
	f:close()
	return text, path
end

--- Standards pinned in the project's .clangd: { c = "c11", cpp = "c++17" } (either may be nil)
function M.pinned(root)
	local pins = {}
	local text = read_clangd(root)
	if text then
		for std in text:gmatch("%-std=([%w%+]+)") do
			pins[std:find("++", 1, true) and "cpp" or "c"] = std
		end
	end
	return pins
end


--- { std, reason, pinned } for a buffer
function M.info(buf)
	buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
	local l = lang(vim.bo[buf].filetype)
	local pin = M.pinned(M.root(buf))[l]
	if pin then
		return { std = pin, pinned = true }
	end
	local src = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	local std, reason = M.detect(src, l)
	return { std = std, reason = reason }
end

function M.current_std(buf)
	return M.info(buf).std
end

local STD_MODULES = {
	std = {
		"The whole C++ standard library as one module: everything in namespace `std`",
		"(containers, algorithms, strings, `<print>`, `<format>`, ranges ...). It replaces",
		"`#include` of standard headers and is faster to compile than including them.",
		"",
		"Macros aren't exported: keep `#include <cassert>` for `assert`, `<cerrno>` for `errno`,",
		"`<cstdio>` for `EOF`/`stdout`, `<climits>` for `INT_MAX` ... next to the import.",
		"Need C names unqualified (`printf`, `size_t`)? Use `import std.compat;`.",
	},
	["std.compat"] = {
		"Everything in `import std;` plus the C library names in the global namespace",
		"(`printf`, `size_t`, `memcpy` ...), for code written against `<stdio.h>` and friends.",
	},
}

--- K: clangd has no hover for module imports, so describe them here; anything else is LSP hover
function M.hover()
	local line = vim.api.nvim_get_current_line()
	local name = line:match("^%s*export%s+import%s+([%w_.:]+)%s*;") or line:match("^%s*import%s+([%w_.:]+)%s*;")
	local header = line:match("^%s*import%s+(<[^>]+>)%s*;") or line:match('^%s*import%s+("[^"]+")%s*;')
	if not name and not header then
		return vim.lsp.buf.hover()
	end
	local std = M.current_std(0)
	local md
	if header then
		md = {
			("### header unit `%s`"):format(header),
			"",
			"Imports a header as a module (its declarations *and* macros). Legal C++20, but the",
			"least supported part of modules: Clang calls it experimental and CMake can't build it.",
			"",
			"Instead: `import std;` for the standard library, or `#include` for anything else.",
		}
	else
		local modules = require("core.cc_modules")
		local root = M.root(0)
		local full = name
		if name:sub(1, 1) == ":" then
			local own = modules.parse(vim.api.nvim_buf_get_lines(0, 0, 300, false)).module
			full = (own and own:match("^[^:]+") or "") .. name
		end
		local found = modules.lookup(full, root)
		md = { ("### %s `%s` · %s"):format(name:find(":") and "module partition" or "module", full, std:upper()), "" }
		if STD_MODULES[full] then
			vim.list_extend(md, STD_MODULES[full])
		end
		if found then
			vim.list_extend(md, { "", "---", "Interface: `" .. vim.fn.fnamemodify(found.src, found.is_std and ":~" or ":.") .. "`" })
			for _, impl in ipairs(found.impls) do
				table.insert(md, "Implementation: `" .. vim.fn.fnamemodify(impl, ":.") .. "`")
			end
			table.insert(md, "clangd reads a Clang-built copy (cached in `~/.cache/nvim/cc-modules`)")
		else
			vim.list_extend(md, { "No `export module " .. full .. ";` found under `" .. vim.fn.fnamemodify(root, ":~") .. "`." })
		end
	end
	vim.lsp.util.open_floating_preview(md, "markdown", { border = "rounded", focus_id = "cc-import-hover" })
end

local function compile_flags(root)
	local path = root .. "/compile_flags.txt"
	if not vim.uv.fs_stat(path) then
		return nil
	end
	return vim.tbl_filter(function(l)
		return vim.trim(l) ~= ""
	end, vim.fn.readfile(path))
end

-- Tell clangd how to compile this file (clangd's compilationDatabaseChanges extension): the
-- detected standard, plus -fmodule-file=... for every module it imports.
-- compile_commands.json (CMake ...) wins: the build system knows best, modules included.
local function send_to_clangd(buf, std)
	local root = M.root(buf)
	if vim.uv.fs_stat(root .. "/compile_commands.json") then
		return
	end
	local file = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
	local cpp = vim.bo[buf].filetype ~= "c"
	local base = compile_flags(root)
	local command = { cpp and "clang++" or "clang" }
	vim.list_extend(command, base or { "-std=" .. std })
	local uses_modules = false
	if cpp then
		local mstd = std
		for _, f in ipairs(base or {}) do
			mstd = f:match("^%-std=(.+)") or mstd
		end
		local flags
		flags, uses_modules = require("core.cc_modules").clangd_flags(vim.api.nvim_buf_get_lines(buf, 0, -1, false), root, mstd, base, function()
			if vim.api.nvim_buf_is_valid(buf) then
				send_to_clangd(buf, std)
			end
		end)
		vim.list_extend(command, flags)
		if uses_modules then
			vim.schedule(function()
				require("core.cc_modules").preload_impls(vim.api.nvim_buf_get_lines(buf, 0, -1, false), root)
			end)
		end
	end
	if base and not uses_modules then
		return -- compile_flags.txt already says it all
	end
	table.insert(command, file)
	for _, client in ipairs(vim.lsp.get_clients({ name = "clangd", bufnr = buf })) do
		client:notify("workspace/didChangeConfiguration", {
			settings = {
				compilationDatabaseChanges = {
					[file] = { workingDirectory = vim.fs.dirname(file), compilationCommand = command },
				},
			},
		})
	end
end

-- What clangd needs to hear about again when it changes: imports and the module declaration
local function module_key(buf)
	if vim.bo[buf].filetype ~= "cpp" then
		return ""
	end
	local info = require("core.cc_modules").parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
	return (info.module or "") .. "|" .. table.concat(info.imports, ",")
end

function M.refresh(buf, force)
	if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_name(buf) == "" then
		return
	end
	local info = M.info(buf)
	local prev = vim.b[buf].cc_std
	local key = module_key(buf)
	if not force and prev == info.std and vim.b[buf].cc_modules == key then
		return
	end
	vim.b[buf].cc_modules = key
	vim.b[buf].cc_std = info.std
	vim.b[buf].cc_std_pinned = info.pinned or false
	send_to_clangd(buf, info.std)
	if prev and prev ~= info.std then
		local msg = ("%s → %s"):format(prev, info.std)
		vim.notify(info.reason and (msg .. " (" .. info.reason .. ")") or msg, vim.log.levels.INFO, { title = "C/C++ standard" })
	end
	pcall(function()
		require("lualine").refresh()
	end)
end

--- Statusline text, e.g. "C++23" or "C11 (pinned)"
function M.statusline()
	local std = vim.b.cc_std
	if not std then
		return ""
	end
	return std:gsub("^c", "C"):gsub("^gnu", "GNU") .. (vim.b.cc_std_pinned and " (pinned)" or "")
end


-- After a pin changes: clangd caches .clangd for a while, so restart it (LspAttach then
-- sends each buffer's standard again)
local function refresh_all()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		local ft = vim.bo[b].filetype
		if ft == "c" or ft == "cpp" then
			M.refresh(b, true)
		end
	end
	if #vim.lsp.get_clients({ name = "clangd" }) > 0 then
		if not pcall(vim.cmd, "lsp restart clangd") then
			pcall(vim.cmd, "LspRestart clangd")
		end
	end
end

function M.set_std(std, buf)
	buf = buf or 0
	local root = M.root(buf)
	local text, path = read_clangd(root)
	local managed = text == nil or text:find(MARKER, 1, true)

	if std == "auto" then
		if text and managed then
			os.remove(path)
			vim.notify("Unpinned: the standard follows the code again", vim.log.levels.INFO, { title = "C/C++ standard" })
		elseif text then
			vim.notify(path .. " was not written by :CStd, so it's left alone", vim.log.levels.WARN)
		end
		return refresh_all()
	end

	if not managed then
		vim.notify(
			path .. " was not written by :CStd, so it's left alone.\nAdd this to it yourself:\n"
				.. "CompileFlags: { Remove: [-std=*], Add: [-std=" .. std .. "] }",
			vim.log.levels.WARN
		)
		return
	end

	local pins = M.pinned(root)
	pins[std:find("++", 1, true) and "cpp" or "c"] = std
	local lines = { MARKER .. ". Pins the standard; :CStd auto removes this file." }
	if pins.c then
		vim.list_extend(lines, { "---", "If:", [[  PathMatch: .*\.c$]], "CompileFlags:", "  Remove: [-std=*]", "  Add: [-std=" .. pins.c .. "]" })
	end
	if pins.cpp then
		vim.list_extend(lines, { "---", "If:", "  PathMatch: " .. CPP_EXT, "CompileFlags:", "  Remove: [-std=*]", "  Add: [-std=" .. pins.cpp .. "]" })
	end
	vim.fn.writefile(lines, path)
	vim.notify("Pinned " .. std .. " in " .. path, vim.log.levels.INFO, { title = "C/C++ standard" })
	refresh_all()
end

function M.pick_std(buf)
	buf = buf or 0
	local l = lang(vim.bo[buf].filetype)
	local items = vim.list_extend({ "auto" }, M.standards[l])
	vim.ui.select(items, { prompt = "Standard (now " .. M.current_std(buf) .. ")" }, function(choice)
		if choice then
			M.set_std(choice, buf)
		end
	end)
end


-- Compile the current file on its own (handy for exercises / single-file programs)
-- opts.sanitize = false builds without ASan/UBSan (for valgrind)
function M.build_cmd(buf, opts)
	buf = buf or 0
	opts = opts or {}
	local file = vim.api.nvim_buf_get_name(buf)
	local is_c = vim.bo[buf].filetype == "c"
	local std = M.current_std(buf)
	local out_dir = vim.fn.stdpath("cache") .. "/cc-run"
	vim.fn.mkdir(out_dir, "p")
	local out = out_dir .. "/" .. vim.fn.fnamemodify(file, ":t:r")

	local cmd = {
		is_c and "gcc" or "g++", "-std=" .. std, "-g", "-fno-omit-frame-pointer",
		"-Wall", "-Wextra", "-Wpedantic", "-Wshadow", "-Wconversion", "-Wformat=2", "-Wnull-dereference",
	}
	if opts.sanitize ~= false then
		table.insert(cmd, "-fsanitize=address,undefined")
	end
	if is_c then
		vim.list_extend(cmd, { "-Wstrict-prototypes", "-Wvla" })
	else
		vim.list_extend(cmd, { "-Wnon-virtual-dtor", "-Woverloaded-virtual", "-D_GLIBCXX_ASSERTIONS" })
	end
	-- Modules it imports (std, std.compat, the project's own): their sources go first, in
	-- dependency order. GCC writes gcm.cache/ in the working directory, so builds run in out_dir.
	if not is_c then
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		vim.list_extend(cmd, require("core.cc_modules").gcc_args(lines, file, M.root(buf)))
	end
	vim.list_extend(cmd, { file, "-o", out })
	return cmd, out, out_dir
end

function M.build(run)
	if vim.bo.modified then
		vim.cmd("silent write")
	end
	local cmd, out, build_dir = M.build_cmd(0)
	local esc = vim.fn.shellescape
	local compile = "(cd " .. esc(build_dir) .. " && " .. table.concat(vim.tbl_map(esc, cmd), " ") .. ")"
	local shell = compile .. (run and (" && " .. esc(out)) or (" && echo 'Built " .. out .. "'"))
	local cwd = vim.fn.expand("%:p:h")
	vim.cmd("botright 15split")
	vim.cmd("enew")
	vim.fn.jobstart({ vim.o.shell, "-c", shell }, { term = true, cwd = cwd })
	vim.cmd("startinsert")
end


-- Buffer-local setup, called from after/ftplugin/{c,cpp}.lua
function M.attach(buf)
	buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
	end
	-- build/run/test keys come from cc_build (project-aware, falls back to this file alone)
	require("core.cc_build").attach(buf)
	map("<leader>cs", function() M.pick_std(buf) end, "C/C++: pin a [S]tandard")
	map("<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", "C/C++: switch source/[H]eader")
	map("K", M.hover, "Hover (also explains `import` lines)")
	map("<leader>ci", "<cmd>LspClangdShowSymbolInfo<cr>", "C/C++: symbol [I]nfo")

	local group = vim.api.nvim_create_augroup("cc-std-" .. buf, { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave", "TextChanged" }, {
		group = group,
		buffer = buf,
		callback = function()
			M.refresh(buf)
			require("core.cc_modules").check_style(buf)
		end,
	})
	M.refresh(buf)
	require("core.cc_modules").check_style(buf)
end

-- clangd may attach after the buffer was first scanned: send it the standard then
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("cc-std-lsp", { clear = true }),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client.name == "clangd" then
			M.refresh(ev.buf, true)
		end
	end,
})

vim.api.nvim_create_user_command("CStd", function(o)
	if o.args == "" then
		local info = M.info(0)
		local how = info.pinned and "pinned with :CStd" or (info.reason or "newest standard, nothing older needed")
		vim.notify(info.std .. " (" .. how .. ")", vim.log.levels.INFO, { title = "C/C++ standard" })
	else
		M.set_std(o.args)
	end
end, {
	nargs = "?",
	desc = "Show the C/C++ standard, pin one (:CStd c++17) or unpin (:CStd auto)",
	complete = function()
		return vim.list_extend(vim.list_extend({ "auto" }, M.standards.c), M.standards.cpp)
	end,
})

require("core.cc_modules").setup()

return M
