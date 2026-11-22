-- C++20 modules outside a build system: clangd support and single-file builds.
--
-- clangd is Clang and can't read the module files GCC writes, and outside CMake nothing builds
-- modules for it. So for every `import X;` in a file this finds X's source (libstdc++'s module
-- sources for std / std.compat, or `export module X;` anywhere in the project, partitions
-- included), precompiles it with clang++ into ~/.cache/nvim/cc-modules (dependencies first)
-- and gives clangd -fmodule-file=X=<file>. Saving a module source rebuilds what depends on it.
-- GCC builds (:CRun, <leader>cr) get the same sources in dependency order instead.
--
-- #include still works everywhere. What `import std;` makes pointless is including the standard
-- headers it already provides (<vector>, <string> ...): that gets a hint. Macro headers
-- (<cassert>, <cerrno>, <climits> ...) are still needed because modules don't export macros, and
-- third-party/project headers have no module, so those are fine. So is anything in a module's
-- global fragment (`module;` ... `export module x;`), which exists for exactly that.

local M = {}

local MODULE_EXT = { cppm = true, ixx = true, mpp = true, cxxm = true, ccm = true }
local SOURCE_GLOBS = { "*.cppm", "*.ixx", "*.mpp", "*.cxxm", "*.ccm", "*.cpp", "*.cc", "*.cxx" }
local CACHE = vim.fn.stdpath("cache") .. "/cc-modules"

local function mtime(p)
	local s = vim.uv.fs_stat(p)
	return s and (s.mtime.sec + s.mtime.nsec / 1e9) or nil
end

-- readfile's limit: a positive `max` reads the first lines (a negative one would mean the last)
local function read(path, max)
	local ok, lines = pcall(function()
		return max and vim.fn.readfile(path, "", max) or vim.fn.readfile(path)
	end)
	return ok and lines or {}
end

--- { module = "a.b" | "a:part" | nil, interface = bool, imports = { "x", ":part", ... } }
function M.parse(lines)
	local info = { imports = {} }
	for _, l in ipairs(lines) do
		if not info.module then
			local name = l:match("^%s*export%s+module%s+([%w_.:]+)%s*;")
			if name then
				info.module, info.interface = name, true
			else
				name = l:match("^%s*module%s+([%w_.:]+)%s*;")
				if name then
					info.module, info.interface = name, false
				end
			end
		end
		local imp = l:match("^%s*export%s+import%s+([%w_.:]+)%s*;") or l:match("^%s*import%s+([%w_.:]+)%s*;")
		if imp then
			table.insert(info.imports, imp)
		end
	end
	return info
end

-- Full module names this unit needs: partitions get their module's name; an implementation
-- unit (`module m;`) implicitly imports its own interface.
local function needed(info)
	local primary = info.module and info.module:match("^[^:]+")
	local names = {}
	for _, imp in ipairs(info.imports) do
		table.insert(names, imp:sub(1, 1) == ":" and ((primary or "") .. imp) or imp)
	end
	if info.module and not info.interface and not info.module:find(":") then
		table.insert(names, info.module)
	end
	return names
end

local std_cache
--- libstdc++'s module sources, from the manifest GCC ships: { std = path, ["std.compat"] = path }
function M.std_sources()
	if std_cache == nil then
		std_cache = false
		local json = vim.trim(vim.fn.system({ "g++", "-print-file-name=libstdc++.modules.json" }))
		local ok, data = pcall(vim.json.decode, table.concat(read(json), "\n"))
		if ok and type(data) == "table" then
			local sources = {}
			for _, m in ipairs(data.modules or {}) do
				sources[m["logical-name"]] = vim.fs.normalize(vim.fn.resolve(vim.fs.dirname(json) .. "/" .. m["source-path"]))
			end
			std_cache = sources.std and sources or false
		end
	end
	return std_cache or nil
end

local toolchain_key
local function toolchain()
	if not toolchain_key then
		local clang = vim.trim(vim.fn.system({ "clang++", "-dumpversion" }))
		local gcc = vim.trim(vim.fn.system({ "g++", "-dumpversion" }))
		toolchain_key = ("clang%s-libstdc++%s"):format(clang, gcc)
	end
	return toolchain_key
end

