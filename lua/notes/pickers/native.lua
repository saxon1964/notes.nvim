-- Picker backend using vim.ui.select (built-in).
-- snacks.nvim and dressing.nvim both override vim.ui.select automatically,
-- so this backend benefits from those plugins without any extra code here.
local M = {}

local function notify(msg, level)
  vim.notify(msg, level, { title = "notes.nvim" })
end

function M.pick(items, opts, on_choice)
  vim.ui.select(items, {
    prompt      = opts.prompt or "Notes",
    format_item = opts.format_item,
  }, function(choice)
    if choice then on_choice(choice) end
  end)
end

function M.search(vault, query)
  if not query or query == "" then
    vim.ui.input({ prompt = "Search notes: " }, function(input)
      if input and input ~= "" then M.search(vault, input) end
    end)
    return
  end

  local has_rg = vim.fn.executable("rg") == 1
  local cmd
  if has_rg then
    cmd = string.format("rg --vimgrep %s --type md %s",
      vim.fn.shellescape(query), vim.fn.shellescape(vault))
  else
    cmd = string.format("grep -rn %s --include='*.md' %s",
      vim.fn.shellescape(query), vim.fn.shellescape(vault))
  end

  local raw = vim.fn.systemlist(cmd)
  local qf  = {}
  for _, line in ipairs(raw) do
    local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)")
    if file then
      table.insert(qf, { filename = file, lnum = tonumber(lnum),
                         col = tonumber(col), text = vim.trim(text) })
    end
  end

  if #qf == 0 then
    notify("No results for: " .. query, vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist(qf, "r")
  vim.fn.setqflist({}, "a", { title = "Notes search: " .. query })
  vim.cmd.copen()
  notify(string.format("%d result(s) for '%s'", #qf, query), vim.log.levels.INFO)
end

return M
