local M = {}

local function notify(msg, level)
  vim.notify(msg, level, { title = "notes.nvim" })
end

local function url_decode(s)
  return s:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

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

--- Find the first link on the line that contains or starts at/right of col.
--- Returns (path_string, kind) or (nil, nil).
local function find_link_from_col(line, col)
  local best_s, best_path, best_kind = math.huge, nil, nil

  local pos = 1
  while true do
    local s, e, path = line:find("%[.-%]%((.-)%)", pos)
    if not s then break end
    if col <= e and s < best_s then
      best_s, best_path, best_kind = s, path, "markdown"
    end
    pos = e + 1
  end

  pos = 1
  while true do
    local s, e, inner = line:find("%[%[(.-)%]%]", pos)
    if not s then break end
    if col <= e and s < best_s then
      local path = inner:match("^(.-)%|") or inner
      if not path:match("%.%w+$") then path = path .. ".md" end
      best_s, best_path, best_kind = s, path, "wiki"
    end
    pos = e + 1
  end

  return best_path, best_kind
end

--- Resolve a (possibly relative) link path to an absolute filesystem path.
--- Uses the current buffer's directory as the base.
local function resolve_abs(link_path, kind)
  local decoded = url_decode(link_path)
  local vault = cfg().vault
  if kind == "wiki" then
    -- Wiki links are always relative to vault root
    return vim.fn.simplify(vault .. "/" .. decoded)
  end
  if decoded:sub(1, 1) == "/" then
    return vault .. decoded
  end
  local from_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
  return vim.fn.simplify(from_dir .. "/" .. decoded)
end

--- Follow the first link at or to the right of the cursor on the current line.
--- If the target does not exist it is created with the default template.
function M.follow()
  local line = vim.api.nvim_get_current_line()
  local col  = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-indexed
  local link_path, kind = find_link_from_col(line, col)
  if not link_path then
    notify("No link on this line at or right of cursor", vim.log.levels.WARN)
    return
  end

  local abs = resolve_abs(link_path, kind)

  -- Image files: open with image.nvim if available, else system viewer
  local images = require("notes.images")
  if images.is_image(abs) then
    images.open(abs)
    return
  end

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
  if M.parse_under_cursor() then
    notify("Cursor is already inside a link", vim.log.levels.WARN)
    return
  end
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
    -- leave cursor at start of link so <leader>no can follow it immediately
  end)
end

--- Prompt for a title, create a child note, and insert a link at cursor.
function M.insert_new()
  if M.parse_under_cursor() then
    notify("Cursor is already inside a link", vim.log.levels.WARN)
    return
  end
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
    -- leave cursor at start of link so <leader>no can follow it immediately

    notify("Created: " .. rel_path, vim.log.levels.INFO)
  end)
end

--- In source_file, replace every link that resolves to target_abs with
--- italic display text + the configured dangling link marker.
local function fix_dangling_links(source_file, target_abs, marker)
  local lines = vim.fn.readfile(source_file)
  if not lines then return end
  local vault      = cfg().vault
  local source_dir = vim.fn.fnamemodify(source_file, ":h")
  local changed    = false

  local function resolved(path)
    local decoded = url_decode(path)
    if decoded:sub(1, 1) == "/" then
      return vim.fn.simplify(vault .. decoded)
    end
    return vim.fn.simplify(source_dir .. "/" .. decoded)
  end

  local new_lines = {}
  for _, line in ipairs(lines) do
    -- markdown links: [text](path)
    local new_line = line:gsub("%[(.-)%]%((.-)%)", function(text, path)
      if resolved(path) == target_abs then
        changed = true
        return "*" .. text .. "* " .. marker
      end
      return "[" .. text .. "](" .. path .. ")"
    end)
    -- wiki links: [[path]] or [[path|alias]]
    new_line = new_line:gsub("%[%[(.-)%]%]", function(inner)
      local wpath, alias = inner:match("^(.-)%|(.+)$")
      local display
      if wpath then display = alias else wpath, display = inner, vim.fn.fnamemodify(inner, ":t:r") end
      if not wpath:match("%.%w+$") then wpath = wpath .. ".md" end
      if vim.fn.simplify(vault .. "/" .. wpath) == target_abs then
        changed = true
        return "*" .. display .. "* " .. marker
      end
      return "[[" .. inner .. "]]"
    end)
    table.insert(new_lines, new_line)
  end

  if changed then
    vim.fn.writefile(new_lines, source_file)
    -- Reload buffer if it is open
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buf) == source_file then
        vim.api.nvim_buf_call(buf, function() vim.cmd("silent! edit") end)
        break
      end
    end
  end
