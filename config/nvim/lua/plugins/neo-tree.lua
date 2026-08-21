return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        commands = {
          open_in_file_manager = function(state)
            local node = state.tree:get_node()
            local path = node:get_id()

            if node.type ~= "directory" then
              path = vim.fn.fnamemodify(path, ":h")
            end

            vim.fn.jobstart({ "xdg-open", path }, { detach = true })
          end,
        },
        window = {
          mappings = {
            ["O"] = "open_in_file_manager",
          },
        },
      },
    },
  },
}
