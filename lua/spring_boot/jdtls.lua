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

--- Sends `command` to jdtls and returns without waiting for its answer, which
--- is only reported when it fails.
---
--- Use this from a handler that has to answer a request itself: jdtls runs
--- commands behind its project import, so waiting for one can take far longer
--- than the caller is willing to wait. See |spring_boot.classpath|.
M.execute_command_async = function(command, param)
  local client = M.get_jdtls_client()
  if not client then
    vim.notify("spring_boot: no jdtls client for " .. command, vim.log.levels.WARN)
    return
  end
  return util.execute_command(client, command, param, function(err, _)
    if err then
      vim.notify("spring_boot: error executing " .. command .. ": " .. vim.inspect(err), vim.log.levels.ERROR)
    end
  end)
end

return M
