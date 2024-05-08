local M = {}

local launch = require("spring_boot.launch")
M.setup = function(opts)
  local config = vim.tbl_deep_extend("force", require("spring_boot.config"), opts)
  launch.setup(config)
end

M.java_extensions = function()
  return launch.jdt_extensions_jars()
end

return M
