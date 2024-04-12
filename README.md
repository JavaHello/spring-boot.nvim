# Spring Boot LS

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
        "mfussenegger/nvim-jdtls",
        "ibhagwan/fzf-lua", -- 可选
      },
    }
  ```

## 配置

### `spring-boot.nvim`

```lua
  require('spring_boot').setup({
    ls_path = nil, -- 默认依赖 vscode-spring-boot 插件, 如果没有安装 vscode 插件，可以指定路径
    jdt_extensions_path = nil, -- 默认依赖 vscode-spring-boot 插件
  })
```

### `nvim-jdtls`

详细配置参考[nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls)项目

```lua
local jdtls_config = {}
local bundles = {}
-- 添加 spring-boot jdtls 扩展 jar 包
vim.list_extend(bundles, require("spring_boot").java_extensions())


-- 启用 spring-boot classpath_listening
jdtls_config["on_init"] = function(client, _)
  require("spring_boot").enable_classpath_listening()
end
```

## 使用

- 查找使用了 `Spring` 注解的 `Bean`。
  ```vim
  :FzfLua lsp_live_workspace_symbols
  ```
  ![lsp_live_workspace_symbols](https://javahello.github.io/dev/nvim-lean/images/spring-boot.png)
