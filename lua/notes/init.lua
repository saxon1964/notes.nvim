local M = {}

-- Whether the post-vault wiring (autocmds, keymaps) has been done.
local _wired = false

--- Complete the setup that requires a known vault path.
--- Safe to call multiple times; only runs once.
local function wire()
  if _wired then return end
  _wired = true

  local config = require("notes.config")
  local cfg    = config.get()

  vim.fn.mkdir(cfg.vault .. "/" .. cfg.inbox_dir,   "p")
  vim.fn.mkdir(cfg.vault .. "/" .. cfg.journal_dir, "p")

  if cfg.auto_index then
    require("notes.index").setup_autocmd()
  end

  -- Buffer-local keymaps — only active inside vault *.md files
  local km = cfg.keymaps
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = cfg.vault .. "/**/*.md",
    group   = vim.api.nvim_create_augroup("NotesKeymaps", { clear = true }),
    callback = function(ev)
      local buf   = ev.buf
      local bopts = function(desc)
        return { buffer = buf, silent = true, desc = "Notes: " .. desc }
      end
      if km.insert_link then
        vim.keymap.set("n", km.insert_link,
          function() require("notes.links").insert_existing() end,
          bopts("insert link to existing note"))
      end
      if km.insert_new_link then
        vim.keymap.set("n", km.insert_new_link,
          function() require("notes.links").insert_new() end,
          bopts("insert link to new child note"))
      end
      if km.follow_link then
        vim.keymap.set("n", km.follow_link,
          function() require("notes.links").follow() end,
          bopts("follow link under cursor"))
      end
      if km.backlinks then
        vim.keymap.set("n", km.backlinks,
          function() require("notes.backlinks").show() end,
          bopts("show backlinks"))
      end
      if km.daily then
        vim.keymap.set("n", km.daily,
          function() require("notes.journal").open_daily() end,
          bopts("open today's daily note"))
      end
      if km.search then
        vim.keymap.set("n", km.search,
          function() require("notes.search").search() end,
          bopts("search vault"))
      end
      if km.index then
        vim.keymap.set("n", km.index,
          function()
            require("notes.index").generate()
            vim.cmd.edit(cfg.vault .. "/" .. cfg.index_file)
          end,
          bopts("open index"))
      end
    end,
  })
end

--- Ensure the vault is resolved, then call callback().
--- If the vault cannot be auto-detected, asks the user whether to initialise
--- the current working directory.
local function ensure_vault(callback)
  local config = require("notes.config")
  local files  = require("notes.files")
  local cfg    = config.get()

  -- Already known
  if cfg.vault then
    wire()
    callback()
    return
  end

  -- Try to detect from cwd upwards
  local detected = files.find_vault_root()
  if detected then
    config.set_vault(detected)
    wire()
    callback()
    return
  end

  -- Ask the user
  local cwd = vim.fn.getcwd()
  vim.ui.select({ "Yes", "No" }, {
    prompt = string.format("'%s' is not inside a notes vault. Initialize it as vault root?", cwd),
  }, function(choice)
    if choice == "Yes" then
      files.init_vault(cwd)
      config.set_vault(cwd)
      wire()
      callback()
    end
  end)
end

function M.setup(opts)
  local config = require("notes.config")
  config.setup(opts)

  -- If an explicit vault was provided, wire immediately.
  -- Otherwise wiring is deferred until ensure_vault() is first called.
  if config.get().vault then
    wire()
  end

  -- ── Commands (registered unconditionally; vault resolved on first use) ───

  vim.api.nvim_create_user_command("NotesInit", function()
    local files  = require("notes.files")
    local config2 = require("notes.config")
    local cwd    = vim.fn.getcwd()
    if vim.fn.filereadable(cwd .. "/" .. files.MARKER) == 1 then
      vim.notify("notes.nvim: '" .. cwd .. "' is already a vault root", vim.log.levels.INFO)
      return
    end
    files.init_vault(cwd)
    config2.set_vault(cwd)
    wire()
  end, { desc = "Initialize current directory as notes vault root" })

  vim.api.nvim_create_user_command("NotesDaily", function(a)
    ensure_vault(function()
      require("notes.journal").open_daily(a.args ~= "" and a.args or nil)
    end)
  end, { nargs = "?", desc = "Open daily note (optional: YYYY-MM-DD)" })

  vim.api.nvim_create_user_command("NotesNew", function(a)
    ensure_vault(function()
      local files = require("notes.files")
      local cfg   = require("notes.config").get()
      local title = a.args ~= "" and a.args or nil
      local function create(t)
        local slug = files.slugify(t)
        local rel  = cfg.inbox_dir .. "/" .. slug .. ".md"
        local abs  = files.create(rel, cfg.templates.new_note(t))
        vim.cmd.edit(abs)
      end
      if title then
        create(title)
      else
        vim.ui.input({ prompt = "Note title: " }, function(input)
          if input and input ~= "" then create(input) end
        end)
      end
    end)
  end, { nargs = "?", desc = "Create new note in inbox" })

  vim.api.nvim_create_user_command("NotesIndex", function()
    ensure_vault(function()
      local cfg = require("notes.config").get()
      require("notes.index").generate()
      vim.cmd.edit(cfg.vault .. "/" .. cfg.index_file)
    end)
  end, { desc = "Regenerate and open INDEX.md" })

  vim.api.nvim_create_user_command("NotesSearch", function(a)
    ensure_vault(function()
      require("notes.search").search(a.args ~= "" and a.args or nil)
    end)
  end, { nargs = "?", desc = "Full-text search across vault" })

  vim.api.nvim_create_user_command("NotesBacklinks", function()
    ensure_vault(function()
      require("notes.backlinks").show()
    end)
  end, { desc = "Show backlinks to current note" })

  -- ── Global keymap for NotesInit (available before any vault exists) ──────
  local km = config.get().keymaps
  if km.init then
    vim.keymap.set("n", km.init, "<cmd>NotesInit<cr>",
      { silent = true, desc = "Notes: initialize vault in cwd" })
  end
end

return M
