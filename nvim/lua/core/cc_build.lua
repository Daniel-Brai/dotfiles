-- C / C++ projects: configure, build, test, run and debug CMake / Meson / Make projects.
-- Without a project, the same keys compile and run the current file on its own (core/cc.lua).
--
--   <leader>cc  configure        <leader>cb  build (errors -> quickfix)
--   <leader>cr  build & run      <leader>ct  run tests
--   <leader>cp  pick preset      <leader>cT  pick the executable to run/debug
--   <leader>ca  assembly of the current file

local cc = require("core.cc")
local M = {}

-- Remembered per project root: chosen preset and executable
local STATE_FILE = vim.fn.stdpath("state") .. "/cc-projects.json"
local state = {}
do
	local ok, data = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(STATE_FILE), "\n"))
	end)
	state = ok and type(data) == "table" and data or {}
end
local function save_state()
	pcall(vim.fn.writefile, { vim.json.encode(state) }, STATE_FILE)
end
local function project_state(root)
	state[root] = state[root] or {}
	return state[root]
end

local function exists(p)
	return vim.uv.fs_stat(p) ~= nil
end


local function start_dir()
	local name = vim.api.nvim_buf_get_name(0)
	if name ~= "" and vim.bo.buftype == "" then
		return vim.fs.dirname(name)
	end
	return vim.fn.getcwd()
end

-- Outermost directory (up to the git root) that contains `file`
local function outermost(dir, file)
	local found
	for d in vim.fs.parents(dir .. "/x") do
		if exists(d .. "/" .. file) then
			found = d
		end
		if exists(d .. "/.git") then
			break
		end
	end
	return found
end

--- { kind = "cmake" | "meson" | "make", root, presets? } or nil for a lone file
function M.project()
	local dir = start_dir()
	local root = outermost(dir, "CMakeLists.txt")
	if root then
		local p = { kind = "cmake", root = root }
		if exists(root .. "/CMakePresets.json") or exists(root .. "/CMakeUserPresets.json") then
			p.presets = M.read_presets(root)
		end
		return p
	end
	root = outermost(dir, "meson.build")
	if root then
		return { kind = "meson", root = root }
	end
	root = vim.fs.root(dir, { "Makefile", "makefile", "GNUmakefile" })
	if root then
		return { kind = "make", root = root }
	end
	return nil
end


function M.read_presets(root)
	local all = {}
	for _, f in ipairs({ "CMakePresets.json", "CMakeUserPresets.json" }) do
		local path = root .. "/" .. f
		if exists(path) then
			local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
			if ok and type(data) == "table" then
				for _, p in ipairs(data.configurePresets or {}) do
					all[p.name] = p
				end
			end
		end
	end
	local function field(p, key, seen)
		seen = seen or {}
		if not p or seen[p.name] then
			return nil
		end
		seen[p.name] = true
		if p[key] ~= nil then
			return p[key]
		end
		local parents = type(p.inherits) == "string" and { p.inherits } or p.inherits or {}
		for _, parent in ipairs(parents) do
			local v = field(all[parent], key, seen)
			if v ~= nil then
				return v
			end
		end
	end
	local list = {}
	for name, p in pairs(all) do
		if not p.hidden then
			local bdir = field(p, "binaryDir") or ("${sourceDir}/build/" .. name)
			bdir = bdir:gsub("%${sourceDir}", root)
				:gsub("%${presetName}", name)
				:gsub("%${sourceParentDir}", vim.fs.dirname(root))
				:gsub("%${sourceDirName}", vim.fs.basename(root))
			table.insert(list, { name = name, binary_dir = bdir, display = p.displayName or name })
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

local function current_preset(p)
	if not p.presets or #p.presets == 0 then
		return nil
	end
	local want = project_state(p.root).preset
	for _, pr in ipairs(p.presets) do
		if pr.name == want then
			return pr
		end
	end
	for _, pr in ipairs(p.presets) do
		if pr.name == "debug" then
			return pr
		end
	end
	return p.presets[1]
end

