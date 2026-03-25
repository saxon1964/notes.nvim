# notes.nvim — Specification

## Overview

A simple, self-contained Neovim plugin for markdown-based note-taking. No mandatory
external dependencies. Integrates with popular pickers (telescope, fzf-lua) when available.

---

## Vault Structure

```
vault/
├── INDEX.md                    ← auto-maintained, never edit manually
├── inbox/                      ← new notes without an explicit parent
│   └── random-thought.md
├── journal/
│   └── YYYY/
│       └── MM/
│           └── DD.md
└── topics/
    ├── neovim.md               ← a note
    └── neovim/                 ← children of neovim.md live here
        ├── plugins.md
        └── plugins/            ← children of plugins.md
            └── telescope.md
```

**Rule:** when a child note is created from `parent.md`, it is placed at
`parent/<child-slug>.md` — the "children folder" shares its name with the parent file
(without extension).

---

## Configuration

```lua
require("notes").setup({
  -- Required: root directory of the vault
  vault = vim.fn.expand("~/notes"),

  -- Picker backend: "auto" | "telescope" | "fzf" | "snacks" | "native"
  -- "auto" tries telescope → fzf-lua → vim.ui.select
  -- snacks.nvim automatically upgrades vim.ui.select when installed
  picker = "auto",

  -- Subdirectories (relative to vault)
  inbox_dir   = "inbox",
  journal_dir = "journal",
  index_file  = "INDEX.md",

  -- Regenerate INDEX.md on every markdown file save inside vault
  auto_index = true,

  -- Key mappings (set any to false to disable)
  keymaps = {
    insert_link     = "<leader>nl",   -- insert link to existing note
    insert_new_link = "<leader>nn",   -- insert link + create child note
    follow_link     = "<leader>nf",   -- open note under cursor
    backlinks       = "<leader>nb",   -- show backlinks in quickfix
    daily           = "<leader>nd",   -- open today's daily note
    search          = "<leader>ns",   -- full-text search
    index           = "<leader>ni",   -- force-regenerate INDEX.md
  },

  -- Content templates (override to customise)
  templates = {
    daily    = function(date)  return ("# %s\n\n## Notes\n\n## Tasks\n\n"):format(date) end,
    new_note = function(title) return ("# %s\n\n"):format(title) end,
  },
})
```

---

## Commands

| Command | Description |
|---|---|
| `:NotesDaily [YYYY-MM-DD]` | Open today's (or given date's) daily note |
| `:NotesNew [title]` | Create new note in `inbox/` |
| `:NotesIndex` | Force-regenerate `INDEX.md` |
| `:NotesSearch [query]` | Full-text grep across vault → quickfix |
| `:NotesBacklinks` | Show all notes linking to the current file → quickfix |

---

## Keymaps

All keymaps are buffer-local and only active inside vault `*.md` files.

| Default | Action |
|---|---|
| `<leader>nl` | Picker: choose existing note → insert `[stem](rel-path)` at cursor |
| `<leader>nn` | Prompt for title → create child note → insert link at cursor |
| `<leader>nf` | Follow link under cursor (creates file if missing) |
| `<leader>nb` | Backlinks → quickfix |
| `<leader>nd` | Open today's daily note |
| `<leader>ns` | Search prompt → quickfix |
| `<leader>ni` | Regenerate INDEX.md |

---

## Link Formats

Both formats are supported for **following** links. Only markdown format is **inserted**
by the plugin (more portable, works in any markdown renderer).

```
[display text](relative/path.md)     ← standard markdown, inserted by plugin
[[wikilink]]                         ← wiki-style, resolved from vault root
[[wikilink|display text]]            ← wiki-style with alias
```

All inserted links use **relative paths** from the current file.

---

## INDEX.md

Auto-generated file. Structure:

```markdown
<!-- AUTO-GENERATED: do not edit manually -->
# Notes Index

_Last updated: 2026-03-25 14:30_

## Recent Notes
- [25](journal/2026/03/25.md) — 2026-03-25 14:30
...

## Recent Journal
- [2026-03-25](journal/2026/03/25.md)
...

## All Notes
- **inbox/**
  - [random-thought](inbox/random-thought.md)
- **topics/**
  - [neovim](topics/neovim.md)
  - **neovim/**
    - [plugins](topics/neovim/plugins.md)
```

Triggered automatically on `BufWritePost` for any vault `*.md` file (excluding INDEX.md
itself). Can be suppressed with `auto_index = false`.

---

## Dependencies

| Dependency | Required | Purpose |
|---|---|---|
| Neovim ≥ 0.9 | Yes | Lua API used throughout |
| `rg` (ripgrep) | No | Faster search / backlinks; falls back to `grep` |
| telescope.nvim | No | Rich picker UI |
| fzf-lua | No | Rich picker UI |
| snacks.nvim | No | Enhances `vim.ui.select` automatically |

---

## Installation (lazy.nvim)

```lua
{
  "saxon1964/notes.nvim",
  config = function()
    require("notes").setup({
      vault = vim.fn.expand("~/notes"),
    })
  end,
}
```
