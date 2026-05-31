# AGENTS.md

Guidance for agents working in this repository.

## Project Overview

This repository is a Neovim plugin that wraps
[translate-shell](https://github.com/soimort/translate-shell) and exposes a
`:Trans` command for translating text inside Neovim.

## Development Commands

Run the full test suite with:

```bash
make test
```

The tests use `plenary.nvim` and run in headless Neovim with
`tests/minimal_init.lua`.

Format Lua code with:

```bash
stylua lua
```

Check Lua formatting without modifying files with:

```bash
stylua --check lua
```

## Project Structure

- `lua/translator.lua`: main module entry point, `setup()` function, and config
  management.
- `lua/translator/module.lua`: core functionality modules.
- `plugin/translator.lua`: plugin initialization and user command creation.
- `tests/translator/translator_spec.lua`: plenary/busted test suite.
- `tests/minimal_init.lua`: minimal Neovim config used by tests.

## Configuration Pattern

Configuration defaults live in `lua/translator.lua`. Users call `setup()` with
optional overrides, and config is merged with
`vim.tbl_deep_extend("force", ...)`.

## Dependencies

- `translate-shell`: external CLI used for translation.
- `plenary.nvim`: test dependency, automatically cloned during test runs.

## CI

GitHub Actions runs formatting checks, tests across supported operating systems
and Neovim versions, documentation generation, and release automation.

## Editing Guidance

- Keep changes surgical and aligned with the existing Neovim plugin structure.
- Match the existing Lua style and run `stylua` when changing Lua files.
- Add or update focused tests for behavior changes.
- Do not introduce new dependencies or abstractions unless the change requires
  them.