-- Which project file declares each module (interfaces and implementation units)
local indexes = {}
function M.index(root)
	if indexes[root] then
		return indexes[root]
	end
	local idx = { interfaces = {}, impls = {} }
	local cmd = { "grep", "-rlE" }
	for _, d in ipairs({ "build", "builddir", ".git", "_deps", ".cache", "node_modules" }) do
		table.insert(cmd, "--exclude-dir=" .. d)
	end
	for _, g in ipairs(SOURCE_GLOBS) do
		table.insert(cmd, "--include=" .. g)
	end
	vim.list_extend(cmd, { "^[[:space:]]*(export[[:space:]]+)?module[[:space:]]+[[:alnum:]_.:]+[[:space:]]*;", root })
	local res = vim.system(cmd, { text = true }):wait(5000)
	for _, f in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
		local info = M.parse(read(f, 300))
		if info.module then
			if info.interface then
				idx.interfaces[info.module] = f
			else
				idx.impls[info.module] = idx.impls[info.module] or {}
				table.insert(idx.impls[info.module], f)
			end
		end
	end
	indexes[root] = idx
	return idx
end

function M.invalidate(root)
	indexes[root] = nil
end

local function source_of(name, root)
	local std = M.std_sources()
	if std and std[name] then
		return std[name], true
	end
	return M.index(root).interfaces[name], false
end

local function pcm_path(name, std, root, is_std)
	local scope = is_std and "std" or vim.fn.sha256(root):sub(1, 12)
	return ("%s/%s/%s/%s/%s.pcm"):format(CACHE, toolchain(), std, scope, (name:gsub(":", "-")))
end

local parse_cache = {}
local function deps_of(src)
	local t = mtime(src)
	local c = parse_cache[src]
	if not c or c.t ~= t then
		c = { t = t, deps = needed(M.parse(read(src))) }
		parse_cache[src] = c
	end
	return c.deps
end

--- Modules `names` need, dependencies first: { { name, src, pcm, is_std } ... }, plus unknown names
local function closure(names, root, std)
	local order, seen, missing = {}, {}, {}
	local function visit(name)
		if seen[name] then
			return
		end
		seen[name] = true
		local src, is_std = source_of(name, root)
		if not src then
			table.insert(missing, name)
			return
		end
		for _, dep in ipairs(deps_of(src)) do
			visit(dep)
		end
		table.insert(order, { name = name, src = src, pcm = pcm_path(name, std, root, is_std), is_std = is_std })
	end
	for _, n in ipairs(names) do
		visit(n)
	end
	return order, missing
end

local function stale(node, order)
	local t = mtime(node.pcm)
	if not t or t < (mtime(node.src) or 0) then
		return true
	end
	for _, dep in ipairs(deps_of(node.src)) do
		for _, other in ipairs(order) do
			if other.name == dep and (mtime(other.pcm) or math.huge) > t then
				return true
			end
		end
	end
	return false
end

-- One build at a time; whoever asked while it ran is called back when it's done
local busy, waiting = false, {}

-- Bumped after every build. clangd only re-parses a file when its command changes, and the
-- -fmodule-file paths stay the same when a module is rebuilt, so the command carries this too.
M.revision = 0

local function build(order, std, extra, on_done)
	if busy then
		table.insert(waiting, on_done)
		return
	end
	busy = true
	table.insert(waiting, on_done)
	local queue = vim.tbl_filter(function(n)
		return stale(n, order)
	end, order)
	local function finish()
		busy = false
		M.revision = M.revision + 1
		local cbs = waiting
		waiting = {}
		for _, cb in ipairs(cbs) do
			pcall(cb)
		end
	end
	local function step(i)
		local node = queue[i]
		if not node then
			return vim.schedule(finish)
		end
		vim.fn.mkdir(vim.fs.dirname(node.pcm), "p")
		local cmd = { "clang++", "-std=" .. std, "-Wno-reserved-module-identifier", "--precompile", "-x", "c++-module" }
		vim.list_extend(cmd, extra)
		for _, other in ipairs(order) do
			if other ~= node and vim.uv.fs_stat(other.pcm) then
				table.insert(cmd, ("-fmodule-file=%s=%s"):format(other.name, other.pcm))
			end
		end
		vim.list_extend(cmd, { node.src, "-o", node.pcm })
		if i == 1 and #queue > 0 then
			vim.schedule(function()
				local names = table.concat(vim.tbl_map(function(n) return n.name end, queue), ", ")
				vim.notify("Building for clangd: " .. names, vim.log.levels.INFO, { title = "C++ modules" })
			end)
		end
		vim.system(cmd, { text = true }, function(r)
			if r.code ~= 0 then
				vim.schedule(function()
					local first = table.concat(vim.list_slice(vim.split(r.stderr or "", "\n"), 1, 6), "\n")
					vim.notify(("Module %s doesn't compile yet:\n%s"):format(node.name, first), vim.log.levels.WARN, { title = "C++ modules" })
				end)
				return vim.schedule(finish)
			end
			vim.schedule(function()
				step(i + 1)
			end)
		end)
	end
	step(1)
