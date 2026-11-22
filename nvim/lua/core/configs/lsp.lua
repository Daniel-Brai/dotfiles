local servers = {
	ruby_lsp = {},
	html = {},
	-- C/C++. Language standards and clang-tidy checks live in ~/.config/clangd/config.yaml,
	-- per file extension. (A fallbackFlags std here applies to C *and* C++ files alike.)
	clangd = {
		cmd = {
			-- The system clangd matches the system clang++ (and clang-tidy). That matters for
			-- `import std`: the std module clangd loads is built by clang++ and only works with the
			-- exact same version. Mason's clangd is the fallback.
			vim.fn.executable("/usr/bin/clangd") == 1 and "/usr/bin/clangd" or "clangd",
			"--background-index", -- index the whole project for references/workspace symbols
			"--clang-tidy",
			"--header-insertion=iwyu", -- auto #include what you use on completion
			"--completion-style=detailed",
			"--function-arg-placeholders=1",
			"--fallback-style=llvm",
			-- Let clangd ask the real compilers for their system include paths
			"--query-driver=/usr/bin/gcc,/usr/bin/g++,/usr/bin/cc,/usr/bin/c++,/usr/bin/clang*",
		},
		init_options = {
			usePlaceholders = true,
			completeUnimported = true,
			clangdFileStatus = true,
		},
	},
	neocmake = {}, -- CMakeLists.txt / *.cmake: completion, hover, go to definition
	cssls = {},
	tailwindcss = {},
	taplo = {},
	gopls = {},
	ruff = {},
	ols = {},
	pylsp = {
		settings = {
			pylsp = {
				pyflakes = { enabled = false },
				pycodestyle = { enabled = false },
				autopep8 = { enabled = false },
				yapf = { enabled = false },
				mccabe = { enabled = false },
				pylsp_mypy = { enabled = false },
				pylsp_black = { enabled = true },
				pylsp_isort = { enabled = true },
			},
		},
	},
	gitlab_ci_ls = {},
	gh_actions_ls = {},
	dexter = {
		cmd = { vim.fn.exepath("dexter"), "lsp" },
		root_markers = { ".dexter/dexter.db", ".dexter.db", ".git", "mix.exs" },
		filetypes = { "elixir", "eelixir", "heex" },
		init_options = {
			followDelegates = true,
		},
	},
	docker_language_server = {},
	terraformls = {},
	sqlls = {},
	postgres_lsp = {},
	-- hls = {
	-- 	cmd = { vim.fn.exepath("haskell-language-server-wrapper"), "--lsp" },
	-- 	filetypes = { "haskell", "lhaskell", "cabal" },
	-- },
	-- zls = {},
	ts_ls = {},
	yamlls = {},
	emmet_language_server = {},
	herb_ls = {},
	bashls = {},
	-- vue_ls = {},
	lua_ls = {
		settings = {
			Lua = {
				completion = { callSnippet = "Replace" },
				runtime = { version = "LuaJIT" },
				workspace = {
					checkThirdParty = false,
					library = {
						"${3rd}/luv/library",
						unpack(vim.api.nvim_get_runtime_file("", true)),
					},
				},
				diagnostics = {
					disable = { "missing-fields" },
					globals = { "vim" },
				},
			},
		},
	},
}

return {
	servers = servers,
}
