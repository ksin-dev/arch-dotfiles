return {
  "akinsho/git-conflict.nvim",
  version = "*",
  config = function()
    require("git-conflict").setup({
      default_mappings = false, -- disable buffer local mapping created by this plugin
    })
    vim.keymap.set("n", "<leader>gco", "<Plug>(git-conflict-ours)", { desc = "Choose Ours" })
    vim.keymap.set("n", "<leader>gct", "<Plug>(git-conflict-theirs)", { desc = "Choose Theirs" })
    vim.keymap.set("n", "<leader>gcb", "<Plug>(git-conflict-both)", { desc = "Choose Both" })
    vim.keymap.set("n", "<leader>gc0", "<Plug>(git-conflict-none)", { desc = "Choose None" })
    vim.keymap.set("n", "<leader>g[x", "<Plug>(git-conflict-prev-conflict)", { desc = "Previous Conflict" })
    vim.keymap.set("n", "<leader>g]x", "<Plug>(git-conflict-next-conflict)", { desc = "Next Conflict" })
  end,
}
