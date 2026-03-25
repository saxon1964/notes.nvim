local M = {}

local AUTO_HEADER = "<!-- AUTO-GENERATED: do not edit manually -->"

--- Build a nested table (tree) from a flat list of vault-relative paths.
local function build_tree(paths)
  local tree = {}
  for _, path in ipairs(paths) do
    local parts = vim.split(path, "/", { plain = true })
    local node  = tree
    for i, part in ipairs(parts) do
      if i == #parts then
        node.__files = node.__files or {}
        table.insert(node.__files, { name = part, path = path })
      else
        node[part] = node[part] or {}
        node = node[part]
      end
    end
  end
  return tree
end

--- Render the tree to a list of markdown lines (indented list).
local function render_tree(tree, indent)
  indent = indent or ""
  local lines = {}

  -- Files in this directory first
  local leaf_files = tree.__files or {}
  table.sort(leaf_files, function(a, b) return a.name < b.name end)
  for _, f in ipairs(leaf_files) do
    local stem = f.name:gsub("%.md$", "")
    table.insert(lines, string.format("%s- [%s](%s)", indent, stem, f.path))
  end

  -- Then subdirectories
  local dirs = {}
  for k in pairs(tree) do
    if k ~= "__files" then
      table.insert(dirs, k)
    end
  end
  table.sort(dirs)
  for _, dir in ipairs(dirs) do
    table.insert(lines, indent .. "- **" .. dir .. "/**")
    local sub = render_tree(tree[dir], indent .. "  ")
    for _, l in ipairs(sub) do
      table.insert(lines, l)
    end
  end

  return lines
end

--- Regenerate INDEX.md inside the vault.
function M.generate()
  local cfg        = require("notes.config").get()
  local files_mod  = require("notes.files")
  local vault      = cfg.vault
  local all        = files_mod.list()

  -- ── Recent notes (last 10 by mtime) ─────────────────────────────────────
  local with_mtime = {}
  for _, rel in ipairs(all) do
    table.insert(with_mtime, { rel = rel, mtime = vim.fn.getftime(vault .. "/" .. rel) })
  end
  table.sort(with_mtime, function(a, b) return a.mtime > b.mtime end)

  local recent_lines = {}
  for i = 1, math.min(10, #with_mtime) do
    local f    = with_mtime[i]
    local stem = vim.fn.fnamemodify(f.rel, ":t:r")
    local date = os.date("%Y-%m-%d %H:%M", f.mtime)
    table.insert(recent_lines, string.format("- [%s](%s) — %s", stem, f.rel, date))
  end

  -- ── Recent journal entries (last 7) ─────────────────────────────────────
  local journal_prefix = cfg.journal_dir .. "/"
  local journal_files  = {}
  for _, rel in ipairs(all) do
    if rel:sub(1, #journal_prefix) == journal_prefix then
      table.insert(journal_files, rel)
    end
  end
  table.sort(journal_files, function(a, b) return a > b end)

  local journal_lines = {}
  for i = 1, math.min(7, #journal_files) do
    local rel = journal_files[i]
    local y, mo, d = rel:match("/(%d%d%d%d)/(%d%d)/(%d%d)%.md$")
    local label = y and string.format("%s-%s-%s", y, mo, d) or vim.fn.fnamemodify(rel, ":t:r")
    table.insert(journal_lines, string.format("- [%s](%s)", label, rel))
  end

  -- ── Full tree ────────────────────────────────────────────────────────────
  local tree_lines = render_tree(build_tree(all))

  -- ── Assemble ─────────────────────────────────────────────────────────────
  local out = {
    AUTO_HEADER,
    "# Notes Index",
    "",
    string.format("_Last updated: %s_", os.date("%Y-%m-%d %H:%M")),
    "",
    "## All Notes",
    "",
  }
  for _, l in ipairs(tree_lines) do table.insert(out, l) end

  table.insert(out, "")
  table.insert(out, "## Recent Notes")
  table.insert(out, "")
  for _, l in ipairs(recent_lines) do table.insert(out, l) end

  if #journal_lines > 0 then
    table.insert(out, "")
    table.insert(out, "## Recent Journal")
    table.insert(out, "")
    for _, l in ipairs(journal_lines) do table.insert(out, l) end
  end

  table.insert(out, "")

  local index_path = vault .. "/" .. cfg.index_file
  local fh = io.open(index_path, "w")
  if fh then
    fh:write(table.concat(out, "\n"))
    fh:close()
  else
    vim.notify("notes.nvim: could not write " .. index_path, vim.log.levels.ERROR)
    return
  end

  -- If INDEX.md is open in a buffer, reload it silently
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == index_path then
      vim.api.nvim_buf_call(buf, function() vim.cmd("checktime") end)
      break
    end
  end
end

--- Set up an autocommand to regenerate the index on every vault file save.
function M.setup_autocmd()
  local cfg        = require("notes.config").get()
  local index_path = cfg.vault .. "/" .. cfg.index_file

  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern  = index_path,
    group    = vim.api.nvim_create_augroup("NotesIndexReadonly", { clear = true }),
    callback = function()
      vim.bo.modifiable = false
      vim.bo.readonly   = true
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern  = cfg.vault .. "/**/*.md",
    group    = vim.api.nvim_create_augroup("NotesAutoIndex", { clear = true }),
    callback = function(ev)
      if ev.file ~= index_path then
        vim.schedule(M.generate)
      end
    end,
  })
end

return M
