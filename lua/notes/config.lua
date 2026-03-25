local M = {}

local defaults = {
  vault       = nil,    -- auto-detected via .notesroot marker; or set explicitly
  picker      = "auto", -- auto | telescope | fzf | snacks | native
  inbox_dir   = "inbox",
  journal_dir = "journal",
  index_file  = "INDEX.md",
  auto_index  = true,
  keymaps = {
    insert_link     = "<leader>nl",
    insert_new_link = "<leader>nn",
    follow_link     = "<leader>no",
    backlinks       = "<leader>nb",
    daily           = "<leader>nd",
    search          = "<leader>ns",
    index           = "<leader>ni",
  },
  templates = {
    daily = function(date)
      return string.format("# %s\n\n## Notes\n\n## Tasks\n\n", date)
    end,
    new_note = function(title)
      return string.format("# %s\n\n", title)
    end,
  },
}

local current = vim.deepcopy(defaults)

function M.setup(opts)
  current = vim.tbl_deep_extend("force", defaults, opts or {})
  if current.vault then
    -- Explicit vault provided — normalise path
    current.vault = current.vault:gsub("[/\\]+$", "")
  end
  -- If vault is nil, auto-detection runs lazily on first use (see init.lua)
end

--- Update the vault path at runtime (used by auto-detection).
function M.set_vault(path)
  current.vault = path:gsub("[/\\]+$", "")
end

function M.get()
  return current
end

return M
