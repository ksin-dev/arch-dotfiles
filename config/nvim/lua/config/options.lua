-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false

-- Route yanks through the terminal's OSC 52 clipboard bridge. This works both
-- locally in Alacritty and across SSH sessions without requiring a clipboard
-- provider on the remote host.
local osc52 = require("vim.ui.clipboard.osc52")
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = osc52.copy("+"),
    ["*"] = osc52.copy("*"),
  },
  paste = {
    ["+"] = osc52.paste("+"),
    ["*"] = osc52.paste("*"),
  },
}

-- LazyVim temporarily clears this option while it starts up. Restore it after
-- that deferred setup so ordinary yanks use the OSC 52 provider as well.
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    vim.schedule(function()
      vim.opt.clipboard = "unnamedplus"
    end)
  end,
})
