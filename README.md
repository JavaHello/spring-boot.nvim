[English](./README_en.md)

# Spring Boot Nvim

参考 [VScode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) 插件, 将它的部分功能集成到 `Neovim` 中。

- [x] 查找使用了 `Spring` 注解的 `Bean`。
- [x] 查找 Web Endpoints。
- [x] `application.properties`, `application.yml` 文件补全提示, 以及跳转。
- [x] `Spring` 注解依赖提示补全。
- [x] `Code Action`。

## 要求

- `Neovim 0.12+`。插件在 `runtimepath` 上提供 `lsp/spring-boot.lua`，通过 `vim.lsp.config()` / `vim.lsp.enable()` 接入 LSP。

## 安装

- `lazy.nvim`
  ```lua
  -- 默认使用 mason 或 ~/.vscode/extensions/vmware.vscode-spring-boot-x.xx.x 中的 jar
  {
    "JavaHello/spring-boot.nvim",
    ft = { "java", "yaml", "jproperties" },
    dependencies = {
      "mfussenegger/nvim-jdtls", -- or nvim-java, nvim-lspconfig
      "ibhagwan/fzf-lua", -- 可选，用于符号选择等UI功能。也可以使用其他选择器（例如 telescope.nvim）。
    },
    ---@type bootls.Config
    opts = {}
  },
  ```

  插件加载时会自动调用 `vim.lsp.enable("spring-boot")`，无需再手动配置 LSP。

  如果你希望自己控制启动时机，设置 `opts = { auto_enable = false }`，然后自行调用 `vim.lsp.enable("spring-boot")`。

