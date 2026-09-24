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
--- empty until a source file happens to change. (|spring_boot.classpath| sends
--- this once the classpath events of a burst have settled, so that the projects
--- are registered before the server answers the notification.)
---
--- What it cannot repair is an empty *scan*: when the server's log ends a
--- project at
---
---     scan java files done, number of index elements created: 0
---
--- the index is empty because the project's classpath, as the server received
--- it, has no `jre` — the indexer's parser then has no JRE and no jars, so it
--- cannot resolve the meta-annotations behind `@Service` or `@RestController`
--- (`@Component` on `@Service` is defined in `spring-context`) and produces
--- nothing, which the cache faithfully records as "indexed, no symbols". The
--- JRE field comes from `JavaRuntime.getVMInstall(project)` on the jdtls side
--- (`ClasspathUtil.resolve`), which returns null once the bindings between
--- execution environments and installed JVMs in the jdtls *workspace* — the
--- directory behind its `-data` argument — go stale, as they do when the
--- installed JDKs change. No settings push can fix that: only re-importing the
--- project into a fresh workspace does. The server can be asked to prove it:
--- over its embedded MCP endpoint `getJavaVersion` fails with
--- `IClasspath.getJre()` null and `getProjectList` reports `javaVersion: null`
--- for every project, where a healthy session answers with the JRE version.
---@param client vim.lsp.Client
M.push = function(client)
  local configured = require("spring_boot.config").server
  local settings = vim.tbl_deep_extend("force", DEFAULTS, (configured and configured.settings) or {})
  client:notify("workspace/didChangeConfiguration", { settings = settings })
end

return M
