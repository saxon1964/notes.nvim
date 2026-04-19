local M = {}

local function notify(msg, level)
  vim.notify(msg, level, { title = "notes.nvim" })
end

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
    notify("No backlinks found for: " .. stem, vim.log.levels.INFO)
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
    notify("No backlinks found for: " .. stem, vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist(qf, "r")
  vim.fn.setqflist({}, "a", { title = "Backlinks: " .. stem })
  vim.cmd.copen()
  notify(string.format("%d backlink(s) for '%s'", #qf, stem), vim.log.levels.INFO)
end

--- Return a list of absolute file paths that contain links to target_abs.
--- Uses stem-based search (same as show()); excludes INDEX.md.
function M.find(target_abs)
  local cfg      = require("notes.config").get()
  local vault    = cfg.vault
  -- Search for the filename with extension (e.g. "25.md") rather than just
  -- the stem ("25") to avoid false positives on short or numeric names.
  local filename = vim.fn.fnamemodify(target_abs, ":t")

  local has_rg = vim.fn.executable("rg") == 1
  local cmd
  if has_rg then
    cmd = string.format("rg -l --fixed-strings %s --type md %s",
      vim.fn.shellescape(filename), vim.fn.shellescape(vault))
  else
    cmd = string.format("grep -rl --fixed-strings %s --include='*.md' %s",
      vim.fn.shellescape(filename), vim.fn.shellescape(vault))
  end

  local index_abs = vault .. "/" .. cfg.index_file
  local result = {}
  for _, path in ipairs(vim.fn.systemlist(cmd)) do
    if path ~= target_abs and path ~= index_abs then
      table.insert(result, path)
    end
  end
  return result
end

return M
