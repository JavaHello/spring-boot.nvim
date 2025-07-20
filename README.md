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
      "ibhagwan/fzf-lua", -- 可选，用于符号选择等UI功能。也可以使用其他选择器（例如 telescope.nvim）。
    },
    ---@type bootls.Config
    opts = {}
  },

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
  此功能利用 LSP 工作区符号。您可以使用您偏好的、支持显示 LSP 工作区符号的模糊查找器。
  例如：
  - 如果您正在使用 `fzf-lua`：
    ```vim
    :FzfLua lsp_live_workspace_symbols
    ```
  - 如果您正在使用 `telescope.nvim`：
    ```vim
    :lua require'telescope.builtin'.lsp_workspace_symbols{}
    ```
  *(注意：具体命令可能因您选择的选取器及其配置而异。请确保您的选取器已配置为处理 LSP 符号。)*
  ![lsp_live_workspace_symbols](https://github.com/JavaHello/javahello.github.io/raw/refs/heads/master/content/posts/nvim-lean/images/spring-boot.png)

