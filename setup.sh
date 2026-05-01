#!/usr/bin/env bash
set -euo pipefail

REMOTE_URL="${DOTFILES_REMOTE:-https://github.com/jeffniu-openai/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$script_dir/vim/vimrc" || ! -f "$script_dir/tmux/tmux.conf" ]]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to install dotfiles" >&2
    exit 1
  fi

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" pull --ff-only
  else
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone "$REMOTE_URL" "$DOTFILES_DIR"
  fi

  exec "$DOTFILES_DIR/setup.sh" "$@"
fi

timestamp="$(date +%Y%m%d%H%M%S)"

backup_path() {
  local target="$1"
  local backup="${target}.backup.${timestamp}"
  mv "$target" "$backup"
  echo "backed up $target -> $backup"
}

link_file() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    local current
    current="$(readlink "$target")"
    if [[ "$current" == "$source" ]]; then
      echo "already linked $target"
      return
    fi
    rm "$target"
  elif [[ -e "$target" ]]; then
    backup_path "$target"
  fi

  ln -s "$source" "$target"
  echo "linked $target -> $source"
}

mkdir -p "$HOME/.vim/undo" "$HOME/.vim/swap" "$HOME/.vim/backup"

link_file "$script_dir/vim/vimrc" "$HOME/.vimrc"
link_file "$script_dir/vim/openai-python.vim" "$HOME/.vim/openai-python.vim"
link_file "$script_dir/tmux/tmux.conf" "$HOME/.tmux.conf"

if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf"
  echo "reloaded tmux config"
fi

echo "dotfiles setup complete"
