local M = {}

function M.setup(opts)
  local config = require("notes.config")
  config.setup(opts)

  local cfg = config.get()
  local vault = cfg.vault

  -- Ensure core directories exist
  for _, dir in ipairs({ vault, vault .. "/" .. cfg.inbox_dir, vault .. "/" .. cfg.journal_dir }) do
    vim.fn.mkdir(dir, "p")
  end

  -- Auto-index
  if cfg.auto_index then
    require("notes.index").setup_autocmd()
  end

  -- ── Commands ──────────────────────────────────────────────────────────────

  vim.api.nvim_create_user_command("NotesDaily", function(a)
    require("notes.journal").open_daily(a.args ~= "" and a.args or nil)
  end, { nargs = "?", desc = "Open daily note (optional: YYYY-MM-DD)" })

  vim.api.nvim_create_user_command("NotesNew", function(a)
    local files = require("notes.files")
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
  end, { nargs = "?", desc = "Create new note in inbox" })

  vim.api.nvim_create_user_command("NotesIndex", function()
    require("notes.index").generate()
    vim.notify("notes.nvim: index regenerated", vim.log.levels.INFO)
  end, { desc = "Regenerate INDEX.md" })

  vim.api.nvim_create_user_command("NotesSearch", function(a)
    require("notes.search").search(a.args ~= "" and a.args or nil)
  end, { nargs = "?", desc = "Full-text search across vault" })

  vim.api.nvim_create_user_command("NotesBacklinks", function()
    require("notes.backlinks").show()
  end, { desc = "Show backlinks to current note" })

  -- ── Buffer-local keymaps (only inside vault *.md files) ──────────────────

  local km = cfg.keymaps

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = vault .. "/**/*.md",
    group   = vim.api.nvim_create_augroup("NotesKeymaps", { clear = true }),
    callback = function(ev)
      local buf  = ev.buf
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
            vim.notify("notes.nvim: index regenerated", vim.log.levels.INFO)
          end,
          bopts("regenerate index"))
      end
    end,
  })
end

return M
