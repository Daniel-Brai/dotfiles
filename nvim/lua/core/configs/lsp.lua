local servers = {
	ruby_lsp = {},
	html = {},
	clangd = {
		init_options = {
			fallbackFlags = { "--std=c23" },
		},
	},
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
