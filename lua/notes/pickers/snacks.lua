-- Picker backend for snacks.nvim.
-- snacks.nvim overrides vim.ui.select automatically, so delegating to
-- the native backend already produces the snacks-enhanced UI.
local M = {}

function M.pick(items, opts, on_choice)
  return require("notes.pickers.native").pick(items, opts, on_choice)
end

function M.search(vault, query)
  require("snacks").picker.grep({
    cwd    = vault,
    search = query or "",
  })
end

return M
