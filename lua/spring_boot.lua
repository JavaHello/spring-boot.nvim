vim.g.spring_boot = {
  jdt_extensions_path = nil,
  -- https://github.com/spring-projects/sts4/blob/7d3d91ecfa6087ae2d0e0f595da61ce8f52fed96/vscode-extensions/vscode-spring-boot/package.json#L33
  jdt_extensions_jars = {
    "io.projectreactor.reactor-core.jar",
    "org.reactivestreams.reactive-streams.jar",
    "jdt-ls-commons.jar",
    "jdt-ls-extension.jar",
    "sts-gradle-tooling.jar",
  },
  jdt_expanded_extensions_jars = {},
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
  local result = M.get_from_mason_registry("vscode-spring-boot-tools", "vscode-spring-boot-tools/language-server.jar")
  if #result > 0 then
    return result[1]
  end
  return nil
end

M.get_from_mason_registry = function(package_name, key_prefix)
  local success, mason_registry = pcall(require, "mason-registry")
  local result = {}
  if success then
    local mason_package = mason_registry.get_package(package_name)
    if mason_package:is_installed() then
      local install_path = mason_package:get_install_path()
      mason_package:get_receipt():if_present(function(recipe)
        for key, value in pairs(recipe.links.share) do
          if key:sub(1, #key_prefix) == key_prefix then
            table.insert(result, install_path .. "/" .. value)
          end
        end
      end)
    end
  end
  return result
end

local initialized = false
M.setup = function(opts)
  if initialized then
    return
  end
  opts = vim.tbl_deep_extend("keep", opts, require("spring_boot.config"))
  if not opts.ls_path then
    opts.ls_path = M.get_ls_from_mason() -- get ls from mason-registry
    if opts.ls_path then
      vim.g.spring_boot.jdt_expanded_extensions_jars =
        M.get_from_mason_registry("vscode-spring-boot-tools", "vscode-spring-boot-tools/jdtls/")
    else
      -- try to find ls on standard installation path of vscode
      opts.ls_path = require("spring_boot.vscode").find_one("/vmware.vscode-spring-boot-*/language-server")
      if vim.fn.isdirectory(opts.ls_path .. "/BOOT-INF") ~= 0 then
        -- it's an exploded jar
        opts.exploded_ls_jar_data = true
      else
        -- it's a single jar
        local server_jar = vim.split(vim.fn.glob(opts.ls_path .. "/spring-boot-language-server*.jar"), "\n")
        if #server_jar > 0 then
          opts.ls_path = server_jar[1]
        end
      end
    end
  end
  if vim.fn.isdirectory(opts.ls_path .. "/BOOT-INF") ~= 0 then
    -- a path was given in opts
    opts.exploded_ls_jar_data = true
  else
    opts.exploded_ls_jar_data = false
  end
  if not opts.ls_path then
    -- all possibilities finding the ls failed
    vim.notify("Spring Boot LS is not installed", vim.log.levels.WARN)
  end
  M.init_lsp_commands()
  require("spring_boot.launch").setup(opts)
  initialized = true
end

M.java_extensions = function()
  if vim.g.spring_boot.jdt_expanded_extensions_jars and #vim.g.spring_boot.jdt_expanded_extensions_jars > 0 then
    return vim.g.spring_boot.jdt_expanded_extensions_jars
  end
  local bundles = {}
  local function bundle_jar(path)
    for _, jar in ipairs(vim.g.spring_boot.jdt_extensions_jars) do
      if vim.endswith(path, jar) then
        return true
      end
    end
  end
  local spring_boot_path = vim.g.spring_boot.jdt_extensions_path
    or require("spring_boot.vscode").find_one("/vmware.vscode-spring-boot-*/jars")
  if spring_boot_path then
    for _, bundle in ipairs(vim.split(vim.fn.glob(spring_boot_path .. "/*.jar"), "\n")) do
      if bundle_jar(bundle) then
        table.insert(bundles, bundle)
      end
    end
  end
  return bundles
end

return M
