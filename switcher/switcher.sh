#!/usr/bin/env bash
# rex-switcher: fuzzy session/pane switcher for Rex, like tmux prefix+w.
#   switcher.sh [client_id]          open the picker (client_id = the Rex app, used to switch sessions)
#   switcher.sh list|close|rename …  helpers that fzf's key bindings call
# Keys: enter go · ctrl-/ preview · ctrl-x close · ctrl-r rename · esc cancel. Statuses refresh every 2s.
set -uo pipefail
# Rex panes may not get Homebrew's PATH, so look there too for fzf and jq
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

for dep in fzf jq curl; do
  command -v "$dep" >/dev/null || { echo "rex-switcher needs $dep. Install it (brew install $dep) and try again."; read -rsn1; exit 1; }
done

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
dir="$(dirname "$self")"

case "${1:-}" in
list)
  exec rex do "$dir/list.lua" "skip=${REX_BLOCK:-}" 2>/dev/null
  ;;
refresh) # runs in the background; reloads fzf every 2s so statuses stay live, stops when fzf exits
  exec >/dev/null 2>&1
  while sleep 2; do
    curl -fsS -XPOST "localhost:$FZF_PORT" -d "reload-sync($self list)" || exit 0
  done
  ;;
close) # kind session window block
  clear
  kind=$2 session=$3 block=$5
  if [[ $kind == session ]]; then what="session $(rex session inspect "$session" --json | jq -r .label)"
  else what="this pane"; fi
  read -rp "Close $what? [y/N] " ok </dev/tty
  [[ $ok == [yY]* ]] || exit 0
  if [[ $kind == session ]]; then rex kill "$session"
  else rex block close -s "$session" "$block"; fi >/dev/null
  exit 0
  ;;
rename) # kind session window block
  clear
  kind=$2 session=$3 window=$4
  if [[ $kind == session ]]; then read -rp "New session name: " name </dev/tty
  else read -rp "New tab name: " name </dev/tty; fi
  [[ -n $name ]] || exit 0
  if [[ $kind == session ]]; then rex session rename "$session" "$name"
  else rex window rename -s "$session" "$window" "$name"; fi >/dev/null
  exit 0
  ;;
esac

client="${1:-}"
args='{1} {2} {3} {4}'
pick=$("$self" list |
  fzf --ansi --delimiter=$'\t' --with-nth=5 --no-sort --reverse --track --listen \
      --bind="start:execute-silent($self refresh &)" \
      --prompt='switch> ' \
      --header='enter go · ctrl-/ preview · ctrl-x close · ctrl-r rename · esc cancel' \
      --preview='rex capture -s {2} -b {4} --trim 2>/dev/null | tail -n "$FZF_PREVIEW_LINES"' \
      --preview-window='down,50%,border-top,hidden' \
      --bind='ctrl-/:toggle-preview' \
      --bind="ctrl-x:execute($self close $args)+reload($self list)" \
      --bind="ctrl-r:execute($self rename $args)+reload($self list)") || exit 0

IFS=$'\t' read -r _ session window block _ <<<"$pick"

# Another session needs the app to switch to it (needs Remote Control in Rex Settings → Server).
if [[ "$session" != "${REX_SESSION:-}" ]]; then
  if ! rex ${client:+-C "$client"} do session.select "session_id=$session" "window_id=$window" >/dev/null 2>&1; then
    echo "Couldn't switch the app to that session."
    echo "Turn on Remote Control in Rex Settings → Server, then try again."
    read -rsn1 -p "Press any key to close."
    exit 1
  fi
fi

[[ -n $block ]] && rex focus -s "$session" "$block" >/dev/null
