# Spring Boot Nvim

Integrate some features from the [VScode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) plugin into `Neovim`.

- [x] Find Beans annotated with `Spring`.
- [x] Find Web Endpoints.
- [x] Autocompletion and navigation for `application.properties` and `application.yml` files.
- [x] Code snippet completion.
- [x] `Code Action`.

## Installation

- `lazy.nvim`
  ```lua
    {
      "JavaHello/spring-boot.nvim",
      ft = "java",
      dependencies = {
        "mfussenegger/nvim-jdtls", -- or nvim-java, nvim-lspconfig
        "ibhagwan/fzf-lua", -- optional
      },
    }
  ```
- Optionally, install [VScode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) in [Visual Studio Code](https://code.visualstudio.com/).

## Configuration

### `spring-boot.nvim`

```lua
  require('spring_boot').setup({})
```

- Default configuration
  ```lua
    vim.g.spring_boot = {
      jdt_extensions_path = nil, -- defaults to ~/.vscode/extensions/vmware.vscode-spring-boot-x.xx.x
      jdt_extensions_jars = {
        "io.projectreactor.reactor-core.jar",
        "org.reactivestreams.reactive-streams.jar",
        "jdt-ls-commons.jar",
        "jdt-ls-extension.jar",
      },
    }
    require('spring_boot').setup({
      ls_path = nil, -- defaults to ~/.vscode/extensions/vmware.vscode-spring-boot-x.xx.x
      jdtls_name = "jdtls",
      log_file = nil,
    })
  ```

### `nvim-jdtls`

For detailed configuration, refer to the [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) project.

```lua
local jdtls_config = {
  bundles = {}
}
-- Add spring-boot jdtls extension jar files
vim.list_extend(jdtls_config.bundles, require("spring_boot").java_extensions())
```

### `nvim-lspconfig`

```lua
require('spring_boot').init_lsp_commands()
require("lspconfig").jdtls.setup {
  init_options = {
    bundles = require("spring_boot").java_extensions(),
  },
}
```

## Usage

- Find Beans annotated with `Spring`.
  ```vim
  :FzfLua lsp_live_workspace_symbols
  ```
  ![lsp_live_workspace_symbols](https://javahello.github.io/dev/nvim-lean/images/spring-boot.png)