end

-- Flags the module sources themselves need: the project's include dirs and defines
local function project_flags(base, root, std_flag)
	local extra = {}
	for _, f in ipairs(base or {}) do
		if f:match("^%-[IDU]") or f:match("^%-isystem") then
			table.insert(extra, f)
		end
	end
	vim.list_extend(extra, { "-I" .. root, "-I" .. root .. "/include" })
	return extra
end

--- clangd flags for a C++ buffer: -fmodule-file=... for every module it imports (directly or not).
--- Builds what's missing or out of date in the background and calls `on_ready` when done.
function M.clangd_flags(lines, root, std, base, on_ready)
	local names = needed(M.parse(lines))
	if #names == 0 then
		return {}, false
	end
	local order = closure(names, root, std)
	local flags = {}
	for _, n in ipairs(order) do
		table.insert(flags, ("-fmodule-file=%s=%s"):format(n.name, n.pcm))
	end
	table.insert(flags, "-DNVIM_MODULES_REV=" .. M.revision)
	local todo = vim.tbl_filter(function(n)
		return stale(n, order)
	end, order)
	if #todo > 0 then
		build(order, std, project_flags(base, root), on_ready)
	end
	return flags, true
end

--- Load the implementation units of the project modules `lines` imports, hidden and unlisted, so
--- clangd has seen them and go to definition reaches function bodies, not just declarations.
--- (With CMake, clangd's background index does this from compile_commands.json.)
function M.preload_impls(lines, root)
	local names = needed(M.parse(lines))
	if #names == 0 then
		return
	end
	local idx = M.index(root)
	for _, n in ipairs(closure(names, root, "any")) do
		for _, impl in ipairs(not n.is_std and idx.impls[n.name] or {}) do
			if vim.fn.bufloaded(impl) == 0 then
				local b = vim.fn.bufadd(impl)
				vim.bo[b].buflisted = false
				vim.fn.bufload(b)
				vim.api.nvim_exec_autocmds("FileType", { buffer = b, modeline = false })
			end
		end
	end
end

--- Arguments for a GCC build of the file `lines` came from: module sources (and implementation
--- units) in dependency order, before the file itself. Returns {} when it imports nothing.
function M.gcc_args(lines, file, root)
	local names = needed(M.parse(lines))
	if #names == 0 then
		return {}
	end
	local order = closure(names, root, "gcc")
	local args, added = { "-fmodules" }, { [file] = true }
	local function add(src)
		if added[src] then
			return
		end
		added[src] = true
		if MODULE_EXT[src:match("%.([%w+]+)$") or ""] then
			vim.list_extend(args, { "-x", "c++", src, "-x", "none" })
		else
			table.insert(args, src)
		end
	end
	local idx = M.index(root)
	for _, n in ipairs(order) do
		add(n.src)
		for _, impl in ipairs(idx.impls[n.name] or {}) do
			add(impl)
		end
	end
	return args
end

--- The module (std or project) a name refers to, for hover: { src, is_std, impls }
function M.lookup(name, root)
	local src, is_std = source_of(name, root)
	return src and { src = src, is_std = is_std, impls = (M.index(root).impls[name] or {}) } or nil
end

-- Go to definition / declaration / implementation: a module's `using std::println;` (how std.cc
-- and other modules re-export names) is not where the code is. Drop those and duplicates when a
-- real location is also there, so the jump goes straight to the definition.
local function line_at(fname, lnum, cache)
	cache[fname] = cache[fname] or read(fname)
	return cache[fname][lnum + 1]
end

function M.filter_locations(result)
	if type(result) ~= "table" or result.uri or result.targetUri or #result < 2 then
		return result
	end
	local seen, real, reexports, files = {}, {}, {}, {}
	for _, l in ipairs(result) do
		local uri = l.uri or l.targetUri
		local r = l.range or l.targetSelectionRange
		local key = uri .. ":" .. r.start.line .. ":" .. r.start.character
		if not seen[key] then
			seen[key] = true
			local text = line_at(vim.uri_to_fname(uri), r.start.line, files) or ""
			if text:match("^%s*export%s+using%s+[%w_:]+%s*;") or text:match("^%s*using%s+[%w_:]+%s*;") then
				table.insert(reexports, l)
			else
				table.insert(real, l)
			end
		end
	end
	return #real > 0 and real or reexports
end

local style_ns = vim.api.nvim_create_namespace("cc-modules-style")

