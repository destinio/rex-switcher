#!/usr/bin/env bash
# Installs rex-switcher into your Rex config directory and enables it in init.lua.
#   ./install.sh           copy the files
#   ./install.sh --link    symlink instead, so `git pull` updates you
#   KEY='ctrl+b>w' ./install.sh   bind a different key (default ctrl+a>f)
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
key="${KEY:-ctrl+a>f}"

if [[ -n "${REX_CONFIG:-}" ]]; then config="$REX_CONFIG"
else config="${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua"; fi
dest="$(dirname "$config")/switcher"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
missing=()
for dep in rex fzf jq curl; do command -v "$dep" >/dev/null || missing+=("$dep"); done
if ((${#missing[@]})); then
  echo "Missing: ${missing[*]}"
  echo "Install them first (rex comes with the Rex app; the rest: brew install ${missing[*]/rex/})"
  exit 1
fi

mkdir -p "$(dirname "$config")"
if [[ -f "$dest/bind.lua" ]]; then
  rm -rf "$dest" # an earlier install of this; replace it
elif [[ -e "$dest" || -L "$dest" ]]; then
  backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
  mv "$dest" "$backup"
  echo "Moved your existing $dest to $backup"
fi
if [[ "${1:-}" == "--link" ]]; then
  ln -s "$repo/switcher" "$dest"
  echo "Linked $dest -> $repo/switcher"
else
  cp -R "$repo/switcher" "$dest"
  echo "Copied switcher to $dest"
fi
chmod +x "$dest/switcher.sh"

# write the path relative to $HOME when possible, so a shared dotfiles init.lua works on any Mac
bind="\"$dest/bind.lua\""
[[ "$dest" == "$HOME"/* ]] && bind="os.getenv(\"HOME\") .. \"${dest#"$HOME"}/bind.lua\""
line="dofile($bind)({ key = \"$key\" })"
if [[ -f "$config" ]] && grep -q "switcher/bind.lua" "$config"; then
  echo "init.lua already loads the switcher; left it alone."
else
  printf '\n-- rex-switcher: fuzzy session/pane switcher\n%s\n' "$line" >>"$config"
  echo "Added to $config:"
  echo "  $line"
fi

rex config check >/dev/null && rex config reload >/dev/null && echo "Reloaded Rex config."
cat <<EOF

Done. Press ${key//>/ } in Rex to open the switcher.
To jump between sessions, turn on Remote Control in Rex Settings → Server.
EOF
