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

M.init_lsp_commands = function()
  local o, _ = pcall(require, "jdtls")
  if o then
    return
  end
  -- see  https://github.com/mfussenegger/nvim-jdtls/blob/29255ea26dfb51ef0213f7572bff410f1afb002d/lua/jdtls.lua#L819
  if not vim.lsp.handlers["workspace/executeClientCommand"] then
    vim.lsp.handlers["workspace/executeClientCommand"] = function(_, params, ctx) -- luacheck: ignore 122
      local client = vim.lsp.get_client_by_id(ctx.client_id) or {}
      local commands = client.commands or {}
      local global_commands = vim.lsp.commands
      local fn = commands[params.command] or global_commands[params.command]
      if fn then
        local ok, result = pcall(fn, params.arguments, ctx)
        if ok then
          return result
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
        for _, value in pairs(vim.fn.globpath("$MASON/share/" .. package_name, filter or "*", true, true)) do
          if spring_boot.is_bundle_jar(value) then
            table.insert(result, value)
          end
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
  local bundles = {}
  if not jar_paths then
    bundles = M.get_from_mason_registry("vscode-spring-boot-tools", "jars/*.jar")
    if bundles and #bundles > 0 then
      return bundles
    else
      jar_paths = require("spring_boot.vscode").find_one("/vmware.vscode-spring-boot-*/jars")
    end
  end
  if jar_paths then
    for _, bundle in ipairs(vim.split(vim.fn.glob(jar_paths .. "/*.jar"), "\n")) do
      if spring_boot.is_bundle_jar(bundle) then
        table.insert(bundles, bundle)
      end
    end
  end
  return bundles
end

local initialized = false

---@param opts bootls.Config
M.setup = function(opts)
  if initialized then
    return
  end
  initialized = true
  opts = vim.tbl_deep_extend("keep", opts or {}, require("spring_boot.config"))
  if not opts.ls_path then
    opts.ls_path = M.get_boot_ls() -- get ls from mason-registry
  end
  if not opts.ls_path then
    -- all possibilities finding the language server failed
    vim.notify("Spring Boot LS is not installed", vim.log.levels.WARN)
    return
  end
  if vim.fn.isdirectory(opts.ls_path .. "/BOOT-INF") ~= 0 then
    -- a path was given in opts
    opts.exploded_ls_jar_data = true
  else
    opts.exploded_ls_jar_data = false
  end
  M.init_lsp_commands()

  if opts.autocmd then
    require("spring_boot.launch").ls_autocmd(opts)
  end
  return opts
end

M.java_extensions = function(jar_paths)
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
