local M = {}

local function cfg()    return require("notes.config").get() end
local function files()  return require("notes.files") end
local function picker() return require("notes.pickers") end

--- Parse the link under the cursor.
--- Returns (path_string, kind) where kind = "markdown" | "wiki", or (nil, nil).
function M.parse_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col  = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-indexed

  -- Standard markdown link:  [text](path)
  local pos = 1
  while true do
    local s, e, path = line:find("%[.-%]%((.-)%)", pos)
    if not s then break end
    if col >= s and col <= e then
      return path, "markdown"
    end
    pos = e + 1
  end

  -- Wikilink:  [[path]]  or  [[path|alias]]
  pos = 1
  while true do
    local s, e, inner = line:find("%[%[(.-)%]%]", pos)
    if not s then break end
    if col >= s and col <= e then
      local path = inner:match("^(.-)%|") or inner
      -- Wiki links have no extension in practice; normalise to .md
      if not path:match("%.%w+$") then
        path = path .. ".md"
      end
      return path, "wiki"
    end
    pos = e + 1
  end

  return nil, nil
end

--- Resolve a (possibly relative) link path to an absolute filesystem path.
--- Uses the current buffer's directory as the base.
local function resolve_abs(link_path, kind)
  local vault = cfg().vault
  if kind == "wiki" then
    -- Wiki links are always relative to vault root
    return vim.fn.simplify(vault .. "/" .. link_path)
  end
  if link_path:sub(1, 1) == "/" then
    return vault .. link_path
  end
  local from_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
  return vim.fn.simplify(from_dir .. "/" .. link_path)
end

--- Follow the link under the cursor.
--- If the target does not exist it is created with the default template.
function M.follow()
  local link_path, kind = M.parse_under_cursor()
  if not link_path then
    vim.notify("No link under cursor", vim.log.levels.WARN)
    return
  end

  local abs = resolve_abs(link_path, kind)

  if vim.fn.filereadable(abs) == 0 then
    local vault = cfg().vault
    local rel   = abs:sub(#vault + 2)
    local title = vim.fn.fnamemodify(rel, ":t:r")
    files().create(rel, cfg().templates.new_note(title))
  end

  vim.cmd.edit(abs)
end

--- Insert a link to an existing note at the current cursor position.
function M.insert_existing()
  local f = files()
  local all     = f.list()
  local current = f.current_rel()

  picker().pick(all, { prompt = "Link to note" }, function(choice)
    local rel_link = f.relative(current, choice)
    local stem     = vim.fn.fnamemodify(choice, ":t:r")
    local link     = string.format("[%s](%s)", stem, rel_link)

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line     = vim.api.nvim_get_current_line()
    vim.api.nvim_set_current_line(line:sub(1, col) .. link .. line:sub(col + 1))
    vim.api.nvim_win_set_cursor(0, { row, col + #link })
  end)
end

--- Prompt for a title, create a child note, and insert a link at cursor.
function M.insert_new()
  local f       = files()
  local current = f.current_rel()
  local cdir    = f.child_dir(current)

  vim.ui.input({ prompt = "New note title: " }, function(title)
    if not title or title == "" then return end

    local slug     = f.slugify(title)
    local rel_path = cdir .. "/" .. slug .. ".md"
    f.create(rel_path, cfg().templates.new_note(title))

    local rel_link = f.relative(current, rel_path)
    local link     = string.format("[%s](%s)", title, rel_link)

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line     = vim.api.nvim_get_current_line()
    vim.api.nvim_set_current_line(line:sub(1, col) .. link .. line:sub(col + 1))
    vim.api.nvim_win_set_cursor(0, { row, col + #link })

    vim.notify("Created: " .. rel_path, vim.log.levels.INFO)
  end)
end

return M
