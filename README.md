[English](./README_en.md)

# Spring Boot Nvim

参考 [VScode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) 插件, 将它的部分功能集成到 `Neovim` 中。

- [x] 查找使用了 `Spring` 注解的 `Bean`。
- [x] 查找 Web Endpoints。
- [x] `application.properties`, `application.yml` 文件补全提示, 以及跳转。
- [x] `Spring` 注解依赖提示补全。
- [x] `Code Action`。

## 安装

- `lazy.nvim`
  ```lua
  -- 使用 `autocmd` 方式启动(默认)
  -- 默认使用 mason 或 ~/.vscode/extensions/vmware.vscode-spring-boot-x.xx.x 中的 jar
  {
    "JavaHello/spring-boot.nvim",
    ft = {"java", "yaml", "jproperties"},
    dependencies = {
      "mfussenegger/nvim-jdtls", -- or nvim-java, nvim-lspconfig
      "ibhagwan/fzf-lua", -- 可选
    },
    ---@type bootls.Config
    opts = {}
  },

  -- 使用 `ftplugin` 或自定义 方式启动
  -- 如果你使用 `nvim-jdtls`，并且使用 `ftplugin/java.lua` 的方式启动 `jdtls` 这种方式是推荐的
  {
    "JavaHello/spring-boot.nvim",
    lazy = true,
    dependencies = {
      "mfussenegger/nvim-jdtls", -- or nvim-java, nvim-lspconfig
    },
    config = false
  }
  ```
- [Visual Studio Code](https://code.visualstudio.com/) 中安装[VScode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot)(可选的)

## `jdtls` 配置

### 选项 1: 使用 `nvim-jdtls`

详细配置参考[nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls)项目

```lua
local jdtls_config = {
  bundles = {}
}
-- 添加 spring-boot jdtls 扩展 jar 包
vim.list_extend(jdtls_config.bundles, require("spring_boot").java_extensions())
```

### 选项 2: 使用 `nvim-lspconfig`

```lua
-- 添加全局命令处理器
require('spring_boot').init_lsp_commands()
-- 添加 spring-boot jdtls 扩展 jar 包
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
  ![lsp_live_workspace_symbols](https://github.com/JavaHello/javahello.github.io/raw/refs/heads/master/content/posts/nvim-lean/images/spring-boot.png)
