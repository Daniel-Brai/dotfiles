return {
	{
		"romus204/tree-sitter-manager.nvim",
		lazy = false,
		config = function()
			require("tree-sitter-manager").setup({
				ensure_installed = {
					"bash",
					"c",
					"cpp",
					"diff",
					"html",
					"lua",
					"rust",
					"gitignore",
					"gitcommit",
					"go",
					"gotmpl",
					"haskell",
					"heex",
					"gomod",
					"gosum",
					"gowork",
					"css",
					"ruby",
					"elixir",
					"eex",
					"typescript",
					"javascript",
					"python",
					"luadoc",
					"markdown",
					"markdown_inline",
					"query",
					"vim",
					"xml",
					"yaml",
					"vimdoc",
					"zig",
				},
				auto_install = true,
				languages = {
					haskell = {
						install_info = {
							url = "https://github.com/tree-sitter-grammars/tree-sitter-haskell",
							revision = "98aedbd2d6947a168ba3ba3755d70b0cb6b78395",
							use_repo_queries = true,
						},
					},
				},
			})
		end,
	},
}
