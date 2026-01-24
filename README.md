# A Neovim Translator Plugin

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/ellisonleao/nvim-plugin-template/lint-test.yml?branch=main&style=for-the-badge)
![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

A neovim plugin that wrapped the [translate-shell](https://github.com/soimort/translate-shell), so we can translate text directly from neovim.

## Prerequisites

Make sure you have [translate-shell](https://github.com/soimort/translate-shell) installed:

```bash
# macOS
brew install translate-shell

# Linux (Debian/Ubuntu)
sudo apt-get install translate-shell

# Or install via wget
wget git.io/trans
chmod +x ./trans
```

## Install

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "nicholasxjy/translator.nvim",
    event = "VeryLazy",
    opts = {
        default_target_lang = "zh",  -- Default target language
        default_source_lang = nil,   -- Default source language (nil = auto-detect)
        popup_width = 80,            -- Popup window width
        popup_height = 20,           -- Popup window max height
    },
}
```

## How to use

### Basic Commands

```vim
" Translate specific text to Chinese
:Trans text=hello to=zh

" Translate visual selection to Chinese (select text first, then run command)
:'<,'>Trans to=zh

" Translate word under cursor to Chinese
:TransWord to=zh

" Translate word under cursor with source and target language
:TransWord from=en to=zh

" Translate word under cursor using default target language
:TransWord

" Translate with source and target language
:Trans text=你好 from=zh to=en
```

### Configuration with Keybindings

```lua
{
    "nicholasxjy/translator.nvim",
    event = "VeryLazy",
    opts = {
        default_target_lang = "zh",
        popup_width = 80,
        popup_height = 20,
    },
    keys = {
        -- Translate visual selection to Chinese
        { "<leader>tc", ":'<,'>Trans to=zh<cr>", mode = "v", desc = "Translate to Chinese" },
        -- Translate visual selection to English
        { "<leader>te", ":'<,'>Trans to=en<cr>", mode = "v", desc = "Translate to English" },
        -- Translate visual selection to Japanese
        { "<leader>tj", ":'<,'>Trans to=ja<cr>", mode = "v", desc = "Translate to Japanese" },
        -- Translate word under cursor to Chinese
        { "<leader>tw", "<cmd>TransWord to=zh<cr>", mode = "n", desc = "Translate word to Chinese" },
        -- Translate word under cursor using default language
        { "<leader>tt", "<cmd>TransWord<cr>", mode = "n", desc = "Translate word" },
    }
}
```

### Features

- **Popup Window**: Translation results are displayed in a centered popup window with rounded borders
- **Visual Selection**: Select text and translate it directly
- **Word Translation**: Translate the word under cursor with `:TransWord` command
- **Full Translation Results**: Display complete translation information including pronunciation, definitions, and examples
- **Markdown Formatting**: Translation results are displayed with markdown syntax highlighting
- **Flexible Parameters**: Support for `text=`, `to=`, and `from=` parameters
- **Error Handling**: Shows notifications when translation fails
- **Easy Close**: Press `q` or `<Esc>` to close the popup window

