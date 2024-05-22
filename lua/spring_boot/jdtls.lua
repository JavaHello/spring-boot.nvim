local M = {}
local config = require("spring_boot.config")
local util = require("spring_boot.util")
M.get_jdtls_client = function()
  return util.get_client(config.jdtls_name)
end

M.execute_command = function(command, param)
  local err, resp = util.execute_command(M.get_jdtls_client(), command, param)
  if err then
    print("Error executeCommand: " .. command .. "\n" .. vim.inspect(err))
  end
  return resp
end

return M
