local M = {}

--- Full-text search across all vault notes.
--- Delegates to the active picker backend's live-grep capability.
function M.search(query)
  local cfg = require("notes.config").get()
  require("notes.pickers").search(cfg.vault, query)
end

return M
