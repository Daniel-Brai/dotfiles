-- custom/configs/null-ls.lua

local null_ls = require "null-ls"

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
local formatting = null_ls.builtins.formatting
local lint = null_ls.builtins.diagnostics
local hover = null_ls.builtins.hover
local actions = null_ls.builtins.code_actions

local sources = {
  actions.gomodifytags,
  formatting.autopep8,
  formatting.erb_lint,
  formatting.prettier,
  formatting.isort,
  formatting.golines,
  formatting.goimports_reviser,
  formatting.taplo,
  formatting.stylua,
  formatting.rustywind,
  formatting.rustfmt,
  formatting.standardrb,
  formatting.sql_formatter,
  hover.dictionary,
  lint.curlylint,
  lint.djlint,
  lint.erb_lint,
  lint.mypy,
  lint.rubocop,
  lint.shellcheck,
  lint.stylelint,
  lint.textlint,
  lint.staticcheck,
}

null_ls.setup {
  debug = true,
  sources = sources,
  on_attach = function(client, bufnr)
    if client.supports_method "textDocument/formatting" then
      vim.api.nvim_clear_autocmds { group = augroup, buffer = bufnr }
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format {
            bufnr = bufnr,
            filter = function()
              return client.name == "null-ls"
            end,
          }
        end,
      })
    end
  end,
}
