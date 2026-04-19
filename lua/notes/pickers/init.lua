-- Auto-detects and dispatches to the configured picker backend.
local M = {}

local function detect()
  local choice = require("notes.config").get().picker
  if choice ~= "auto" then return choice end

  if pcall(require, "telescope.actions") then return "telescope" end
  if pcall(require, "fzf-lua")           then return "fzf"       end
  return "native"
end

--- Present a list of items and call on_choice(item) with the selected one.
--- opts: { prompt = string, format_item = function }
function M.pick(items, opts, on_choice)
  local backend = detect()
  local ok, mod = pcall(require, "notes.pickers." .. backend)
  if not ok then mod = require("notes.pickers.native") end
  mod.pick(items, opts, on_choice)
end

--- Open a live-grep search over vault using the active picker backend.
--- Falls back to quickfix for the native backend.
function M.search(vault, query)
  local backend = detect()
  local ok, mod = pcall(require, "notes.pickers." .. backend)
  if not ok then mod = require("notes.pickers.native") end
  mod.search(vault, query)
end

return M