function M.build_dir(p)
	if p.kind == "cmake" then
		local pr = current_preset(p)
		return pr and pr.binary_dir or (p.root .. "/build")
	elseif p.kind == "meson" then
		return p.root .. "/builddir"
	end
	-- Make: :CNew Makefiles build into build/<mode>/, others usually build in place
	return exists(p.root .. "/build") and (p.root .. "/build") or p.root
end

local function configured(p)
	local b = M.build_dir(p)
	if p.kind == "cmake" then
		return exists(b .. "/CMakeCache.txt")
	elseif p.kind == "meson" then
		return exists(b .. "/build.ninja")
	end
	return true
end


-- Parse compiler output into the quickfix list; paths are resolved from `dir`
local function to_quickfix(lines, dir, title)
	local cwd = vim.fn.getcwd()
	vim.cmd("noautocmd silent cd " .. vim.fn.fnameescape(dir))
	local items = vim.fn.getqflist({ lines = lines, efm = vim.o.errorformat }).items or {}
	vim.cmd("noautocmd silent cd " .. vim.fn.fnameescape(cwd))
	local valid, errors = {}, 0
	for _, it in ipairs(items) do
		if it.valid == 1 then
			table.insert(valid, it)
			if it.type == "e" or it.text:find("error") then
				errors = errors + 1
			end
		end
	end
	vim.fn.setqflist({}, " ", { title = title, items = valid })
	return #valid, errors
end

local running = false

local function run_job(cmd, cwd, title, on_ok, on_fail)
	if running then
		vim.notify("A build is already running", vim.log.levels.WARN)
		return on_fail and on_fail()
	end
	running = true
	vim.notify(table.concat(cmd, " "), vim.log.levels.INFO, { title = title })
	local started = vim.uv.hrtime()
	vim.system(cmd, { cwd = cwd, text = true }, function(out)
		vim.schedule(function()
			running = false
			local text = (out.stdout or "") .. "\n" .. (out.stderr or "")
			local lines = vim.split(text, "\n", { trimempty = true })
			local count, errors = to_quickfix(lines, cwd, title)
			local secs = (vim.uv.hrtime() - started) / 1e9
			if out.code == 0 then
				local msg = ("%s done in %.1fs"):format(title, secs)
				if count > 0 then
					msg = msg .. (" (%d warnings, see quickfix)"):format(count)
				end
				vim.notify(msg, vim.log.levels.INFO, { title = title })
				if on_ok then
					on_ok()
				end
			else
				if count > 0 then
					vim.cmd("botright copen")
				else
					-- Nothing parseable (CMake error, linker error...): show the raw output
					vim.fn.setqflist({}, " ", { title = title, lines = lines, efm = "%m" })
					vim.cmd("botright copen")
				end
				vim.notify(("%s failed (%d errors)"):format(title, errors), vim.log.levels.ERROR, { title = title })
				if on_fail then
					on_fail()
				end
			end
		end)
	end)
end

local function in_terminal(cmd, cwd)
	vim.cmd("botright 15split")
	vim.cmd("enew")
	vim.fn.jobstart(cmd, { term = true, cwd = cwd })
	vim.cmd("startinsert")
end

-- clangd finds compile_commands.json in the project root: link it there
local function link_compile_commands(p)
	local src = M.build_dir(p) .. "/compile_commands.json"
	local dst = p.root .. "/compile_commands.json"
	if not exists(src) then
		return
	end
	local lstat = vim.uv.fs_lstat(dst)
	if lstat and lstat.type ~= "link" then
		return -- a real file the user put there
	end
	if vim.uv.fs_readlink(dst) == src then
		return
	end
	if lstat then
		os.remove(dst)
	end
	vim.uv.fs_symlink(src, dst)
	if #vim.lsp.get_clients({ name = "clangd" }) > 0 then
		pcall(vim.cmd, "lsp restart clangd")
	end
end


