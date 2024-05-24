[English](./README_en.md)

# Spring Boot Nvim

参考 [VScode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) 插件, 将它的部分功能集成到 `Neovim` 中。

- [x] 查找使用了 `Spring` 注解的 `Bean`。
- [x] 查找 Web Endpoints。
- [x] `application.properties`, `application.yml` 文件补全提示, 以及跳转。
- [x] 代码片段补全。
- [x] `Code Action`。

> 部分功能可能不完整，欢迎提交 PR。

## 安装

- `lazy.nvim`
  ```lua
    {
      "JavaHello/spring-boot.nvim",
      ft = "java",
      dependencies = {
        "mfussenegger/nvim-jdtls", -- or nvim-java, nvim-lspconfig
        "ibhagwan/fzf-lua", -- 可选
      },
    }
  ```
- [Visual Studio Code](https://code.visualstudio.com/) 中安装[VScode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot)(可选的)

## 配置

### `spring-boot.nvim`

```lua
  require('spring_boot').setup({})
```

- 默认配置
  ```lua
    vim.g.spring_boot = {
      jdt_extensions_path = nil, -- 默认使用 ~/.vscode/extensions/vmware.vscode-spring-boot-x.xx.x
      jdt_extensions_jars = {
        "io.projectreactor.reactor-core.jar",
        "org.reactivestreams.reactive-streams.jar",
        "jdt-ls-commons.jar",
        "jdt-ls-extension.jar",
      },
    }
    require('spring_boot').setup({
      ls_path = nil, -- 默认使用 ~/.vscode/extensions/vmware.vscode-spring-boot-x.xx.x
      jdtls_name = "jdtls",
      log_file = nil,
    })
  ```

### `nvim-jdtls`

详细配置参考[nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls)项目

```lua
local jdtls_config = {
  bundles = {}
}
-- 添加 spring-boot jdtls 扩展 jar 包
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

## 使用

- 查找使用了 `Spring` 注解的 `Bean`。
  ```vim
  :FzfLua lsp_live_workspace_symbols
  ```
  ![lsp_live_workspace_symbols](https://javahello.github.io/dev/nvim-lean/images/spring-boot.png)