end

--- Scan all vault markdown files for broken links and populate the quickfix list.
function M.check_integrity()
  local vault = cfg().vault
  if not vault then
    notify("Vault not set", vim.log.levels.WARN)
    return
  end

  local all_files = vim.fn.glob(vault .. "/**/*.md", false, true)
  local broken    = {}

  for _, filepath in ipairs(all_files) do
    local lines   = vim.fn.readfile(filepath)
    if not lines then goto continue end
    local file_dir = vim.fn.fnamemodify(filepath, ":h")

    local function resolve_from_file(path, kind)
      local decoded = url_decode(path)
      if kind == "wiki" then
        return vim.fn.simplify(vault .. "/" .. decoded)
      end
      if decoded:sub(1, 1) == "/" then
        return vim.fn.simplify(vault .. decoded)
      end
      return vim.fn.simplify(file_dir .. "/" .. decoded)
    end

    for lnum, line in ipairs(lines) do
      -- markdown links: [text](path)
      local pos = 1
      while true do
        local s, _, text, path = line:find("%[(.-)%]%((.-)%)", pos)
        if not s then break end
        -- skip external URLs, anchors, and empty paths
        if path ~= ""
          and not path:match("^https?://")
          and not path:match("^ftps?://")
          and not path:match("^mailto:")
          and not path:match("^#")
        then
          local abs = resolve_from_file(path, "markdown")
          if vim.fn.filereadable(abs) == 0 then
            table.insert(broken, {
              filename = filepath,
              lnum     = lnum,
              col      = s - 1,
              text     = string.format("[%s](%s)", text, path),
            })
          end
        end
        pos = s + 1
      end

      -- wikilinks: [[path]] or [[path|alias]]
      pos = 1
      while true do
        local s, _, inner = line:find("%[%[(.-)%]%]", pos)
        if not s then break end
        local wpath = inner:match("^(.-)%|") or inner
        if not wpath:match("%.%w+$") then wpath = wpath .. ".md" end
        local abs = resolve_from_file(wpath, "wiki")
        if vim.fn.filereadable(abs) == 0 then
          table.insert(broken, {
            filename = filepath,
            lnum     = lnum,
            col      = s - 1,
            text     = string.format("[[%s]]", inner),
          })
        end
        pos = s + 1
      end
    end

    ::continue::
  end

  if #broken == 0 then
    notify("All links are valid", vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist(broken, "r")
  vim.cmd("copen")
  notify(string.format("%d broken link(s) found — see quickfix list", #broken), vim.log.levels.WARN)
end

--- Delete the file under the cursor link, or the current file if no link.
--- Finds all backlinks first; on confirmation deletes the file and replaces
--- dangling links in every affected note with italic text + marker.
function M.delete()
  local link_path, kind = M.parse_under_cursor()
  local target_abs

  if link_path then
    target_abs = resolve_abs(link_path, kind)
  else
    target_abs = vim.api.nvim_buf_get_name(0)
  end

  if not target_abs or target_abs == "" or vim.fn.filereadable(target_abs) == 0 then
    notify("No file to delete", vim.log.levels.WARN)
    return
  end

  local display   = vim.fn.fnamemodify(target_abs, ":~")
  local backlinked = require("notes.backlinks").find(target_abs)
  local marker    = cfg().dangling_link_marker

  local prompt
  if #backlinked == 0 then
    prompt = "Delete " .. display .. "?"
  else
    local names = {}
    for _, f in ipairs(backlinked) do
      table.insert(names, vim.fn.fnamemodify(f, ":~:."))
    end
    prompt = string.format(
      "Delete %s? Linked from %d file(s): %s — links will become *text* %s",
      display, #backlinked, table.concat(names, ", "), marker
    )
  end

  vim.ui.select({ "Yes", "No" }, { prompt = prompt }, function(choice)
    if choice ~= "Yes" then return end

    -- Close any buffer showing this file before removing it
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buf) == target_abs then
        vim.api.nvim_buf_delete(buf, { force = true })
        break
      end
    end

    local ok, err = os.remove(target_abs)
    if not ok then
      notify("Could not delete: " .. (err or target_abs), vim.log.levels.ERROR)
      return
    end

    notify("Deleted: " .. display, vim.log.levels.INFO)

    for _, f in ipairs(backlinked) do
      fix_dangling_links(f, target_abs, marker)
    end
    if #backlinked > 0 then
      notify(string.format("Fixed dangling links in %d file(s)", #backlinked), vim.log.levels.INFO)
    end
  end)
end

return M
