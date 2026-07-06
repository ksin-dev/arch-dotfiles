return {
  "jake-stewart/multicursor.nvim",
  branch = "1.0",
  config = function()
    local mc = require("multicursor-nvim")

    mc.setup()

    local set = vim.keymap.set

    set({ "n", "x" }, "<leader>md", function()
      mc.matchAddCursor(1)
    end, { desc = "Add Cursor to Next Match" })

    set({ "n", "x" }, "<leader>mD", function()
      mc.matchAddCursor(-1)
    end, { desc = "Add Cursor to Previous Match" })

    set({ "n", "x" }, "<leader>ms", function()
      mc.matchSkipCursor(1)
    end, { desc = "Skip Next Match" })

    set({ "n", "x" }, "<leader>mS", function()
      mc.matchSkipCursor(-1)
    end, { desc = "Skip Previous Match" })

    set({ "n", "x" }, "<C-Up>", function()
      mc.lineAddCursor(-1)
    end, { desc = "Add Cursor Above" })

    set({ "n", "x" }, "<C-Down>", function()
      mc.lineAddCursor(1)
    end, { desc = "Add Cursor Below" })

    set("n", "<leader>mc", function()
      mc.clearCursors()
    end, { desc = "Clear Multiple Cursors" })
  end,
}
