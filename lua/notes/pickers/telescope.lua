-- Picker backend using telescope.nvim
local M = {}

function M.pick(items, opts, on_choice)
  local actions       = require("telescope.actions")
  local action_state  = require("telescope.actions.state")
  local pickers       = require("telescope.pickers")
  local finders       = require("telescope.finders")
  local conf          = require("telescope.config").values

  pickers.new({}, {
    prompt_title = opts.prompt or "Notes",
    finder = finders.new_table({ results = items }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local sel = action_state.get_selected_entry()
        if sel then on_choice(sel[1]) end
      end)
      return true
    end,
  }):find()
end

function M.search(vault, query)
  require("telescope.builtin").live_grep({
    search_dirs  = { vault },
    default_text = query or "",
    prompt_title = "Search Notes",
  })
end

return M
