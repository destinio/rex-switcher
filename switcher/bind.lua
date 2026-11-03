-- rex-switcher: binds a key that opens the switcher in a floating pane.
-- In ~/.config/rex/init.lua:
--   dofile(os.getenv("HOME") .. "/.config/rex/switcher/bind.lua")({ key = "ctrl+a>f" })
-- Options (all optional):
--   key     key or sequence to bind           default "ctrl+a>f"
--   bounds  {x, y, w, h} as window fractions  default {0.15, 0.1, 0.7, 0.8}
return function(opts)
  opts = opts or {}
  -- switcher.sh sits next to this file, wherever it was installed
  local here = debug.getinfo(1, "S").source:gsub("^@", "")
  local script = here:match("^(.*)/[^/]*$") .. "/switcher.sh"

  rex.bind(opts.key or "ctrl+a>f", function(ctx)
    local _, err = rex.session.new_layer({
      bounds = opts.bounds or { 0.15, 0.1, 0.7, 0.8 },
      focus = true,
      layout = {
        block = {
          flavor = "com.superlogical.terminal.shell",
          label = "switcher",
          options = { command = { "bash", script, ctx.client_id or "" } },
        },
      },
    })
    if err then rex.log("rex-switcher: " .. tostring(err)) end
    return true
  end)
end
