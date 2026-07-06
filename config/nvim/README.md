# Neovim

LazyVim-based Neovim configuration.

## Files

- `init.lua`: entry point
- `lua/config/`: local options, keymaps, autocommands, and Lazy setup
- `lua/plugins/`: plugin overrides and custom plugins
- `lazy-lock.json`: pinned plugin revisions
- `stylua.toml`: Lua formatter settings

## Required

- `neovim`
- `git`: required by `lazy.nvim`
- `curl` or a working TLS stack for plugin downloads

## Strongly Recommended

- `ripgrep`: Telescope and search
- `fd`: file finding
- `unzip`: Mason package extraction
- `gcc` or `clang`: Treesitter parser builds
- A Nerd Font: icons in LazyVim UI

## Configured Features

- LazyVim base distribution
- Mason-managed debug adapters:
  - `codelldb`
  - `delve`
  - `python`
  - `elixir-ls-debugger`
- Elixir support:
  - `elixir-ls`
  - DAP launch configs for `mix test`, current-file tests, and `mix phx.server`
  - Treesitter parsers for `elixir`, `heex`, `eex`
  - `elixir-extras.nvim`
- Claude Code integration through `coder/claudecode.nvim`

## Language-Specific Dependencies

Install only what you use:

- Elixir: `elixir`, `erlang`, `mix`, and Mason's `elixir-ls` package
- Go debugging: `go`
- Rust/C/C++ debugging: `lldb`
- Python debugging: `python`
- Claude Code plugin: `claude` CLI available in `PATH`

## Install

From the repository root:

```sh
./install.sh nvim
```

Open Neovim and let Lazy/Mason install plugins:

```sh
nvim
```
