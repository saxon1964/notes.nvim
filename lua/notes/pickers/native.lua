-- Picker backend using vim.ui.select (built-in).
-- snacks.nvim and dressing.nvim both override vim.ui.select automatically,
-- so this backend benefits from those plugins without any extra code here.
local M = {}

function M.pick(items, opts, on_choice)
  vim.ui.select(items, {
    prompt      = opts.prompt or "Notes",
    format_item = opts.format_item,
  }, function(choice)
    if choice then on_choice(choice) end
  end)
end

return M
