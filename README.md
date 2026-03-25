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
    require("notes").setup({})
  end,
}
```

---

## Quick-start configuration

```lua
require("notes").setup({
  -- No vault needed — auto-detected via .notesroot marker.
  -- Override only if you want to force a specific path:
  -- vault = vim.fn.expand("~/notes"),

  -- Picker: "auto" | "telescope" | "fzf" | "snacks" | "native"
  picker = "auto",

  -- Override any keymap or disable it with false
  keymaps = {
    init            = "<leader>nI",   -- initialize vault in cwd
    new_note        = "<leader>nc",   -- create note in inbox
    delete_note     = "<leader>nD",   -- delete note under link or current file
    insert_link     = "<leader>nl",   -- insert link to existing note
    insert_new_link = "<leader>nn",   -- create child note + insert link
    follow_link     = "<leader>no",   -- follow link at or right of cursor
    backlinks       = "<leader>nb",   -- show backlinks
    daily           = "<leader>nd",   -- today's daily note
    search          = "<leader>ns",   -- live full-text search
    index           = "<leader>ni",   -- regenerate INDEX.md
  },
})
```

---

## Vault auto-detection

On startup the plugin walks upward from your working directory looking for a `.notesroot`
marker file. When found, that directory becomes the vault root and all keymaps activate.
If you open a file directly (e.g. `nvim ~/notes/foo.md` from `~`), detection runs from
the file's own directory instead.

If no marker is found anywhere you are asked whether to initialise the current directory.
Run `:NotesInit` (or `<leader>nI`) at any time to do it explicitly.

Commit `.notesroot` to git alongside your notes.

---

## Vault layout

```
~/notes/
├── .notesroot              ← vault marker; commit this to git
├── INDEX.md                ← auto-maintained; do not edit manually
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

When you create a child note from `parent.md` it is placed in `parent/<child-slug>.md`.
Notes without a parent go to `inbox/`.

---

## Keymaps

All keymaps are global once the vault is detected. `<leader>nI` is always available.

| Keymap | Action |
|---|---|
| `<leader>nI` | Initialize vault in cwd |
| `<leader>nc` | Prompt for title → create note in `inbox/` |
| `<leader>nD` | Delete file under cursor link, or current file (with confirmation) |
| `<leader>nl` | Picker: choose existing note → insert `[stem](rel-path)` at cursor |
| `<leader>nn` | Prompt for title → create child note → insert link at cursor |
| `<leader>no` | Follow first link at or right of cursor (creates file if missing) |
| `<leader>nb` | Show backlinks to current file |
| `<leader>nd` | Open today's daily note |
| `<leader>ns` | Live full-text search across vault |
| `<leader>ni` | Regenerate and open `INDEX.md` |

`<leader>nl`, `<leader>nn`, `<leader>no`, `<leader>nb`, and `<leader>nD` warn if the
current buffer is not a vault `*.md` file.

---

## Commands

| Command | Description |
|---|---|
| `:NotesInit` | Initialize current directory as vault root |
| `:NotesDaily [YYYY-MM-DD]` | Open today's (or a specific) daily note |
| `:NotesNew [title]` | Create a new note in `inbox/` |
| `:NotesIndex` | Regenerate and open `INDEX.md` |
| `:NotesSearch [query]` | Full-text search across vault |
| `:NotesBacklinks` | Notes linking to the current file |

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
| `rg` (ripgrep) | | Faster search and backlinks; falls back to `grep` |
| telescope.nvim | | Live grep + rich picker |
| fzf-lua | | Live grep + rich picker |
| snacks.nvim | | Live grep + enhances `vim.ui.select` |

---

See [SPEC.md](SPEC.md) for the full specification.
