---@class bootls.Config
---@field ls_path? string The path to the language server jar, or to an exploded jar directory (`BOOT-INF/`). When nil it is discovered from mason-registry, then from the vscode extension directory.
---@field java_cmd? string The path to the java command. Defaults to `$JAVA_HOME/bin/java`, then `java`.
---@field log_file? string|fun(root_dir: string?): string? The path to the spring boot ls log file. Defaults to `/dev/null` (logging disabled), and so does a callback that returns nothing. `root_dir` is nil when the workspace root is not known yet.
---@field log_level? string The root logging level of the language server. Defaults to `warn`.
---@field jvm_args? string[] Extra JVM arguments appended to the server command line.
---@field jars? string[] Explicit jdtls extension jars, skipping discovery. See |spring_boot.java_extensions()|.
---@field project_filter? fun(root_dir: string): boolean Decides whether the language server should run in a given workspace. Called once per workspace root, after the built-in gating. A predicate that errors is treated as `true`, so a bug there never silently disables the server. Defaults to nil (every workspace attaches). See |spring_boot.has_spring_boot_dependency()|.
---@field jdtls_name? string The name of the JDTLS language server client. Defaults to `jdtls`.
---@field server? vim.lsp.ClientConfig Extra fields merged into the `spring-boot` LSP config. Takes precedence over everything else.
---@field auto_enable? boolean Automatically call `vim.lsp.enable("spring-boot")` in |spring_boot.setup()|. Defaults to `true`.

---@type bootls.Config
local M = {
  ls_path = nil,
  java_cmd = nil,
  log_file = nil,
  log_level = "warn",
  jvm_args = nil,
  jars = nil,
  project_filter = nil,
  jdtls_name = "jdtls",
  server = {},
  auto_enable = true,
}

return M
