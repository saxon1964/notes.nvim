local M = {}

local function notify(msg, level)
  vim.notify(msg, level, { title = "notes.nvim" })
end

local IMAGE_EXTS = {
  png=true, jpg=true, jpeg=true,
  gif=true, webp=true, bmp=true,
  svg=true, tiff=true, tif=true,
}

--- Return true if path points to an image file.
function M.is_image(path)
  local ext = path:match("%.(%w+)$")
  return ext and IMAGE_EXTS[ext:lower()] == true
end

--- Clear all images rendered by image.nvim (to avoid z-layer bleed through pickers/floats).
function M.clear_all()
  local ok, image_api = pcall(require, "image")
  if not ok then return end
  for _, img in pairs(image_api.get_images()) do
    img:clear()
  end
end

--- Open an image in the system viewer (macOS Preview / xdg-open).
function M.open(abs_path)
  local cmd = vim.fn.has("mac") == 1 and "open" or "xdg-open"
  vim.fn.jobstart({ cmd, abs_path }, { detach = true })
end

--- List image files in the vault's images directory, relative to vault root.
function M.list()
  local cfg   = require("notes.config").get()
  local dir   = cfg.vault .. "/" .. cfg.images_dir
  local exts  = {}
  for e in pairs(IMAGE_EXTS) do
    table.insert(exts, "*." .. e)
  end

  local result = {}
  for _, ext in ipairs(exts) do
    local matches = vim.fn.glob(dir .. "/**/" .. ext, false, true)
    for _, abs in ipairs(matches) do
      local rel = abs:sub(#cfg.vault + 2)
      if not rel:match("^%.") and not rel:match("/%.") then
        table.insert(result, rel)
      end
    end
  end
  table.sort(result)
  return result
end

--- List ALL files in the vault's images directory, relative to vault root.
function M.list_all()
  local cfg = require("notes.config").get()
  local dir = cfg.vault .. "/" .. cfg.images_dir
  local matches = vim.fn.glob(dir .. "/**/*", false, true)
  local result = {}
  for _, abs in ipairs(matches) do
    if vim.fn.isdirectory(abs) == 0 then
      local rel = abs:sub(#cfg.vault + 2)
      if not rel:match("^%.") and not rel:match("/%.") then
        table.insert(result, rel)
      end
    end
  end
  table.sort(result)
  return result
end

return M