- [Visual Studio Code](https://code.visualstudio.com/) 中安装 [VScode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot)(可选的)

## 配置

`opts` 中可用的字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ls_path` | `string?` | 语言服务器 jar（或解压后的目录）路径。默认依次从 mason-registry、vscode 扩展目录查找。 |
| `java_cmd` | `string?` | `java` 可执行文件路径。默认 `$JAVA_HOME/bin/java`，否则 `java`。 |
| `log_file` | `string\|fun(root_dir: string?): string?` | 服务端日志文件。默认不记录日志（`/dev/null`）。 |
| `log_level` | `string?` | 根日志级别，默认 `warn`。 |
| `jvm_args` | `string[]?` | 追加的 JVM 参数。 |
| `jars` | `string[]?` | 显式指定 jdtls 扩展 jar，跳过自动查找。 |
| `project_filter` | `fun(root_dir: string): boolean?` | 决定某个工作区是否启动客户端。见[按需启动](#按需启动)。 |
| `jdtls_name` | `string?` | jdtls 客户端名，默认 `jdtls`。 |
| `server` | `vim.lsp.ClientConfig?` | 额外合并进 `spring-boot` 客户端配置的字段，优先级最高。 |
| `auto_enable` | `boolean?` | 是否在 `setup()` 中自动 `vim.lsp.enable("spring-boot")`，默认 `true`。 |

例如把服务端日志留到文件里排查问题：

```lua
opts = {
  log_file = function(root_dir)
    return vim.fs.joinpath(vim.fn.stdpath("log"), "spring-boot-ls.log")
  end,
  log_level = "debug",
}
```

## 按需启动

默认情况下，只要找到了语言服务器，`java` 文件和 `application*.yml` / `application*.properties` 就会启动客户端。如果只想在真正的 Spring Boot 工程里启动，加一个项目级判断：

```lua
opts = {
  project_filter = function(root_dir)
    return require("spring_boot.util").has_spring_boot_dependency(root_dir)
  end,
}
```

`project_filter` 在插件找到工作区根目录、并通过内置的 `application.yml` / `.properties` 文件名判断之后调用，返回 `false` 就不启动。判断期间抛错会当作 `true` 处理并给出警告，避免谓词写错时静默失去补全。

`has_spring_boot_dependency(root_dir)` 检查 `pom.xml` / `build.gradle` / `build.gradle.kts`，识别 `spring-boot-starter-*`、`spring-boot-starter-parent` 以及 Gradle 的 `org.springframework.boot` 插件。多模块工程的聚合根 pom 常常只列 `<modules>`，因此会广度优先往下找子模块（最多 3 层、最多读 50 个构建文件，`target/`、`build/` 等输出目录跳过）。

判断结果按工作区缓存（`root_dir` 在每次 `FileType` 事件都会执行，而谓词可能要读构建文件）。改动 pom 之后重新调用一次 `setup()` 即可清空缓存重新评估。

## 覆盖 LSP 配置

`spring-boot` 客户端配置按 `vim.lsp.config()` 的[合并链](https://neovim.io/doc/user/lsp.html#lsp-config-merge)解析：先插件自带的 `lsp/spring-boot.lua`，再 `after/lsp/spring-boot.lua`，最后 `opts.server`。因此可以像配置其他 LSP 一样覆盖任意字段：

```lua
-- ~/.config/nvim/after/lsp/spring-boot.lua
return {
  on_attach = function(client, bufnr)
    -- ...
  end,
}
```

## `jdtls` 配置

Spring Boot 的 `Java` 相关能力（依赖提示、`Code Action` 等）由 jdtls 的扩展 jar 提供。

### 选项 1: 使用 `nvim-jdtls`

详细配置参考 [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) 项目

```lua
local jdtls_config = {
  bundles = {}
}
-- 添加 spring-boot jdtls 扩展 jar 包
vim.list_extend(jdtls_config.bundles, require("spring_boot").java_extensions())
```

### 选项 2: 使用 `nvim-lspconfig`

```lua
-- 添加 spring-boot jdtls 扩展 jar 包
require("lspconfig").jdtls.setup {
  init_options = {
    bundles = require("spring_boot").java_extensions(),
  },
}
```

## 使用

- 查找使用了 `Spring` 注解的 `Bean`、`Web Endpoints` 等，插件自带命令：

  ```vim
  :SpringBoot              " 弹出选择：Annotations / Beans / RequestMappings / Prototype
  :SpringBoot Beans        " 直接查询，支持补全
  ```

  对应的服务端查询语法：`Annotations` → `@`，`Beans` → `@+`，`RequestMappings` → `@/`，`Prototype` → `@>`。结果通过 `vim.ui.select` 展示（因此您使用的选取器插件决定 UI）。

  也可以自己用模糊查找器查询 LSP 工作区符号，此时请带上查询前缀：
  - 如果您正在使用 `fzf-lua`：
    ```vim
    :FzfLua lsp_live_workspace_symbols
    ```
  - 如果您正在使用 `telescope.nvim`：
    ```lua
    require'telescope.builtin'.lsp_workspace_symbols{}
    ```
  *(注意：具体命令可能因您选择的选取器及其配置而异。请确保您的选取器已配置为处理 LSP 符号。)*
  ![lsp_live_workspace_symbols](https://github.com/JavaHello/javahello.github.io/raw/refs/heads/master/content/posts/nvim-lean/images/spring-boot.png)

## 排查问题

```vim
:checkhealth spring_boot
```

会依次检查 `java` 可执行文件、语言服务器路径（及 mason / vscode 扩展两个来源）、jdtls 扩展 jar、`$MASON`、配置是否已启用，以及当前运行中的客户端及其 `root_dir`。

服务端自身的日志默认丢弃，排查启动失败时建议先按上面的例子设置 `log_file` 和 `log_level = "debug"`。

### 没有 `Bean` / `Endpoint` / 属性提示

插件会和 VS Code、Eclipse STS 一样推送设置，服务端收到后会重新按源码索引一遍（绕过符号缓存），因此不需要手工清理什么。如果依旧为空，说明服务端拿到的项目 classpath 不完整（机制见 `lua/spring_boot/settings.lua` 的注释），清空该项目的 jdtls 工作区再重启即可：

- `nvim-jdtls`：`:JdtWipeDataAndRestart`
- 其他接入方式：`ps -eo command | grep -o -- '-data [^ ]*'` 查出目录后删除
