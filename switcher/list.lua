-- Prints the switcher's rows for fzf, one session row followed by its panes:
--   kind <TAB> session_id <TAB> window_id <TAB> block_id <TAB> display text
-- kind is "session" or "pane". A session row points at its active tab's focused pane.
-- Run: rex do ~/.config/rex/switcher/list.lua skip=<block to leave out>
local TERM = "com.superlogical.terminal"
local skip = rex.args.skip or ""
local home = os.getenv("HOME") or ""

local C = { reset = "\27[0m", dim = "\27[2m", session = "\27[1;35m", tab = "\27[34m",
  prog = "\27[36m", mark = "\27[33m", red = "\27[1;31m", yellow = "\27[33m", green = "\27[32m" }

-- program states, most urgent first (see Rex docs: program status)
local RANK = { blocked = 1, error = 2, done = 3, working = 4, idle = 5 }
local BADGE = {
  blocked = function(r) return C.red .. "⚠ needs you" .. (r.kind and (" (" .. r.kind .. ")") or "") end,
  error = function() return C.red .. "✗ error" end,
  done = function() return C.green .. "✓ done" end,
  working = function(r) return C.yellow .. "⟳ working" .. (r.progress and (" " .. r.progress .. "%") or "") end,
  idle = function() return C.dim .. "· idle" end,
}

local function short_path(p)
  if not p or p == "" then return "" end
  p = p:gsub("^file://[^/]*", "")
  if home ~= "" and p:sub(1, #home) == home then p = "~" .. p:sub(#home + 1) end
  return p
end

local function clip(s, n)
  s = (s or ""):gsub("%s+", " ")
  -- count UTF-8 characters by their lead bytes (Rex's Lua has no utf8 library)
  local count, cut = 0, nil
  for pos in s:gmatch("()[^\128-\191]") do
    count = count + 1
    if count == n then cut = pos end
  end
  if count > n then s = s:sub(1, cut - 1) .. "…" end
  return s
end

-- pad to n characters (string.format's %-Ns counts bytes, which breaks on "…" and emoji)
local function pad(s, n)
  local count = select(2, s:gsub("[^\128-\191]", ""))
  return s .. string.rep(" ", math.max(0, n - count))
end

-- the most urgent status record a block reports, or nil
local function status_of(sid, id)
  local r = rex.block.call(TERM, "program_status", { session_id = sid, block_id = id })
  local best
  for _, rec in ipairs(r and r.records or {}) do
    if RANK[rec.state] and (not best or RANK[rec.state] < RANK[best.state]) then best = rec end
  end
  return best
end

local function each_block(node, out)
  if not node then return end
  if node.block_id then out[#out + 1] = node.block_id end
  if node.split then
    each_block(node.split.before, out)
    each_block(node.split.after, out)
  end
end

local function row(kind, sid, wid, bid, text)
  print(table.concat({ kind, sid, wid or "", bid or "", text }, "\t"))
end

local list = rex.call("session.list") or {}
for _, s in ipairs(list.sessions or {}) do
  -- a script can only read sessions it's attached to; attach returns the view
  local att = rex.session.attach { session_id = s.session_id }
  local view = att and att.view or {}
  local windows = view.windows or {}

  local active
  for _, w in ipairs(windows) do
    if w.window_id == view.active_window_id then active = w end
  end
  active = active or windows[1] or {}

  local panes, counts = {}, {}
  for wi, w in ipairs(windows) do
    local tab = (w.label and not w.label:match("^Window %x+$")) and w.label or ("tab " .. wi)
    for _, layer in ipairs(w.layers or {}) do
      local labels, order = {}, {}
      for _, b in ipairs(layer.blocks or {}) do labels[b.block_id] = b.label end
      each_block(layer.layout, order)
      for _, id in ipairs(order) do
        if id ~= skip then
          local p = rex.block.call(TERM, "process", { session_id = s.session_id, block_id = id })
          local fg = p and p.foreground or {}
          local prog = (fg.argv0 or fg.name or labels[id] or "?"):gsub("^%-", "")
          local st = status_of(s.session_id, id)
          local badge = ""
          if st then
            counts[st.state] = (counts[st.state] or 0) + 1
            badge = string.format("  %s%s %s%s", BADGE[st.state](st), C.reset, C.dim, clip(st.msg, 50))
          end
          -- name the row like the app's sidebar: the terminal title (Claude sets it to the task),
          -- then a custom tab name, then "tab N"
          local t = rex.block.call(TERM, "title", { session_id = s.session_id, block_id = id })
          local name = (t and t.title or ""):gsub("^[^%w%p]+%s+", "") -- drop a leading spinner glyph
          if name == "" then name = tab end
          local mark = (id == w.focused_block_id) and (C.mark .. "●" .. C.reset) or " "
          panes[#panes + 1] = { w.window_id, id, string.format("   %s %s%s%s %s%-10s%s %s%-22s%s%s%s",
            mark, C.tab, pad(clip(name, 36), 36), C.reset, C.prog, clip(prog, 10), C.reset,
            C.dim, clip(short_path(fg.cwd), 22), C.reset, badge, C.reset) }
        end
      end
    end
  end

  -- session row: label, tab count, and a summary of anything worth a look
  local summary = {}
  if counts.blocked then summary[#summary + 1] = C.red .. counts.blocked .. " need you" end
  if counts.error then summary[#summary + 1] = C.red .. counts.error .. " error" end
  if counts.done then summary[#summary + 1] = C.green .. counts.done .. " done" end
  if counts.working then summary[#summary + 1] = C.yellow .. counts.working .. " working" end
  local here = s.session_id == os.getenv("REX_SESSION")
  row("session", s.session_id, active.window_id, active.focused_block_id,
    string.format("%s%s%s  %s%d tab%s%s%s  %s%s", C.session, s.label or s.session_id, C.reset,
      C.dim, #windows, #windows == 1 and "" or "s", here and " (current)" or "", C.reset,
      table.concat(summary, C.reset .. C.dim .. " · " .. C.reset), C.reset))

  for _, p in ipairs(panes) do row("pane", s.session_id, p[1], p[2], p[3]) end
end
