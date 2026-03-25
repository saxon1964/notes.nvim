local M = {}

--- Show all notes in the vault that contain a link to the current file.
--- Results are shown in the quickfix list.
function M.show()
  local cfg   = require("notes.config").get()
  local files = require("notes.files")
  local vault = cfg.vault

  local current_abs = vim.api.nvim_buf_get_name(0)
  local current_rel = files.current_rel()
  local stem        = vim.fn.fnamemodify(current_rel, ":t:r")

  -- Build a pattern that matches both markdown and wiki-style references.
  -- We search for the stem; false positives are rare and visible in context.
  local pattern = stem

  local has_rg = vim.fn.executable("rg") == 1
  local cmd
  if has_rg then
    cmd = string.format(
      "rg --vimgrep %s --type md %s",
      vim.fn.shellescape(pattern),
      vim.fn.shellescape(vault)
    )
  else
    cmd = string.format(
      "grep -rn %s --include='*.md' %s",
      vim.fn.shellescape(pattern),
      vim.fn.shellescape(vault)
    )
  end

  local raw = vim.fn.systemlist(cmd)
  if #raw == 0 then
    vim.notify("No backlinks found for: " .. stem, vim.log.levels.INFO)
    return
  end

  local index_abs = vault .. "/" .. cfg.index_file
  local qf = {}

  for _, line in ipairs(raw) do
    -- Skip matches in the current file and in INDEX.md
    if not line:find(current_abs, 1, true) and not line:find(index_abs, 1, true) then
      -- vimgrep format:  file:lnum:col:text
      local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)")
      if file then
        table.insert(qf, {
          filename = file,
          lnum     = tonumber(lnum),
          col      = tonumber(col),
          text     = vim.trim(text),
        })
      end
    end
  end

  if #qf == 0 then
    vim.notify("No backlinks found for: " .. stem, vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist(qf, "r")
  vim.fn.setqflist({}, "a", { title = "Backlinks: " .. stem })
  vim.cmd.copen()
  vim.notify(string.format("%d backlink(s) for '%s'", #qf, stem), vim.log.levels.INFO)
end

return M
