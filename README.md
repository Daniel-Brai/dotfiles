# dotfiles

My dev setup on Fedora: Neovim, tmux and zsh, running in Ghostty.

## What's here

| Path | Goes to |
|---|---|
| `nvim/` | `~/.config/nvim` |
| `.tmux.conf` | `~/.tmux.conf` |
| `.zshrc` | `~/.zshrc` |

## Neovim

Neovim 0.12 with [lazy.nvim](https://github.com/folke/lazy.nvim). Plugins install on first start, or run `:Lazy sync`.

- `lua/core/` has options, keymaps and the LSP setup
- `lua/plugins/` has one file per area (LSP, completion, linting, formatting, telescope, treesitter, UI, git)
- `lua/tlaplus/` is TLA+ support: snippets, completion, `.cfg` checks and highlighting, go to definition, `:TlaCheck` output with TLA+ symbols, and `:TlaPdf` / `:TlaTex`
- `<leader>g` keymaps follow the zsh git aliases (`<leader>gs` is `git status`, `<leader>gph` is push, and so on) and open Neogit

Images and PDFs render inside Neovim through snacks.nvim. That needs a terminal with the kitty graphics protocol (Ghostty, kitty), ImageMagick, and Ghostscript for PDFs.

TLA+ support expects `tla2tools.jar` at `~/.local/share/tla/tla2tools.jar` (set in `.zshrc`), plus `pdflatex` and [tlauc](https://github.com/tlaplus-community/tlauc) for PDFs.

## tmux

Plugins go through [tpm](https://github.com/tmux-plugins/tpm). Install it, then press prefix + `I`. `Ctrl+h/j/k/l` moves between tmux panes and Neovim splits. `allow-passthrough` is on so images render inside tmux.

## zsh

Oh My Zsh with the `robbyrussell` theme. Tools it sets up: asdf, pnpm, bun, sdkman, opam and the TLA+ tools.