function M.configure(on_ok, on_fail)
	local p = M.project()
	if not p then
		return vim.notify("No CMakeLists.txt / meson.build here", vim.log.levels.WARN)
	end
	local cmd
	if p.kind == "cmake" then
		local pr = current_preset(p)
		if pr then
			cmd = { "cmake", "--preset", pr.name }
		else
			cmd = {
				"cmake", "-S", p.root, "-B", M.build_dir(p), "-G", "Ninja",
				"-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
			}
		end
	elseif p.kind == "meson" then
		cmd = { "meson", "setup", M.build_dir(p) }
		if configured(p) then
			table.insert(cmd, 3, "--reconfigure")
		end
	else
		return on_ok and on_ok()
	end
	run_job(cmd, p.root, "Configure", function()
		link_compile_commands(p)
		if on_ok then
			on_ok()
		end
	end, on_fail)
end

function M.build(on_ok, on_fail)
	local p = M.project()
	if not p then
		return cc.build(false)
	end
	vim.cmd("silent! wall")
	if not configured(p) then
		return M.configure(function()
			M.build(on_ok, on_fail)
		end, on_fail)
	end
	local cmd
	if p.kind == "cmake" then
		cmd = { "cmake", "--build", M.build_dir(p) }
	elseif p.kind == "meson" then
		cmd = { "meson", "compile", "-C", M.build_dir(p) }
	else
		cmd = { "make", "-j" .. #vim.uv.cpu_info() }
	end
	local dir = p.kind == "meson" and M.build_dir(p) or p.root
	run_job(cmd, dir, "Build", on_ok, on_fail)
end

function M.test()
	local p = M.project()
	if not p then
		return vim.notify("No project here: tests need CMake (ctest) or Meson", vim.log.levels.WARN)
	end
	M.build(function()
		local cmd
		if p.kind == "cmake" then
			cmd = { "ctest", "--test-dir", M.build_dir(p), "--output-on-failure", "-j", tostring(#vim.uv.cpu_info()) }
		elseif p.kind == "meson" then
			cmd = { "meson", "test", "-C", M.build_dir(p), "--print-errorlogs" }
		else
			cmd = { "make", "test" }
		end
		in_terminal(cmd, p.root)
	end)
end

-- Executables in the build directory (skips CMake/Meson internals and fetched deps)
local function executables(p)
	local bdir = M.build_dir(p)
	local found = {}
	if not exists(bdir) then
		return found
	end
	for name, type in vim.fs.dir(bdir, {
		depth = 5,
		skip = function(d)
			return not (
				d:find("CMakeFiles") or d:find("_deps") or d:find("^meson%-") or d:find("%.p$")
				or d:find("Testing") or d:find("^%.git") or d:find("/%.git")
			)
		end,
	}) do
		local full = bdir .. "/" .. name
		if type == "file" and not name:find("%.so") and not name:find("%.a$") and vim.fn.executable(full) == 1 then
			table.insert(found, full)
		end
	end
	-- programs before test binaries
	table.sort(found, function(a, b)
		local ta, tb = a:find("test") ~= nil, b:find("test") ~= nil
		if ta ~= tb then
			return tb
		end
		return a < b
	end)
	return found
end

--- Calls back with the executable to run/debug (asks when there are several)
function M.pick_target(p, force, cb, on_cancel)
	local list = executables(p)
	if #list == 0 then
		vim.notify("No executable in " .. M.build_dir(p) .. " yet", vim.log.levels.WARN)
		return on_cancel and on_cancel()
	end
	local st = project_state(p.root)
	if not force and st.target and vim.tbl_contains(list, st.target) then
		return cb(st.target)
	end
	-- one real program (not *_tests / *_bench): just use it; <leader>cT still lets you pick
	local programs = vim.tbl_filter(function(x)
		local base = vim.fs.basename(x)
		return not (base:find("_tests?$") or base:find("_bench$"))
	end, list)
	if not force and #programs == 1 then
		return cb(programs[1])
	end
	vim.ui.select(list, {
		prompt = "Executable",
		format_item = function(x)
			return vim.fn.fnamemodify(x, ":.")
		end,
	}, function(choice)
		if choice then
			st.target = choice
			save_state()
			cb(choice)
		elseif on_cancel then
			on_cancel()
		end
	end)
end

function M.run(args)
	local p = M.project()
	if not p then
		return cc.build(true)
	end
	M.build(function()
		M.pick_target(p, false, function(exe)
			local cmd = vim.list_extend({ exe }, args or {})
			in_terminal(cmd, p.root)
		end)
	end)
end

function M.pick_preset()
	local p = M.project()
	if not p or not p.presets or #p.presets == 0 then
		return vim.notify("No CMake presets in this project", vim.log.levels.WARN)
	end
	vim.ui.select(p.presets, {
		prompt = "CMake preset",
		format_item = function(x)
			return x.display
		end,
	}, function(choice)
		if choice then
			project_state(p.root).preset = choice.name
			project_state(p.root).target = nil
			save_state()
			M.configure()
		end
	end)
end

--- Program to debug: built project executable, or the current file compiled on its own
function M.debug_program(cb, on_fail, opts)
	local p = M.project()
	if p then
		return M.build(function()
			M.pick_target(p, false, cb, on_fail)
		end, on_fail)
	end
	local cmd, out, build_dir = cc.build_cmd(0, opts)
	vim.cmd("silent! write")
	local res = vim.system(cmd, { text = true, cwd = build_dir }):wait()
	if res.code ~= 0 then
		local lines = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })
		to_quickfix(lines, vim.fn.expand("%:p:h"), "Build")
		vim.cmd("botright copen")
		return on_fail and on_fail()
	end
	cb(out)
end

-- Assembly for the current file (Intel syntax, demangled), compiler-explorer style
function M.assembly(opt, keep_lib)
	opt = opt or "-O2"
	local file = vim.api.nvim_buf_get_name(0)
	local is_c = vim.bo.filetype == "c"
	vim.cmd("silent! write")
	local cmd = {
		is_c and "gcc" or "g++", "-std=" .. cc.current_std(0), opt, "-S", "-o", "-",
		"-masm=intel", "-fno-asynchronous-unwind-tables", "-fno-exceptions", "-fno-dwarf2-cfi-asm", file,
	}
	if is_c then
		table.remove(cmd, 10) -- -fno-exceptions is C++ only
	end
	local out_dir = vim.fn.stdpath("cache") .. "/cc-run"
	vim.fn.mkdir(out_dir, "p")
	if not is_c then
		local mods = require("core.cc_modules").gcc_args(vim.api.nvim_buf_get_lines(0, 0, -1, false), file, cc.root(0))
		if #mods > 0 then
			-- build the imported modules first (writes gcm.cache/ in out_dir), then just this file
			local pre = vim.list_extend({ "g++", "-std=" .. cc.current_std(0), "-c" }, mods)
			vim.system(pre, { text = true, cwd = out_dir }):wait()
			table.insert(cmd, 2, "-fmodules")
		end
	end
	local res = vim.system(cmd, { text = true, cwd = out_dir }):wait()
	if res.code ~= 0 then
		return vim.notify(res.stderr, vim.log.levels.ERROR, { title = "Assembly" })
	end
	-- GCC quotes symbol names ("_Z3sumRK..."); c++filt only demangles them unquoted
	local asm = res.stdout:gsub('"(_Z[%w_.$]+)"', "%1")
	local filt = vim.system({ "c++filt" }, { stdin = asm, text = true }):wait()
	if filt.code == 0 then
		asm = filt.stdout
	end
	-- Like Compiler Explorer: drop directives (keep labels and string data) and the bodies of
	-- standard-library template instantiations, so your own functions are what's left.
	-- :CAsm! keeps the library functions.
	local lines, skipping = {}, false
	for _, l in ipairs(vim.split(asm, "\n")) do
		l = l:gsub('^"([^"]+)":', "%1:")
		local label = l:match("^([^%s.][^\t]*):%s*$")
		if label then
			-- the qualified name without template arguments or parameters: "void std::foo" -> library
			local name = label:gsub("^decltype%(auto%)%s+", "")
			name = name:gsub("%b<>", ""):gsub("%b<>", "")
			name = name:match("^(.-)%(") or name
			skipping = not keep_lib and (name:find("std::") or name:find("__gnu_cxx") or name:find("^_") or name:find(" _")) ~= nil
		end
		local directive = l:match("^%s+%.[%a_]") and not (l:match("^%s+%.string") or l:match("^%s+%.ascii"))
		if not skipping and not directive then
			table.insert(lines, l)
		end
	end
	vim.cmd("vnew")
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	vim.bo.filetype = "asm"
	vim.api.nvim_buf_set_name(0, ("asm://%s %s"):format(vim.fn.fnamemodify(file, ":t"), opt))
end


function M.attach(buf)
	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
	end
	map("<leader>cc", function() M.configure() end, "C/C++: [C]onfigure project")
	map("<leader>cb", function() M.build() end, "C/C++: [B]uild (project or file)")
	map("<leader>cr", function() M.run() end, "C/C++: build & [R]un")
	map("<leader>ct", function() M.test() end, "C/C++: run [T]ests")
	map("<leader>cp", function() M.pick_preset() end, "C/C++: pick CMake [P]reset")
	map("<leader>cT", function()
		local p = M.project()
		if p then
			M.pick_target(p, true, function() end)
		end
	end, "C/C++: pick executable [T]arget")
	map("<leader>ca", function() M.assembly() end, "C/C++: show [A]ssembly (-O2)")
end

local function cmd(name, fn, opts)
	vim.api.nvim_create_user_command(name, fn, vim.tbl_extend("force", { desc = "C/C++" }, opts or {}))
end
cmd("CConfigure", function() M.configure() end)
cmd("CBuild", function() M.build() end)
cmd("CRun", function(o) M.run(o.fargs) end, { nargs = "*" })
cmd("CTest", function() M.test() end)
cmd("CPreset", function() M.pick_preset() end)
cmd("CTarget", function()
	local p = M.project()
	if p then
		M.pick_target(p, true, function() end)
	end
end)
cmd("CAsm", function(o) M.assembly(o.args ~= "" and o.args or nil, o.bang) end, {
	nargs = "?",
	bang = true,
	complete = function()
		return { "-O0", "-O1", "-O2", "-O3", "-Os", "-Og" }
	end,
})

-- Run the built program under a tool, in a terminal split (project executable or this file alone)
local function with_program(fn, opts)
	M.debug_program(function(exe)
		fn(exe, (M.project() or {}).root or vim.fn.expand("%:p:h"))
	end, nil, opts)
end

-- :CGdb        gdb's own text UI on the program (layout src, `catch throw`, watch, x/ ...)
-- :CGdb core   the most recent crash, via systemd-coredump
cmd("CGdb", function(o)
	if o.args == "core" then
		return in_terminal({ "coredumpctl", "gdb" }, vim.fn.getcwd())
	end
	with_program(function(exe, cwd)
		in_terminal({ "gdb", "-q", "-tui", "--args", exe }, cwd)
	end)
end, { nargs = "?", complete = function() return { "core" } end })

-- :CPerf stat | record | energy   (energy reads RAPL counters: needs perf_event_paranoid <= 0 or root)
cmd("CPerf", function(o)
	local mode = o.args ~= "" and o.args or "stat"
	with_program(function(exe, cwd)
		local cmds = {
			stat = { "perf", "stat", "-d", exe },
			record = { "sh", "-c", "perf record -g -o /tmp/perf.data " .. vim.fn.shellescape(exe) .. " && perf report -i /tmp/perf.data" },
			energy = { "perf", "stat", "-e", "power/energy-pkg/,power/energy-cores/", exe },
		}
		in_terminal(cmds[mode] or cmds.stat, cwd)
	end)
end, { nargs = "?", complete = function() return { "stat", "record", "energy" } end })

-- :CValgrind  memcheck with full leak report (build without sanitizers: they don't mix)
cmd("CValgrind", function()
	with_program(function(exe, cwd)
		in_terminal({ "valgrind", "--leak-check=full", "--show-leak-kinds=all", "--track-origins=yes", exe }, cwd)
	end, { sanitize = false })
end)

return M
