-- Picker backend using fzf-lua
local M = {}

function M.pick(items, opts, on_choice)
  require("fzf-lua").fzf_exec(items, {
    prompt  = (opts.prompt or "Notes") .. "> ",
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          on_choice(selected[1])
        end
      end,
    },
  })
end

return M
