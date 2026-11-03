#!/usr/bin/env bash
#
# rex-switcher: one-line install (run it again to update).
#
#   curl -fsSL https://raw.githubusercontent.com/destinio/rex-switcher/main/install.sh | bash
#
# Clones the repo to ~/.local/share/rex-switcher, links it into your Rex config,
# adds one line to init.lua, and reloads Rex.
# Read it first if you like: https://github.com/destinio/rex-switcher/blob/main/install.sh
#
# Options (environment variables):
#   KEY='ctrl+b>w'         bind a different key (default ctrl+a>f)
#   REX_SWITCHER_DIR=path  clone somewhere else (default ~/.local/share/rex-switcher)
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/destinio/rex-switcher/main/install.sh | bash -s -- --uninstall

set -euo pipefail

REPO="https://github.com/destinio/rex-switcher.git"
KEY_SET="${KEY:+1}"
KEY="${KEY:-ctrl+a>f}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

bold=$'\033[1m'; green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; dim=$'\033[2m'; reset=$'\033[0m'
say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$*"; }
die()  { printf '\n  %s✗%s %s\n\n' "$red" "$reset" "$*"; exit 1; }

if [[ -n "${REX_CONFIG:-}" ]]; then config="$REX_CONFIG"
else config="${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua"; fi
link="$(dirname "$config")/switcher"

say ""
say "  🔀 ${bold}rex-switcher${reset}"
say "  ${dim}fuzzy session/pane switcher for Rex, like tmux prefix+w${reset}"
say ""

# ------------------------------------------------------------------ uninstall

if [[ "${1:-}" == "--uninstall" ]]; then
  if [[ -f "$config" ]] && grep -q "switcher/bind.lua" "$config"; then
    tmp="$(mktemp)"
    grep -v -e "switcher/bind.lua" -e "^-- rex-switcher:" "$config" >"$tmp" && cat "$tmp" >"$config" && rm -f "$tmp"
    ok "removed the line from $config"
  fi
  if [[ -L "$link" ]]; then rm "$link"; ok "removed $link"
  elif [[ -e "$link" ]]; then warn "left $link alone (not a link this installer made)"; fi
  command -v rex >/dev/null 2>&1 && rex config reload >/dev/null 2>&1 && ok "reloaded Rex config"
  say ""
  say "  The clone is still at ${REX_SWITCHER_DIR:-$HOME/.local/share/rex-switcher}; delete it if you like."
  say ""
  exit 0
fi

# ------------------------------------------------------------------ prerequisites

command -v rex >/dev/null 2>&1 || die "rex isn't on your PATH. Install the Rex app (https://www.superlogical.com/rex), open it once, then run this again."
ok "rex"
missing=()
for dep in fzf jq curl git; do
  if command -v "$dep" >/dev/null 2>&1; then ok "$dep"; else missing+=("$dep"); fi
done
((${#missing[@]} == 0)) || die "Missing: ${missing[*]}. Install with:  brew install ${missing[*]}"

# ------------------------------------------------------------------ get the code

# Run from a clone (./install.sh) → use it. Piped from curl → clone or update our own copy.
here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -n "$here" && -f "$here/switcher/bind.lua" ]]; then
  src="$here"
  ok "using $src"
else
  src="${REX_SWITCHER_DIR:-$HOME/.local/share/rex-switcher}"
  if [[ -d "$src/.git" ]]; then
    git -C "$src" pull --quiet --ff-only || die "couldn't update $src (local changes?)"
    ok "updated $src"
  elif [[ -e "$src" ]]; then
    die "$src exists and isn't a clone. Remove it, or pick another folder: REX_SWITCHER_DIR=..."
  else
    mkdir -p "$(dirname "$src")"
    git clone --quiet "$REPO" "$src"
    ok "cloned into $src"
  fi
fi
chmod +x "$src/switcher/switcher.sh"

# ------------------------------------------------------------------ link into Rex

mkdir -p "$(dirname "$config")"
if [[ -L "$link" ]]; then
  rm "$link"
elif [[ -e "$link" ]]; then
  backup="$link.bak.$(date +%Y%m%d%H%M%S)"
  mv "$link" "$backup"
  warn "moved your existing $link to $backup"
fi
ln -s "$src/switcher" "$link"
ok "linked $link"

# path relative to $HOME when possible, so a shared dotfiles init.lua works on any machine
bind="\"$link/bind.lua\""
[[ "$link" == "$HOME"/* ]] && bind="os.getenv(\"HOME\") .. \"${link#"$HOME"}/bind.lua\""
if [[ -f "$config" ]] && grep -q "switcher/bind.lua" "$config"; then
  if [[ -n "$KEY_SET" ]]; then
    # rewrite the key in the existing line (plain-text match: keys contain characters sed treats specially)
    tmp="$(mktemp)"
    KEY="$KEY" awk '/switcher\/bind.lua/ { sub(/key = "[^"]*"/, "key = \"" ENVIRON["KEY"] "\"") } { print }' "$config" >"$tmp" &&
      cat "$tmp" >"$config" && rm -f "$tmp"
    ok "init.lua already loads the switcher; set its key to $KEY"
  else
    ok "init.lua already loads the switcher"
  fi
else
  printf '\n-- rex-switcher: fuzzy session/pane switcher\ndofile(%s)({ key = "%s" })\n' "$bind" "$KEY" >>"$config"
  ok "added one line to $config"
fi

if rex config check >/dev/null 2>&1 && rex config reload >/dev/null 2>&1; then
  ok "reloaded Rex config"
else
  warn "couldn't reload Rex. Open Rex, then run:  rex config reload"
fi

say ""
say "  ${bold}Next${reset}"
say "    Press ${bold}${KEY//>/ }${reset} in Rex to open the switcher."
say "    Turn on ${bold}Remote Control${reset} (Rex Settings → Server) to jump between sessions."
say "    ${dim}Update: run the same curl command again.${reset}"
say ""
