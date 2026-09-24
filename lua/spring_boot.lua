local jdt_extensions_jars = {
  "io.projectreactor.reactor-core.jar",
  "org.reactivestreams.reactive-streams.jar",
  "jdt-ls-commons.jar",
  "jdt-ls-extension.jar",
  "sts-gradle-tooling.jar",
}

local spring_boot = {
  jdt_extensions_path = nil,
  -- https://github.com/spring-projects/sts4/blob/7d3d91ecfa6087ae2d0e0f595da61ce8f52fed96/vscode-extensions/vscode-spring-boot/package.json#L33
  jdt_expanded_extensions_jars = {},
  is_bundle_jar = function(path)
    for _, jar in ipairs(jdt_extensions_jars) do
      if vim.endswith(path, jar) then
        return true
      end
    end
  end,
}

local M = {}

--- Handles `workspace/executeClientCommand`: a server asking the editor to run
--- a command, possibly on another server. The command is resolved through the
--- client that sent the request, so per-client `commands` win.
---
--- `lsp/spring-boot.lua` registers this on the `spring-boot` client, which
--- covers the Spring Boot LS itself. The commands jdtls sends to its own client
--- need the global variant installed by |spring_boot.init_lsp_commands()|,
--- unless nvim-jdtls already provided one.
--- see https://github.com/mfussenegger/nvim-jdtls/blob/29255ea26dfb51ef0213f7572bff410f1afb002d/lua/jdtls.lua#L819
---@type lsp.Handler
M.execute_client_command = function(_, params, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id) or {}
  local commands = client.commands or {}
  local global_commands = vim.lsp.commands
  local fn = commands[params.command] or global_commands[params.command]
  if fn then
    local ok, result = pcall(fn, params.arguments, ctx)
    if ok then
      return result == nil and vim.NIL or result
    else
      return vim.lsp.rpc_response_error(vim.lsp.protocol.ErrorCodes.InternalError, result)
    end
  else
    return vim.lsp.rpc_response_error(
      vim.lsp.protocol.ErrorCodes.MethodNotFound,
      "Command " .. params.command .. " not supported on client"
    )
  end
end

--- Installs `workspace/executeClientCommand` globally, for every client.
---
--- The `spring-boot` client does not need this, but other clients a server may
--- want to delegate to (such as a `jdtls` set up through nvim-lspconfig) do.
M.init_lsp_commands = function()
  if vim.lsp.handlers["workspace/executeClientCommand"] then
    -- Already provided, e.g. by an earlier call or by nvim-jdtls.
    return
  end
  if pcall(require, "jdtls") then
    -- Loading nvim-jdtls just installed its own equivalent handler. Prefer it
    -- rather than clobbering it.
    return
  end
  vim.lsp.handlers["workspace/executeClientCommand"] = M.execute_client_command -- luacheck: ignore 122
end

--- Registers the commands a server asks the editor to run through
--- `workspace/executeClientCommand`.
---
--- These belong in the global |vim.lsp.commands| and not in the `spring-boot`
--- config's `commands`, because the one that matters here is sent by the *jdtls*
--- extension, once jdtls has imported a Spring Boot project — so it is
--- dispatched on the `jdtls` client, whose handler resolves commands against
--- that client and the global table only. A `commands` entry on the
--- `spring-boot` client is never consulted for it.
---
--- This is the start of the classpath handshake: the command makes the editor
--- ask the language server to listen for classpath changes
--- (`sts.vscode-spring-boot.enableClasspathListening`), and without it the
--- server never learns the project's classpath — no beans, no endpoints, no
--- `application.properties` / `.yml` properties.
--- see https://github.com/spring-projects/sts4/blob/cfd10f0b53be0bfe107ca91ae0ad3df3038b1af2/headless-services/jdt-ls-extension/org.springframework.tooling.jdt.ls.extension/src/org/springframework/tooling/jdt/ls/extension/JdtLsExtensionPlugin.java
M.register_client_commands = function()
  vim.lsp.commands["vscode-spring-boot.ls.start"] = function()
    require("spring_boot.util").boot_execute_command("sts.vscode-spring-boot.enableClasspathListening", { true })
  end
end

M.get_ls_from_mason = function()
  local result = M.get_from_mason_registry("vscode-spring-boot-tools", "language-server.jar")
  if #result > 0 then
    return result[1]
  end
  return nil
end

