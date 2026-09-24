local M = {}

--- How long to wait for jdtls before answering the server without its result.
--- The server gives up on a classpath listener after `INITIALIZE_TIMEOUT`
--- (10s, in `JdtLsProjectCache`) and from then on treats the project as
--- unavailable, which costs every configuration-property diagnostic — no
--- "unknown property" warning, nothing. jdtls only gets to the forwarded
--- command after its project import, which was measured at 23.7s, so the wait
--- is capped below that deadline: the bare answer is enough for the server,
--- and the listener is registered either way.
local LISTENER_TIMEOUT_MS = 8000

local handlers

--- Handlers for the classpath listener requests the Spring Boot language
--- server sends to the client. Both merely forward the request to jdtls and
--- answer the server with jdtls' result, as the vscode client does.
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
      return require("spring_boot.jdtls").execute_command(
        "sts.java.addClasspathListener",
        { callbackCommandId },
        LISTENER_TIMEOUT_MS
      )
    end,
    ["sts/removeClasspathListener"] = function(_, result)
      local callbackCommandId = result.callbackCommandId
      vim.lsp.commands[callbackCommandId] = nil
      return require("spring_boot.jdtls").execute_command(
        "sts.java.removeClasspathListener",
        { callbackCommandId },
        LISTENER_TIMEOUT_MS
      )
    end,
  }
  return handlers
end

return M
