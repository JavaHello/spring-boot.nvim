local M = {}

local launch = require("spring_boot.launch")
local config = require("spring_boot.config")
M.setup = function(opts)
  vim.tbl_extend("force", config, opts)
  launch.setup(config.server)
end

M.java_extensions = function()
  return launch.jdt_extensions_jars()
end

M.enable_classpath_listening = function()
  launch.enable_classpath_listening()
end

return M
