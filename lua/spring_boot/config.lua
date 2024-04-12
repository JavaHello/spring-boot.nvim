local M = {
  jdtls_name = "jdtls",
  log_file = function(root_dir)
    return root_dir .. "/.spring-boot-ls.log"
  end,
  ls_path = nil,
  jdt_extensions_path = nil,
  jdt_extensions_jars = {
    "io.projectreactor.reactor-core.jar",
    "org.reactivestreams.reactive-streams.jar",
    "jdt-ls-commons.jar",
    "jdt-ls-extension.jar",
  },
  server = {},
}
return M
