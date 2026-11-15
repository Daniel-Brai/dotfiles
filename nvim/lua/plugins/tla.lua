-- TLA+: the plugins, with everything else in lua/tlaplus/
return {
	{
		-- Types ASCII TLA+ operators as Unicode, e.g. \A -> ∀, \in -> ∈, <= -> ≤
		"tlaplus-community/tlaplus-nvim-plugin",
		ft = "tla",
		init = function()
			require("tlaplus").init()
		end,
		config = function()
			require("tlaplus").config()
		end,
	},
	{
		-- :TlaTranslate (PlusCal -> TLA+) and :TlaCheck (TLC) using the jar from ~/.zshrc
		"susliko/tla.nvim",
		ft = "tla",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			-- Same Java and jar as :TlaCheck from a .cfg (lua/tlaplus/check.lua)
			require("tla").setup(require("tlaplus.check").settings)
		end,
	},
}
