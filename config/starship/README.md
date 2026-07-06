# Starship

Prompt configuration for Starship.

## Files

- `starship.toml`: prompt layout, symbols, and module formats

## Required

- `starship`
- A Nerd Font: the prompt uses icon glyphs

## Optional Module Tools

Starship shows modules only when matching tools/projects are detected. Useful
tools include:

- `git`
- `node`, `deno`
- `python`
- `ruby`
- `rust`
- `go`
- `java`
- `docker` or Kubernetes tooling if those modules are enabled later

## Shell Setup

This config file alone does not enable Starship. The shell must initialize it:

```sh
eval "$(starship init zsh)"
```

The current zsh config in this repo uses Powerlevel10k instead of Starship, so
this Starship config is available but not the active prompt unless zsh is
changed to initialize it.

## Install

From the repository root:

```sh
./install.sh starship
```

