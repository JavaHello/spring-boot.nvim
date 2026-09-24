[中文](./README.md)

# Spring Boot Nvim

Adapted from the [VSCode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) extension, integrating some of its features into `Neovim`.

- [x] Find Beans using Spring annotations
- [x] Discover Web Endpoints
- [x] Code completion hints and navigation for `application.properties`/`application.yml`
- [x] Dependency hints/completion for Spring annotations
- [x] Code Actions

## Requirements

- `Neovim 0.12+`. The plugin ships `lsp/spring-boot.lua` on the runtimepath and plugs into LSP through `vim.lsp.config()` / `vim.lsp.enable()`.

## Installation

- `lazy.nvim`
  ```lua
  -- Default uses jars from mason or ~/.vscode/extensions/vmware.vscode-spring-boot-x.x.x
  {
    "JavaHello/spring-boot.nvim",
    ft = { "java", "yaml", "jproperties" },
    dependencies = {
      "mfussenegger/nvim-jdtls", -- or nvim-java, nvim-lspconfig
      "ibhagwan/fzf-lua", -- optional, for UI features like symbol picking. Other pickers (e.g., telescope.nvim) can also be used.
    },
    ---@type bootls.Config
    opts = {}
  },
  ```

  The plugin calls `vim.lsp.enable("spring-boot")` for you when it loads, so no extra LSP wiring is needed.

  To control when the client starts yourself, pass `opts = { auto_enable = false }` and call `vim.lsp.enable("spring-boot")` on your own.

- Install [VSCode Spring Boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot) in [Visual Studio Code](https://code.visualstudio.com/) (optional)

## Configuration

Fields accepted in `opts`:

| Field | Type | Description |
| --- | --- | --- |
| `ls_path` | `string?` | Path to the language server jar (or an exploded directory). Discovered from mason-registry, then the vscode extension directory. |
| `java_cmd` | `string?` | Path to the `java` executable. Defaults to `$JAVA_HOME/bin/java`, then `java`. |
| `log_file` | `string\|fun(root_dir: string?): string?` | The server's log file. Logging is disabled by default (`/dev/null`). |
| `log_level` | `string?` | Root logging level, defaults to `warn`. |
| `jvm_args` | `string[]?` | Extra JVM arguments. |
| `jars` | `string[]?` | Explicit jdtls extension jars, skipping discovery. |
| `project_filter` | `fun(root_dir: string): boolean?` | Decides whether the client starts in a given workspace. See [Starting on demand](#starting-on-demand). |
| `jdtls_name` | `string?` | Name of the jdtls client, defaults to `jdtls`. |
| `server` | `vim.lsp.ClientConfig?` | Extra fields merged into the `spring-boot` client config, at the highest priority. |
| `auto_enable` | `boolean?` | Whether `setup()` calls `vim.lsp.enable("spring-boot")`, defaults to `true`. |

For example, to keep the server log around when debugging:

```lua
opts = {
  log_file = function(root_dir)
    return vim.fs.joinpath(vim.fn.stdpath("log"), "spring-boot-ls.log")
  end,
  log_level = "debug",
}
```

## Starting on demand

By default the client starts for `java` files and for `application*.yml` / `application*.properties` as soon as the language server is found. To only start it inside actual Spring Boot projects, add a per-workspace check:

```lua
opts = {
  project_filter = function(root_dir)
    return require("spring_boot.util").has_spring_boot_dependency(root_dir)
  end,
}
```

`project_filter` is called once the workspace root has been found and the built-in `application.yml` / `.properties` filename check has passed; returning `false` keeps the client from starting. A predicate that raises is treated as `true` and warns, so a mistake there never silently costs you completion.

`has_spring_boot_dependency(root_dir)` reads `pom.xml` / `build.gradle` / `build.gradle.kts` and recognises `spring-boot-starter-*`, `spring-boot-starter-parent` and the Gradle `org.springframework.boot` plugin. Because an aggregator `pom.xml` in a multi-module build often only lists `<modules>`, submodules are searched too, breadth-first (at most 3 levels deep and 50 build files read, skipping output directories such as `target/` and `build/`).

Verdicts are memoized per workspace — `root_dir` runs on every `FileType` event and the predicate may read build files. Call `setup()` again to clear the cache and re-evaluate, for example after adding the dependency.

## Overriding the LSP config

The `spring-boot` client config resolves through the [config merge chain](https://neovim.io/doc/user/lsp.html#lsp-config-merge): the `lsp/spring-boot.lua` shipped by the plugin, then `after/lsp/spring-boot.lua`, then `opts.server`. Any field can therefore be overridden like any other LSP config:

```lua
-- ~/.config/nvim/after/lsp/spring-boot.lua
return {
  on_attach = function(client, bufnr)
    -- ...
  end,
}
```

## `jdtls` Configuration

The Java-side features (dependency hints, code actions, …) come from jdtls extension jars.

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
-- Add spring-boot jdtls extension jars
require("lspconfig").jdtls.setup {
  init_options = {
    bundles = require("spring_boot").java_extensions(),
  },
}
```

## Usage

- Find Beans using Spring annotations, Web Endpoints and more with the command the plugin ships:

  ```vim
  :SpringBoot              " prompts: Annotations / Beans / RequestMappings / Prototype
  :SpringBoot Beans        " query directly, completion included
  ```

  The server query behind each choice: `Annotations` → `@`, `Beans` → `@+`, `RequestMappings` → `@/`, `Prototype` → `@>`. Results are shown through `vim.ui.select`, so your picker plugin decides the UI.

  You can also query LSP workspace symbols yourself with a fuzzy finder — pass the query prefix then:
  - If you are using `fzf-lua`:
    ```vim
    :FzfLua lsp_live_workspace_symbols
    ```
  - If you are using `telescope.nvim`:
    ```lua
    require'telescope.builtin'.lsp_workspace_symbols{}
    ```
  *(Note: The exact command may vary depending on your chosen picker and its configuration. Ensure your picker is set up to handle LSP symbols.)*
  ![lsp_live_workspace_symbols](https://github.com/JavaHello/javahello.github.io/raw/refs/heads/master/content/posts/nvim-lean/images/spring-boot.png)

## Troubleshooting

```vim
:checkhealth spring_boot
```

Reports the `java` executable, the resolved language server path (plus both discovery sources: mason and the vscode extension), the jdtls extension jars, `$MASON`, whether the config is enabled, and the running clients with their `root_dir`.

The server's own log is discarded by default; when debugging a failed start, set `log_file` and `log_level = "debug"` as shown above.

### Index and symbol cache

The server caches each project's symbols in `~/.sts4/.symbolCache` (per project and classpath, keyed by file). As long as an entry is "fresh" the server does not parse those sources again — and once an entry records a file list with no symbols, it trusts it: that project's beans, endpoints and configuration-property diagnostics all stay empty until a source file changes or the classpath does.

So, like VS Code and Eclipse STS, the plugin sends its settings (`workspace/didChangeConfiguration`) once the client is up and again once the project data starts flowing. That notification makes the server index every project from source again — `SpringSymbolIndex` answers it with `initializeProject(project, clean = true)`, which bypasses the cache — so a bad entry is corrected on its own within seconds of starting, with nothing to clean by hand.

If you want to sidestep the cache anyway, the server's own switch can be passed through `jvm_args`:

```lua
opts = {
  jvm_args = { "-Dlanguageserver.boot.symbol-cache-enabled=false" },
}
```

The cost is parsing the sources on every start. The directory can also be moved with `-Dlanguageserver.boot.symbol-cache-dir=<dir>`.
