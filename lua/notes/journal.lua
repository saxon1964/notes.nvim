local M = {}

--- Open the daily note for the given date (YYYY-MM-DD), defaulting to today.
--- Creates the file (and parent directories) if it does not exist.
function M.open_daily(date_str)
  local cfg   = require("notes.config").get()
  local files = require("notes.files")

  local year, month, day, display

  if date_str and date_str ~= "" then
    year, month, day = date_str:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if not year then
      vim.notify("Invalid date format — expected YYYY-MM-DD", vim.log.levels.ERROR)
      return
    end
    display = date_str
  else
    year    = os.date("%Y")
    month   = os.date("%m")
    day     = os.date("%d")
    display = os.date("%Y-%m-%d")
  end

  local rel_path = string.format("%s/%s/%s/%s.md", cfg.journal_dir, year, month, day)
  local abs      = cfg.vault .. "/" .. rel_path

  if vim.fn.filereadable(abs) == 0 then
    files.create(rel_path, cfg.templates.daily(display))
  end

  vim.cmd.edit(abs)
end

return M
