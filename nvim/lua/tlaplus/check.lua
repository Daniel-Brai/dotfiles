-- :TlaCheck that works from a .cfg as well as a .tla. In a .cfg it checks the spec
-- that .cfg belongs to (same name, or the only .tla in the folder) with that .cfg;
-- in a .tla it checks the spec with Name.cfg, like tla.nvim does. The run itself,
-- its output window and its tags are tla.nvim's
--
-- Options, in any order:
--   time=15m          stop TLC after 15 minutes (also 90s, 2h, or plain seconds)
--   workers=4         worker threads (default auto)
--   simulate          random simulation instead of exhaustive checking
--   depth=100         trace depth for simulate
--   seed=42           fixed seed for simulate, so a run can be repeated
--   nodeadlock        don't report deadlock (TLC's -deadlock)
--   nocoverage        skip the coverage report
--   cfg=Other.cfg     check with another .cfg in the spec's folder
--   -- -flag value    pass everything after -- to TLC unchanged
-- :TlaCheckStop stops the run for this spec.

local tla_cfg_spec_file = require("tlaplus.cfg").tla_cfg_spec_file

-- Java and tla2tools.jar for TLC; plugins/tla.lua passes the same to tla.nvim.
-- default_time caps every run that doesn't give time=, nil for no cap
local settings = {
	java_executable = "/usr/bin/java",
	java_opts = { "-XX:+UseParallelGC" },
	tla2tools = vim.fn.expand("~/.local/share/tla/tla2tools.jar"),
	default_time = nil,
}

local OPTIONS = { "time=", "workers=", "simulate", "depth=", "seed=", "nodeadlock", "nocoverage", "cfg=", "--" }

local running = {}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "TLA+" })
end

-- TLC reads from disk, so unsaved edits to the spec or the .cfg must be written first
local function save(path)
	local buf = vim.fn.bufnr(path)
	if buf > 0 and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent update")
		end)
	end
end

local function seconds(text)
	local n, unit = text:match("^(%d+)([smh]?)$")
	if not n then
		return nil
	end
	return tonumber(n) * ({ [""] = 1, s = 1, m = 60, h = 3600 })[unit]
end

local function parse(fargs)
	local opts = { extra = {} }
	for i, arg in ipairs(fargs) do
		if arg == "--" then
			opts.extra = vim.list_slice(fargs, i + 1)
			break
		end
		local key, value = arg:match("^(%w+)=(.+)$")
		if key == "time" then
			opts.time = seconds(value)
			if not opts.time then
				return nil, "time= takes seconds or a number with s, m or h, like 15m"
			end
		elseif key == "workers" or key == "depth" or key == "seed" then
			if not value:match("^%d+$") and not (key == "workers" and value == "auto") then
				return nil, key .. "= takes a number"
			end
			opts[key] = value
		elseif key == "cfg" then
			opts.cfg = value
		elseif arg == "simulate" or arg == "nodeadlock" or arg == "nocoverage" then
			opts[arg] = true
		else
			return nil, "Unknown option " .. arg .. ". Options are " .. table.concat(OPTIONS, " ")
		end
	end
	return opts
end

local function files(opts)
	local file = vim.api.nvim_buf_get_name(0)
	local spec, cfg
	if file:match("%.cfg$") then
		spec, cfg = tla_cfg_spec_file(0), file
		if not spec then
			return nil, "No spec for this .cfg: expected " .. vim.fn.fnamemodify(file, ":t:r") .. ".tla or a single .tla in the folder"
		end
	elseif file:match("%.tla$") then
		spec, cfg = file, (file:gsub("%.tla$", ".cfg"))
	else
		return nil, "TlaCheck runs from a .tla or .cfg file"
	end
	if opts.cfg then
		cfg = opts.cfg:sub(1, 1) == "/" and opts.cfg or vim.fn.fnamemodify(spec, ":h") .. "/" .. opts.cfg
	end
	if not vim.uv.fs_stat(cfg) then
		return nil, vim.fn.fnamemodify(cfg, ":t") .. " doesn't exist; :TlaCfg creates it"
	end
	return spec, cfg
