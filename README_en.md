[中文](./README.md)

# Spring Boot Nvim

Adapted from [VSCode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) extension, integrating some of its features into `Neovim`.

- [x] Find Beans using Spring annotations
- [x] Discover Web Endpoints
- [x] Code completion hints and navigation for `application.properties`/`application.yml`
- [x] Dependency hints/completion for Spring annotations
- [x] Code Actions

## Installation

- `lazy.nvim`
  ```lua
  -- Using autocmd launch (default)
  -- Default uses jars from mason or ~/.vscode/extensions/vmware.vscode-spring-boot-x.x.x
  {
    "JavaHello/spring-boot.nvim",
    ft = {"java", "yaml", "jproperties"},
    dependencies = {
      "mfussenegger/nvim-jdtls", -- or nvim-java, nvim-lspconfig
      "ibhagwan/fzf-lua", -- optional
    },
    ---@type bootls.Config
    opts = {}
  },

  -- Using ftplugin or custom launch
  -- Recommended if using nvim-jdtls with ftplugin/java.lua setup
  {
    "JavaHello/spring-boot.nvim",
    lazy = true,
    dependencies = {
      "mfussenegger/nvim-jdtls", -- or nvim-java, nvim-lspconfig
    },
    config = false
  }
  ```
- Install [VSCode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) in [Visual Studio Code](https://code.visualstudio.com/) (optional)

## `jdtls` Configuration

### Option 1: Using `nvim-jdtls`

Refer to [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) for detailed configuration

```lua
local jdtls_config = {
  bundles = {}
}
-- Add spring-boot jdtls extension jars
vim.list_extend(jdtls_config.bundles, require("spring_boot").java_extensions())
```

### Option 2: Using `nvim-lspconfig`

```lua
-- Add global command handlers
require('spring_boot').init_lsp_commands()
-- Add spring-boot jdtls extension jars
require("lspconfig").jdtls.setup {
  init_options = {
    bundles = require("spring_boot").java_extensions(),
  },
}
```

## Usage

- Find Beans using Spring annotations:
  ```vim
  :FzfLua lsp_live_workspace_symbols
  ```
  ![lsp_live_workspace_symbols](https://javahello.github.io/dev/nvim-lean/images/spring-boot.png)
