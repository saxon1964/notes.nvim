local M = {}

--- The marker file that identifies a vault root directory.
M.MARKER = ".notesroot"

local function cfg() return require("notes.config").get() end

--- Walk upward from start_dir (defaults to cwd) looking for the marker file.
--- Returns the vault root path, or nil if not found.
function M.find_vault_root(start_dir)
  local dir = start_dir or vim.fn.getcwd()
  while true do
    if vim.fn.filereadable(dir .. "/" .. M.MARKER) == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then return nil end  -- reached filesystem root
    dir = parent
  end
end

--- Create the marker file and standard subdirectories in path.
--- Notifies the user on success.
function M.init_vault(path)
  local c = cfg()
  local fh = io.open(path .. "/" .. M.MARKER, "w")
  if fh then fh:close() end
  vim.fn.mkdir(path .. "/" .. c.inbox_dir,   "p")
  vim.fn.mkdir(path .. "/" .. c.journal_dir, "p")
  vim.notify("notes.nvim: vault initialized at " .. path, vim.log.levels.INFO)
end

--- Return all .md files in the vault, as paths relative to vault root.
--- INDEX.md is excluded.
function M.list()
  local c = cfg()
  local vault = c.vault
  local index_abs = vault .. "/" .. c.index_file
  local raw = vim.fn.glob(vault .. "/**/*.md", false, true)
  local result = {}
  for _, abs in ipairs(raw) do
    if abs ~= index_abs then
      -- strip "vault/" prefix
      table.insert(result, abs:sub(#vault + 2))
    end
  end
  table.sort(result)
  return result
end

--- Create a file (and all parent directories) if it does not yet exist.
--- content defaults to empty string.
--- Returns the absolute path.
function M.create(rel_path, content)
  local vault = cfg().vault
  local abs = vault .. "/" .. rel_path
  vim.fn.mkdir(vim.fn.fnamemodify(abs, ":h"), "p")
  if vim.fn.filereadable(abs) == 0 then
    local fh = io.open(abs, "w")
    if fh then
      fh:write(content or "")
      fh:close()
    end
  end
  return abs
end

--- Compute a relative path FROM one vault-relative file TO another.
--- e.g. relative("topics/neovim.md", "topics/neovim/plugins.md")
---      → "neovim/plugins.md"
function M.relative(from_file, to_file)
  local function split(path)
    if not path or path == "" or path == "." then return {} end
    local parts = {}
    for part in path:gmatch("[^/]+") do
      table.insert(parts, part)
    end
    return parts
  end

  local from_dir = vim.fn.fnamemodify(from_file, ":h")
  if from_dir == "." then from_dir = "" end

  local fp = split(from_dir)
  local tp = split(to_file)

  -- Find length of common prefix (directories only, not the filename itself)
  local common = 0
  for i = 1, math.min(#fp, #tp - 1) do
    if fp[i] == tp[i] then
      common = i
    else
      break
    end
  end

  local rel = {}
  for _ = common + 1, #fp do
    table.insert(rel, "..")
  end
  for i = common + 1, #tp do
    table.insert(rel, tp[i])
  end

  if #rel == 0 then return to_file end
  return table.concat(rel, "/")
end

--- Return the vault-relative path of the current buffer.
function M.current_rel()
  local vault = cfg().vault
  local abs = vim.api.nvim_buf_get_name(0)
  if abs:sub(1, #vault) == vault then
    return abs:sub(#vault + 2)
  end
  return abs
end

--- Return the "children directory" for a vault-relative file.
--- e.g. "topics/neovim.md" → "topics/neovim"
---      "note.md"          → "note"
function M.child_dir(rel_file)
  local dir  = vim.fn.fnamemodify(rel_file, ":h")
  local stem = vim.fn.fnamemodify(rel_file, ":t:r")
  if dir == "." then
    return stem
  end
  return dir .. "/" .. stem
end

--- Convert a title to a filesystem-friendly slug.
function M.slugify(title)
  return title
    :lower()
    :gsub("[%s_]+", "-")
    :gsub("[^%w%-]", "")
    :gsub("%-+", "-")
    :gsub("^%-+", "")
    :gsub("%-+$", "")
end

return M