end

local function tlc_args(spec, cfg, opts)
	local args = { "-cp", settings.tla2tools, "tlc2.TLC", spec, "-tool" }
	if opts.simulate then
		table.insert(args, "-simulate")
		if opts.depth then
			vim.list_extend(args, { "-depth", opts.depth })
		end
		if opts.seed then
			vim.list_extend(args, { "-seed", opts.seed })
		end
	else
		table.insert(args, "-modelcheck")
	end
	if not opts.nocoverage then
		vim.list_extend(args, { "-coverage", "1" })
	end
	if opts.nodeadlock then
		table.insert(args, "-deadlock")
	end
	vim.list_extend(args, { "-workers", opts.workers or "auto", "-config", cfg })
	return vim.list_extend(args, opts.extra)
end

local function stop(spec, reason)
	local run = running[spec]
	if not run then
		return false
	end
	run.stopped = reason
	-- plenary's Job:shutdown closes the pipes but doesn't kill the process, so TLC
	-- would keep running. Signal it ourselves; its exit runs the usual on_exit
	local pid = run.job.pid
	pcall(vim.uv.kill, pid, "sigterm")
	vim.defer_fn(function()
		if running[spec] == run then
			pcall(vim.uv.kill, pid, "sigkill")
		end
	end, 3000)
	return true
end

local function tla_check(cmd)
	local opts, err = parse(cmd and cmd.fargs or {})
	if not opts then
		return notify(err, vim.log.levels.ERROR)
	end
	local spec, cfg = files(opts)
	if not spec then
		return notify(cfg, vim.log.levels.ERROR)
	end
	stop(spec, "replaced by a new run")
	save(spec)
	save(cfg)

	local job = require("tla.check").make_check_job(spec, tlc_args(spec, cfg, opts), settings)
	local run = { job = job }
	running[spec] = run
	job:after(vim.schedule_wrap(function()
		if running[spec] == run then
			running[spec] = nil
		end
		if run.timer then
			run.timer:stop()
			run.timer:close()
		end
		if run.stopped then
			local buf = require("tla.utils").get_or_create_output_buf(spec)
			require("tla.utils").append_to_buf(buf, { "", "TLC stopped: " .. run.stopped .. ". The results above are partial." })
		end
	end))
	job:start()

	local limit = opts.time or settings.default_time
	if limit then
		run.timer = vim.uv.new_timer()
		run.timer:start(limit * 1000, 0, vim.schedule_wrap(function()
			stop(spec, "time cap of " .. limit .. " s reached")
		end))
	end
end

local function tla_check_stop()
	local file = vim.api.nvim_buf_get_name(0)
	local spec = file:match("%.cfg$") and tla_cfg_spec_file(0) or file
	if not stop(spec, "stopped with :TlaCheckStop") then
		notify("No TLC run for this spec")
	end
end

local function complete(arglead)
	return vim.tbl_filter(function(o)
		return o:sub(1, #arglead) == arglead
	end, OPTIONS)
end

-- TLC is a separate Java process and outlives Neovim unless it's stopped
vim.api.nvim_create_autocmd("VimLeavePre", {
	group = vim.api.nvim_create_augroup("TlaCheckStopOnExit", { clear = true }),
	callback = function()
		for _, run in pairs(running) do
			pcall(vim.uv.kill, run.job.pid, "sigterm")
		end
	end,
})

-- Buffer-local, so they win over tla.nvim's global :TlaCheck
local function commands(buf, desc)
	vim.api.nvim_buf_create_user_command(buf, "TlaCheck", tla_check, { desc = desc, nargs = "*", complete = complete })
	vim.api.nvim_buf_create_user_command(buf, "TlaCheckStop", tla_check_stop, { desc = "Stop the TLC run for this spec" })
end

return {
	settings = settings,
	tla_check = tla_check,
	commands = commands,
}
