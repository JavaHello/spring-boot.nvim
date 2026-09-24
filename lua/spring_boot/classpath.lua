local M = {}

local handlers

--- Handlers for the classpath listener requests the Spring Boot language
--- server sends to the client. Both merely forward the request to jdtls.
---
--- The `callbackCommandId` the server picks is only known at request time, so
--- these callbacks have to be registered on `vim.lsp.commands` rather than
--- declared statically: the eventual `workspace/executeCommand` comes back
--- from jdtls, not from the client these handlers belong to.
---
--- Both answer the server as soon as jdtls has been asked, without waiting for
--- jdtls' answer. The server gives up on a classpath listener after 10s
--- (`INITIALIZE_TIMEOUT` in `JdtLsProjectCache`) and then treats the project as
--- unavailable, which costs every configuration-property diagnostic — no
--- "unknown property" warning, nothing — while the symbol index still fills in
--- from the classpath events arriving later. Since jdtls queues commands behind
--- its project import, waiting here is what pushes past those 10s.
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
      require("spring_boot.jdtls").execute_command_async("sts.java.addClasspathListener", { callbackCommandId })
      return vim.NIL
    end,
    ["sts/removeClasspathListener"] = function(_, result)
      local callbackCommandId = result.callbackCommandId
      vim.lsp.commands[callbackCommandId] = nil
      require("spring_boot.jdtls").execute_command_async("sts.java.removeClasspathListener", { callbackCommandId })
      return vim.NIL
    end,
  }
  return handlers
end

return M
