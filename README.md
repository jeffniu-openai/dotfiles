# dotfiles

Local terminal/editor defaults for Python development, with a repo-aware Vim setup for
`~/code/openai`.

## One-click setup

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jeffniu-openai/dotfiles/main/setup.sh)"
```

The setup script clones or updates this repo at `~/.dotfiles`, backs up existing target
files, and symlinks:

- `~/.vimrc`
- `~/.vim/openai-python.vim`
- `~/.tmux.conf`

## Vim

The Vim config keeps `hlsearch`, `number`, and `relativenumber` enabled. It also adds
quickfix-backed helpers for the OpenAI monorepo:

- `<leader>of` opens files with `rg --files | fzf`
- `<leader>og` searches the repo with `rg`
- `<leader>or` runs `ruff check`
- `<leader>oR` runs `ruff check --fix`
- `<leader>op` runs `pyright`
- `<leader>ofm` runs Ruff import fixes and Black formatting
- `<leader>ot` runs pytest for the current file

## tmux

The tmux config enables mouse support, vi-style copy mode, current-directory splits,
Vim-like pane navigation, fast window navigation, and a compact top status line.
