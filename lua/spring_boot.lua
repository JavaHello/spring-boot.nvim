vim.g.spring_boot = {
  jdt_extensions_path = nil,
  jdt_extensions_jars = {
    "io.projectreactor.reactor-core.jar",
    "org.reactivestreams.reactive-streams.jar",
    "jdt-ls-commons.jar",
    "jdt-ls-extension.jar",
  },
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

local initialized = false
M.setup = function(opts)
  if initialized then
    return
  end
  M._config = opts
  require("spring_boot.launch").setup()
  initialized = true
end

M.java_extensions = function()
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
