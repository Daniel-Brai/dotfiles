-- Debugging C/C++ with gdb's built-in DAP server (gdb 14+), no extra adapter to install.
--
--   F5 start/continue   F9 breakpoint     F10 step over   F11 step into   S-F11 step out
--   <leader>dB conditional breakpoint     <leader>dl log point   <leader>dE break on C++ throw
--   <leader>dc run to cursor   <leader>de evaluate   <leader>du toggle UI   <leader>dx stop
--
-- The REPL (<leader>dr) accepts plain gdb commands: watch x, x/8xw &buf, info threads, bt ...
-- Starting a session builds first: the CMake/Make project's executable, or the current file alone.

local function program()
	return coroutine.create(function(dap_run_co)
		require("core.cc_build").debug_program(function(path)
			coroutine.resume(dap_run_co, path)
		end, function()
			coroutine.resume(dap_run_co, require("dap").ABORT)
		end)
	end)
end

local function args()
	local input = vim.fn.input("Arguments: ")
	return vim.split(input, " +", { trimempty = true })
end

return {
	"mfussenegger/nvim-dap",
	dependencies = {
		{ "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
		"theHamsta/nvim-dap-virtual-text",
	},
	keys = {
		{ "<F5>", function() require("dap").continue() end, desc = "Debug: start / continue" },
		{ "<F17>", function() require("dap").terminate() end, desc = "Debug: stop (S-F5)" },
		{ "<S-F5>", function() require("dap").terminate() end, desc = "Debug: stop" },
		{ "<F9>", function() require("dap").toggle_breakpoint() end, desc = "Debug: toggle breakpoint" },
		{ "<F10>", function() require("dap").step_over() end, desc = "Debug: step over" },
		{ "<F11>", function() require("dap").step_into() end, desc = "Debug: step into" },
		{ "<F23>", function() require("dap").step_out() end, desc = "Debug: step out (S-F11)" },
		{ "<S-F11>", function() require("dap").step_out() end, desc = "Debug: step out" },
		{
			"<leader>dB",
			function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end,
			desc = "Debug: conditional [B]reakpoint",
		},
		{
			"<leader>dl",
			function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log message ({expr} works): ")) end,
			desc = "Debug: [L]og point",
		},
		{ "<leader>dE", function() require("dap").set_exception_breakpoints() end, desc = "Debug: break on [E]xceptions" },
		{ "<leader>dc", function() require("dap").run_to_cursor() end, desc = "Debug: run to [C]ursor" },
		{ "<leader>dL", function() require("dap").run_last() end, desc = "Debug: run [L]ast again" },
		{ "<leader>dr", function() require("dap").repl.toggle() end, desc = "Debug: [R]EPL (gdb commands)" },
		{ "<leader>du", function() require("dapui").toggle() end, desc = "Debug: toggle [U]I" },
		{ "<leader>de", function() require("dapui").eval(nil, { enter = true }) end, mode = { "n", "v" }, desc = "Debug: [E]valuate" },
		{ "<leader>dx", function() require("dap").terminate() end, desc = "Debug: stop" },
	},
	config = function()
		local dap, dapui = require("dap"), require("dapui")
		dapui.setup()
		require("nvim-dap-virtual-text").setup({})

		dap.listeners.after.event_initialized.dapui = function() dapui.open() end
		dap.listeners.before.event_terminated.dapui = function() dapui.close() end
		dap.listeners.before.event_exited.dapui = function() dapui.close() end

		vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
		vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
		vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticInfo" })
		vim.fn.sign_define("DapStopped", { text = "→", texthl = "DiagnosticOk", linehl = "Visual" })

		dap.adapters.gdb = {
			type = "executable",
			command = "gdb",
			args = { "--quiet", "--interpreter=dap" },
		}

		-- ASan aborts at the error so gdb stops there; LeakSanitizer can't run under a debugger
		local env = { ASAN_OPTIONS = "abort_on_error=1:detect_leaks=0", UBSAN_OPTIONS = "print_stacktrace=1:halt_on_error=1" }
		local configs = {
			{ name = "Launch", type = "gdb", request = "launch", program = program, cwd = "${workspaceFolder}", env = env },
			{ name = "Launch with arguments", type = "gdb", request = "launch", program = program, args = args, cwd = "${workspaceFolder}", env = env },
			{
				name = "Launch, stop at main",
				type = "gdb",
				request = "launch",
				program = program,
				cwd = "${workspaceFolder}",
				env = env,
				stopAtBeginningOfMainSubprogram = true,
			},
			{
				name = "Attach to process",
				type = "gdb",
				request = "attach",
				pid = function() return require("dap.utils").pick_process() end,
			},
		}
		dap.configurations.c = configs
		dap.configurations.cpp = configs
	end,
}
