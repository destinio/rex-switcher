# rex-switcher

A fuzzy session and pane switcher for [Rex](https://www.superlogical.com/rex), like tmux's `prefix + w`.
It opens in a floating pane, lists every pane in every session, and shows which agents are working, done, or need you.

```
switch>
  enter go · ctrl-/ preview · ctrl-x close · ctrl-r rename · esc cancel
▌ my-project  2 tabs (current)  1 need you · 1 working
     ● Fix login redirect               claude   ~/src/app       ⚠ needs you (permission)  Allow edit to auth.ts?
       Write migration tests            claude   ~/src/app       ⟳ working  Running tests
       tab 2                            bash     ~/src/app
  side-quest  1 tab  1 done
     ● Explore caching ideas            claude   ~/src/cache     ✓ done
```

## Features

- **Every session at once.** Panes are grouped under their session. Picking a session row jumps to the pane last active in it.
- **Named like the sidebar.** Each pane shows its terminal title (Claude Code sets it to the task), then the tab name.
- **Live agent status**, refreshed every 2 seconds:

  | Badge | Meaning |
  |---|---|
  | ⚠ needs you | Waiting on a permission, an answer, or a login |
  | ✗ error | Failed and stopped |
  | ✓ done | Finished and you haven't looked yet |
  | ⟳ working | Busy, with its current task and % if it reports one |
  | · idle | At its prompt |

  Status comes from Rex's program status, which Claude Code reports and other agents can report via `rex skill setup`.
- **Fuzzy search** on session, task name, program, folder, and status (try typing `need`).

## Keys

| Key | Action |
|---|---|
| `enter` | Go to the pane or session |
| `ctrl-/` | Show or hide a preview of the pane's screen (hidden by default) |
| `ctrl-x` | Close the pane, or the whole session on a session row (asks first) |
| `ctrl-r` | Rename the session on a session row, or the tab on a pane row |
| `esc` | Cancel |

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/destinio/rex-switcher/main/install.sh | bash
```

That clones this repo to `~/.local/share/rex-switcher`, links it into your Rex config, adds one line to `init.lua`, and reloads Rex. ([Read the script](install.sh) first if you like.) Then press **`ctrl+a f`**.

Run the same command again to update.

It needs the Rex app (for the `rex` command) plus `fzf`, `jq`, `curl`, and `git`. The installer checks and tells you what's missing (`brew install fzf jq`).

**Turn on Remote Control** (Rex Settings → Server) to jump to panes in other sessions.
Without it, switching within the current session still works.

Or by hand:

```sh
git clone https://github.com/destinio/rex-switcher && cd rex-switcher && ./install.sh
```

### Different key

```sh
curl -fsSL https://raw.githubusercontent.com/destinio/rex-switcher/main/install.sh | KEY='ctrl+b>w' bash
```

Or edit the line it added to `init.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/rex/switcher/bind.lua")({
  key = "ctrl+a>f",              -- key or sequence
  bounds = { 0.15, 0.1, 0.7, 0.8 }, -- floating pane x, y, width, height (fractions of the window)
})
```

## How it works

| File | Role |
|---|---|
| `switcher/bind.lua` | Binds the key; opens a floating pane running `switcher.sh` |
| `switcher/list.lua` | Gathers sessions, panes, titles, and statuses in one `rex do` call |
| `install.sh` | Installs, updates (`git pull`), or uninstalls (`--uninstall`) |
| `switcher/switcher.sh` | Runs fzf, handles close/rename, and switches the app with `session.select` |

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/destinio/rex-switcher/main/install.sh | bash -s -- --uninstall
```

This removes the line from `init.lua` and the link, then reloads Rex. Delete `~/.local/share/rex-switcher` too if you like.

## License

MIT
