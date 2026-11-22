-- Make recipes must start with a real TAB: keep tabs here (expandtab is on everywhere else)
-- and show them, so a space-indented recipe stands out before make complains.
vim.bo.expandtab = false
vim.bo.shiftwidth = 0
vim.bo.softtabstop = 0
vim.bo.tabstop = 4
vim.opt_local.list = true
vim.opt_local.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }
