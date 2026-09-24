local M = {}

--- The settings the client sends the server, shaped after the Eclipse client's
--- `sendConfiguration()` — one `boot-java` object holding the preferences the
--- server cannot know on its own. The values are the ones that client
--- initialises its preference store with, minus the ones that configure
--- features this plugin has no equivalent for (`live-information`,
--- `remote-apps`, the AI server), which are left to the server's defaults.
--- see https://github.com/spring-projects/sts4/blob/cfd10f0b53be0bfe107ca91ae0ad3df3038b1af2/eclipse-language-servers/org.springframework.tooling.boot.ls/src/org/springframework/tooling/boot/ls/DelegatingStreamConnectionProvider.java
---@type table<string, table>
local DEFAULTS = {
  ["boot-java"] = {
    jpql = true,
    ["support-spring-xml-config"] = {
      on = false,
      ["scan-folders"] = "src/main",
      hyperlinks = true,
      ["content-assist"] = true,
    },
    ["scan-java-test-sources"] = { on = false },
    ["modulith-project-tracking"] = true,
    java = {
      ["beans-structure-tree"] = true,
      reconcilers = true,
      completions = { ["inject-bean"] = true },
      ["codelens-over-query-methods"] = true,
      ["codelens-web-configs-on-controller-classes"] = true,
    },
    ["code-action"] = { ["data-query-multiline"] = false },
    properties = { completions = { ["elide-prefix"] = false } },
    cron = { ["inlay-hints"] = true },
  },
}

--- Sends the settings, merged with whatever `server.settings` in the
--- configuration holds so users keep the last word.
---
--- This is more than configuration: a `workspace/didChangeConfiguration` makes
--- the server index every project from source again — `SpringSymbolIndex`
--- listens for it and calls `initializeProject(project, clean = true)`, which
--- bypasses the symbol cache. That is what repairs an index built from cache
--- entries claiming a project's files hold no symbols, which otherwise stays
--- empty until a source file happens to change.
---@param client vim.lsp.Client
M.push = function(client)
  local configured = require("spring_boot.config").server
  local settings = vim.tbl_deep_extend("force", DEFAULTS, (configured and configured.settings) or {})
  client:notify("workspace/didChangeConfiguration", { settings = settings })
end

return M