-- Standard headers worth including next to `import std;` for their macros
local MACRO_HEADERS = {}
for _, h in ipairs({
	"cassert", "cerrno", "climits", "cfloat", "cstdarg", "csetjmp", "csignal", "cstdio", "cstdlib",
	"cstddef", "cstdint", "cinttypes", "cmath", "version", "cfenv", "clocale", "ctime",
}) do
	MACRO_HEADERS[h] = true
	MACRO_HEADERS[h:sub(2) .. ".h"] = true
end

-- Every header the std module covers (C++ library headers and the <cxxx> C headers)
local STD_HEADERS = {}
for _, h in ipairs({
	"algorithm", "any", "array", "atomic", "barrier", "bit", "bitset", "charconv", "chrono", "compare",
	"complex", "concepts", "condition_variable", "coroutine", "deque", "exception", "execution",
	"expected", "filesystem", "flat_map", "flat_set", "format", "forward_list", "fstream", "functional",
	"future", "generator", "initializer_list", "iomanip", "ios", "iosfwd", "iostream", "istream",
	"iterator", "latch", "limits", "list", "locale", "map", "mdspan", "memory", "memory_resource",
	"mutex", "new", "numbers", "numeric", "optional", "ostream", "print", "queue", "random", "ranges",
	"ratio", "regex", "scoped_allocator", "semaphore", "set", "shared_mutex", "source_location", "span",
	"spanstream", "sstream", "stack", "stacktrace", "stdexcept", "stdfloat", "stop_token", "streambuf",
	"string", "string_view", "strstream", "syncstream", "system_error", "text_encoding", "thread",
	"tuple", "type_traits", "typeindex", "typeinfo", "unordered_map", "unordered_set", "utility",
	"valarray", "variant", "vector", "cctype", "cstring", "cwchar", "cwctype", "cuchar",
}) do
	STD_HEADERS[h] = true
end

--- Hint on #include <vector> & co. in a file that already does `import std;` / `import std.compat;`
function M.check_style(buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "cpp" then
		return
	end
	local std_import, includes, in_fragment = nil, {}, false
	for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		if l:match("^%s*module%s*;") then
			in_fragment = true
		elseif l:match("^%s*export%s+module%s") or l:match("^%s*module%s+[%w_.:]+%s*;") then
			in_fragment = false
		end
		if not std_import and (l:match("^%s*import%s+std%s*;") or l:match("^%s*import%s+std%.compat%s*;") or l:match("^%s*export%s+import%s+std")) then
			std_import = i
		end
		local h = l:match("^%s*#%s*include%s*<([%w_./]+)>")
		if h and not in_fragment and STD_HEADERS[h] and not MACRO_HEADERS[h] then
			table.insert(includes, { i, h })
		end
	end
	local diags = {}
	if std_import then
		for _, inc in ipairs(includes) do
			table.insert(diags, {
				lnum = inc[1] - 1,
				col = 0,
				severity = vim.diagnostic.severity.HINT,
				source = "modules",
				message = ("<%s> is already in `import std;` (line %d): this #include is redundant"):format(inc[2], std_import),
			})
		end
	end
	vim.diagnostic.set(style_ns, buf, diags)
end

local NAV = {
	["textDocument/definition"] = true,
	["textDocument/declaration"] = true,
	["textDocument/typeDefinition"] = true,
	["textDocument/implementation"] = true,
}

function M.setup()
	local group = vim.api.nvim_create_augroup("cc-modules", { clear = true })
	-- Wrap clangd's requests once, so every caller (gd, grd, Telescope, Trouble ...) gets clean results
	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(ev)
			local client = vim.lsp.get_client_by_id(ev.data.client_id)
			if not client or client.name ~= "clangd" or client._cc_filtered then
				return
			end
			client._cc_filtered = true
			local request = client.request
			client.request = function(self, method, params, handler, bufnr)
				if NAV[method] then
					local h = handler or self.handlers[method] or vim.lsp.handlers[method]
					if h then
						handler = function(err, result, ctx, config)
							return h(err, M.filter_locations(result), ctx, config)
						end
					end
				end
				return request(self, method, params, handler, bufnr)
			end
		end,
	})
	-- Saving a module source: re-index the project and rebuild what imports it
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = { "*.cppm", "*.ixx", "*.mpp", "*.cxxm", "*.ccm", "*.cpp", "*.cc", "*.cxx" },
		callback = function(ev)
			local info = M.parse(vim.api.nvim_buf_get_lines(ev.buf, 0, 300, false))
			if not info.module then
				return
			end
			local cc = require("core.cc")
			local root = cc.root(ev.buf)
			M.invalidate(root)
			for _, b in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == "cpp" and cc.root(b) == root then
					cc.refresh(b, true)
				end
			end
		end,
	})
end

return M
