local M = {}

local defaults = {
  vault       = nil,   -- set in setup(); falls back to cwd
  picker      = "auto", -- auto | telescope | fzf | snacks | native
  inbox_dir   = "inbox",
  journal_dir = "journal",
  index_file  = "INDEX.md",
  auto_index  = true,
  keymaps = {
    insert_link     = "<leader>nl",
    insert_new_link = "<leader>nn",
    follow_link     = "<leader>nf",
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
  if not current.vault then
    current.vault = vim.fn.getcwd()
  end
  -- Normalize: strip trailing slash
  current.vault = current.vault:gsub("[/\\]+$", "")
end

function M.get()
  return current
end

return M
