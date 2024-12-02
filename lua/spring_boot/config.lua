---@class bootls.Config
---@field ls_path? string The path to the language server jar path.
---@field jdtls_name string The name of the JDTLS language server. default: "jdtls"
---@field java_cmd? string The path to the java command.
---@field log_file? string|function The path to the spring boot ls log file.
---@field server vim.lsp.ClientConfig The language server configuration.
---@field exploded_ls_jar_data boolean The exploded language server jar data.

---@type bootls.Config
local M = {
  ls_path = nil,
  exploded_ls_jar_data = false,
  jdtls_name = "jdtls",
  java_cmd = nil,
  log_file = nil,
  server = {
    cmd = {},
  },
}

-- local function init()
--   local spring_boot = require("spring_boot")
--   M = vim.tbl_deep_extend("keep", spring_boot._config, M)
--   spring_boot._config = nil
-- end
-- init()

return M
