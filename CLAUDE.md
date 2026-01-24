# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin that wraps [translate-shell](https://github.com/soimort/translate-shell) to enable text translation directly from Neovim. The plugin provides a `:Trans` command for translating text.

## Development Commands

### Testing
```bash
# Run all tests
make test

# The test suite uses plenary.nvim for testing
# Tests run in headless Neovim with minimal_init.lua
```

### Linting
```bash
# Format Lua code with stylua
stylua lua

# Check formatting without modifying files
stylua --check lua
```

## Architecture

### Plugin Structure

The plugin follows the standard Neovim plugin structure:

- **`lua/translator.lua`**: Main module entry point with `setup()` function and config management
- **`lua/translator/module.lua`**: Core functionality modules
- **`plugin/translator.lua`**: Plugin initialization, creates user commands (`:Trans`)
- **`tests/translator/translator_spec.lua`**: Test suite using plenary.nvim's busted framework
- **`tests/minimal_init.lua`**: Minimal Neovim config for running tests

### Configuration Pattern

The plugin uses a standard Neovim plugin configuration pattern:
- Config defaults are defined in `lua/translator.lua`
- Users call `setup()` with optional overrides
- Config is merged using `vim.tbl_deep_extend("force", ...)`

### Testing Setup

Tests use plenary.nvim's busted framework:
- `minimal_init.lua` clones plenary.nvim if not present
- Tests are run in headless Neovim
- Test files follow the `*_spec.lua` naming convention

## External Dependencies

- **translate-shell**: The plugin wraps this external CLI tool for translation functionality
- **plenary.nvim**: Required for running tests (automatically cloned during test runs)

## CI/CD

The project uses GitHub Actions for:
- **lint-test.yml**: Runs stylua formatting checks and tests on multiple OS (Ubuntu, macOS, Windows) and Neovim versions (stable, nightly)
- **docs.yml**: Documentation generation
- **release.yml**: Release automation
