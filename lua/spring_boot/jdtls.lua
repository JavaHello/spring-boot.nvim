local M = {}
local config = require("spring_boot.config")
local util = require("spring_boot.util")
M.get_jdtls_client = function()
  return util.get_client(config.jdtls_name)
end

--- Sends `command` to jdtls and returns its result, or nil when jdtls is not
--- running or does not answer in time.
---
--- `timeout_ms` abandons the wait, not the command: the request stays in
--- flight, so a slow jdtls still does the work. Callers that have to answer a
--- request of their own should pass it — jdtls runs commands behind its
--- project import, which can take far longer than such a caller is allowed to
--- wait. See |spring_boot.classpath|.
---@param command string
---@param param? table
---@param timeout_ms? integer
M.execute_command = function(command, param, timeout_ms)
  local client = M.get_jdtls_client()
  if not client then
    vim.notify("spring_boot: no jdtls client for " .. command, vim.log.levels.WARN)
    return
  end

  if not timeout_ms then
    local err, resp = util.execute_command(client, command, param)
    if err then
      print("Error executeCommand: " .. command .. "\n" .. vim.inspect(err))
    end
    return resp == nil and vim.NIL or resp
  end

  local done, err, resp = false, nil, nil
  util.execute_command(client, command, param, function(e, r)
    done, err, resp = true, e, r
  end)
  vim.wait(timeout_ms, function()
    return done
  end)
  if err then
    print("Error executeCommand: " .. command .. "\n" .. vim.inspect(err))
  end
  -- A server request needs a result or an error, which includes the case of
  -- this wait being abandoned — a bare nil is not a valid answer.
  return resp == nil and vim.NIL or resp
end

return M
