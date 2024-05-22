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