M.get_from_mason_registry = function(package_name, filter)
  local success, mason_registry = pcall(require, "mason-registry")
  local result = {}
  if success then
    local has_package, mason_package = pcall(mason_registry.get_package, package_name)
    if has_package then
      if mason_package:is_installed() then
        for key, value in pairs(vim.fn.globpath("$MASON/share/" .. package_name, filter or "*", true, true)) do
          table.insert(result, value)
        end
      end
    end
  end
  return result
end

M.get_boot_ls = function(ls_path)
  if not ls_path then
    ls_path = M.get_ls_from_mason() -- get ls from mason-registry
  end
  if not ls_path then
    ls_path = require("spring_boot.vscode").find_one("/vmware.vscode-spring-boot-*/language-server")
  end
  if ls_path then
    if vim.fn.isdirectory(ls_path .. "/BOOT-INF") ~= 0 then
      -- it's an exploded jar
      return ls_path
    elseif (ls_path:sub(-#".jar")) ~= ".jar" then
      -- it's a single jar
      local server_jar = vim.split(vim.fn.glob(ls_path .. "/spring-boot-language-server*.jar"), "\n")
      if #server_jar > 0 then
        return server_jar[1]
      end
    end
  end
  return ls_path
end

M.get_jars = function(jar_paths)
  local bundles
  if not jar_paths then
    bundles = M.get_from_mason_registry("vscode-spring-boot-tools", "jars/*.jar")
    if not bundles or #bundles == 0 then
      -- see https://github.com/mason-org/mason-registry/blob/7794e2ddc7ecc7e37650f58e45eb51c3d579cdbb/packages/vscode-spring-boot-tools/package.yaml#L25
      bundles = M.get_from_mason_registry("vscode-spring-boot-tools", "jdtls/*.jar")
    end
    jar_paths = require("spring_boot.vscode").find_one("/vmware.vscode-spring-boot-*/jars")
  end
  if (not bundles or #bundles == 0) and jar_paths then
    bundles = vim.split(vim.fn.glob(jar_paths .. "/*.jar"), "\n")
  end
  local result = {}
  if bundles and #bundles > 0 then
    for _, bundle in ipairs(bundles) do
      if spring_boot.is_bundle_jar(bundle) then
        table.insert(result, bundle)
      end
    end
  end
  return result
end

--- Merges `opts` into the plugin configuration, resolves the language server
--- and enables the client.
---
--- Safe to call more than once; later calls override earlier ones.
---
---@param opts? bootls.Config
---@return bootls.Config
M.setup = function(opts)
  local config = require("spring_boot.config")
  -- `vim.tbl_deep_extend` allocates a new table, so the result has to be
  -- copied back: other modules read the options off the config module.
  for key, value in pairs(vim.tbl_deep_extend("force", config, opts or {})) do
    config[key] = value
  end

  if not config.ls_path then
    -- get ls from mason-registry, then from the vscode extension directory
    config.ls_path = M.get_boot_ls()
  end
  if not config.ls_path then
    -- all possibilities finding the language server failed
    vim.notify("Spring Boot LS is not installed. Run :checkhealth spring_boot", vim.log.levels.WARN)
    return config
  end

  -- The classpath handshake starts on jdtls' side, so both the handler and the
  -- command have to be registered globally, before jdtls imports a Spring Boot
  -- project. See |spring_boot.register_client_commands()|.
  M.register_client_commands()
  M.init_lsp_commands()

  -- `:SpringBoot` symbol queries. See |spring_boot.commands|.
  require("spring_boot.commands").register()

  -- Options may have changed, so workspaces are re-judged by `project_filter`.
  require("spring_boot.launch").clear_project_filter_cache()

  -- Highest priority layer of the config merge chain, see |lsp-config-merge|.
  -- Everything else comes from the `lsp/spring-boot.lua` shipped with the
  -- plugin, which reads the rest of `config` lazily.
  vim.lsp.config("spring-boot", config.server or {})
  if config.auto_enable then
    vim.lsp.enable("spring-boot")
  end
  return config
end

M.java_extensions = function(jar_paths)
  -- `jars` from the configuration is consulted before the memoized lookup, so
  -- setting it in `setup()` still takes effect when this ran earlier — the
  -- discovery is what gets memoized, not the configured value. See
  -- |:checkhealth spring_boot|, which calls this.
  local configured = require("spring_boot.config").jars
  if configured and #configured > 0 then
    return configured
  end
  if spring_boot.jdt_expanded_extensions_jars and #spring_boot.jdt_expanded_extensions_jars > 0 then
    return spring_boot.jdt_expanded_extensions_jars
  end
  local bundles = M.get_jars(jar_paths)
  if #bundles > 0 then
    spring_boot.jdt_expanded_extensions_jars = bundles
  end
  return bundles
end

return M
