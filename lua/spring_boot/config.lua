local M = {
  ls_path = nil,
  jdtls_name = "jdtls",
  log_file = nil,
  server = {},
}

local function init()
  local spring_boot = require("spring_boot")
  M = vim.tbl_deep_extend("keep", spring_boot._config, M)
  spring_boot._config = nil
end
init()

return M
