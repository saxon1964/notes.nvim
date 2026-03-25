local M = {}

--- Full-text search across all vault notes.
--- Results are shown in the quickfix list.
--- If query is nil/empty the user is prompted.
function M.search(query)
  if not query or query == "" then
    vim.ui.input({ prompt = "Search notes: " }, function(input)
      if input and input ~= "" then
        M.search(input)
      end
    end)
    return
  end

  local cfg   = require("notes.config").get()
  local vault = cfg.vault

  local has_rg = vim.fn.executable("rg") == 1
  local cmd
  if has_rg then
    cmd = string.format(
      "rg --vimgrep %s --type md %s",
      vim.fn.shellescape(query),
      vim.fn.shellescape(vault)
    )
  else
    cmd = string.format(
      "grep -rn %s --include='*.md' %s",
      vim.fn.shellescape(query),
      vim.fn.shellescape(vault)
    )
  end

  local raw = vim.fn.systemlist(cmd)
  if #raw == 0 then
    vim.notify("No results for: " .. query, vim.log.levels.INFO)
    return
  end

  local qf = {}
  for _, line in ipairs(raw) do
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

  if #qf == 0 then
    vim.notify("No results for: " .. query, vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist(qf, "r")
  vim.fn.setqflist({}, "a", { title = "Notes search: " .. query })
  vim.cmd.copen()
  vim.notify(string.format("%d result(s) for '%s'", #qf, query), vim.log.levels.INFO)
end

return M
