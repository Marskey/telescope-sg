# Telescope ast-grep

Ast-grep picker for telescope.nvim

Inspired by this [PR](https://github.com/nvim-telescope/telescope.nvim/pull/2611)

![](./img/telescope-sg.png)

## Requires
  `ast-grep` to be installed ( version >= 0.10.0 )

## What it does
  ast-grep is a AST-based tool to search code by pattern code. Think it as your old-friend grep but it matches AST nodes instead of text. You can write patterns as if you are writing ordinary code. It will match all code that has the same syntactical structure. You can use $ sign + upper case letters as wildcard, e.g. $MATCH, to match any single AST node. Think it as REGEX dot ., except it is not textual.

See [ast-grep](https://ast-grep.github.io/)

## Check Health
  Make sure you call `:checkhealth telescope` after intalling to ensure everything is set up correctly.

## Configuration

```lua
require('telescope').setup {
    extensions = {
        ast_grep = {
            command = {
                "sg",
                "--json=stream",
                "-p",
            }, -- must have --json and -p
            grep_open_files = false, -- search in opened files
            lang = nil, -- string value, specify language for ast-grep `nil` for default
        }
    }
}
```

## Usage
```lua
Telescope ast_grep
```
