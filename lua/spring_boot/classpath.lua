local M = {}

local handlers

--- Handlers for the classpath listener requests the Spring Boot language
--- server sends to the client. Both merely forward the request to jdtls.
---
--- The `callbackCommandId` the server picks is only known at request time, so
--- these callbacks have to be registered on `vim.lsp.commands` rather than
--- declared statically: the eventual `workspace/executeCommand` comes back
--- from jdtls, not from the client these handlers belong to.
---@return table<string, lsp.Handler>
M.handlers = function()
  if handlers then
    return handlers
  end
  handlers = {
    ["sts/addClasspathListener"] = function(_, result)
      local callbackCommandId = result.callbackCommandId
      vim.lsp.commands[callbackCommandId] = function(param, _)
        return require("spring_boot.util").boot_execute_command(callbackCommandId, param)
      end
      return require("spring_boot.jdtls").execute_command("sts.java.addClasspathListener", { callbackCommandId })
    end,
    ["sts/removeClasspathListener"] = function(_, result)
      local callbackCommandId = result.callbackCommandId
      vim.lsp.commands[callbackCommandId] = nil
      return require("spring_boot.jdtls").execute_command("sts.java.removeClasspathListener", { callbackCommandId })
    end,
  }
  return handlers
end

return M
