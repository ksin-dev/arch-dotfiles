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

            local ssh_connection = vim.env.SSH_CONNECTION
            if not ssh_connection or ssh_connection == "" then
              vim.fn.jobstart({ "xdg-open", path }, { detach = true })
              return
            end

            local connection = vim.split(ssh_connection, "%s+", { trimempty = true })
            local host = vim.env.NVIM_SFTP_HOST or connection[3]
            local port = vim.env.NVIM_SFTP_PORT or connection[4]
            local user = vim.env.NVIM_SFTP_USER or vim.env.USER

            if not host or not port or not user then
              vim.notify("Could not determine the current SSH connection for SFTP", vim.log.levels.ERROR)
              return
            end

            if host:find(":", 1, true) then
              host = "[" .. host .. "]"
            end

            local sftp_url = string.format(
              "sftp://%s@%s:%s%s",
              vim.uri_encode(user),
              host,
              port,
              vim.uri_encode(path)
            )

            if vim.fn.executable("kitten") == 0 then
              vim.notify("Opening remote folders requires `kitten ssh` for this SSH session", vim.log.levels.ERROR)
              return
            end

            if not vim.env.KITTY_LISTEN_ON or vim.env.KITTY_LISTEN_ON == "" then
              vim.notify("Reconnect with `kitten ssh <host>` before opening a remote folder", vim.log.levels.ERROR)
              return
            end

            vim.fn.jobstart({ "kitten", "@", "launch", "--type=background", "--no-response", "xdg-open", sftp_url }, {
              detach = true,
              on_exit = function(_, code)
                if code ~= 0 then
                  vim.schedule(function()
                    vim.notify("Kitty could not open the local SFTP folder (exit " .. code .. ")", vim.log.levels.ERROR)
                  end)
                end
              end,
            })
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
