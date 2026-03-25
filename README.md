# notes.nvim

A simple, self-contained Neovim plugin for markdown note-taking.

No mandatory external dependencies. Works out of the box with `vim.ui.select`; integrates
with **telescope**, **fzf-lua**, and **snacks.nvim** when available.

---

## Installation

### lazy.nvim

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

---

## Quick-start configuration

```lua
require("notes").setup({
  -- Root directory of your notes vault (required)
  vault = vim.fn.expand("~/notes"),

  -- Picker: "auto" | "telescope" | "fzf" | "snacks" | "native"
  picker = "auto",

  -- Override any keymap by setting its value, or disable it with false
  keymaps = {
    insert_link     = "<leader>nl",   -- link to existing note
    insert_new_link = "<leader>nn",   -- create child note + insert link
    follow_link     = "<leader>nf",   -- open note under cursor
    backlinks       = "<leader>nb",   -- backlinks → quickfix
    daily           = "<leader>nd",   -- today's daily note
    search          = "<leader>ns",   -- full-text search → quickfix
    index           = "<leader>ni",   -- regenerate INDEX.md
  },
})
```

---

## Vault layout

```
~/notes/
├── INDEX.md                ← auto-maintained; never edit manually
├── inbox/                  ← new notes without an explicit parent
├── journal/
│   └── 2026/
│       └── 03/
│           └── 25.md       ← daily note
└── topics/
    ├── neovim.md
    └── neovim/             ← children of neovim.md
        ├── plugins.md
        └── plugins/
            └── telescope.md
```

When you create a child note from `parent.md` the file is placed in a folder that
shares the parent's name: `parent/<child-slug>.md`. Notes without a parent go to `inbox/`.

---

## Commands

| Command | Description |
|---|---|
| `:NotesDaily [YYYY-MM-DD]` | Open today's (or a specific) daily note |
| `:NotesNew [title]` | Create a new note in `inbox/` |
| `:NotesIndex` | Regenerate and open `INDEX.md` |
| `:NotesSearch [query]` | Full-text search → quickfix |
| `:NotesBacklinks` | Notes linking to the current file → quickfix |

---

## Link formats

Both are supported when **following** links. Only the markdown format is **inserted** by
the plugin (portable across renderers).

```
[display text](relative/path.md)   ← inserted by plugin
[[wikilink]]                       ← wiki-style, resolved from vault root
[[wikilink|display text]]          ← wiki-style with alias
```

---

## Dependencies

| | Required | Notes |
|---|---|---|
| Neovim ≥ 0.9 | ✓ | |
| `rg` (ripgrep) | | Faster search; falls back to `grep` |
| telescope.nvim | | Rich picker |
| fzf-lua | | Rich picker |
| snacks.nvim | | Enhances `vim.ui.select` automatically |

---

See [SPEC.md](SPEC.md) for the full specification.
