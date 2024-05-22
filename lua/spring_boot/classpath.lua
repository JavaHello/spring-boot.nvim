local M = {}
M.register_classpath_service = function(client)
  client.handlers["sts/addClasspathListener"] = function(_, result)
    local callbackCommandId = result.callbackCommandId
    vim.lsp.commands[callbackCommandId] = function(param, _)
      return require("spring_boot.util").boot_execute_command(callbackCommandId, param)
    end
    return require("spring_boot.jdtls").execute_command("sts.java.addClasspathListener", { callbackCommandId })
  end
  client.handlers["sts/removeClasspathListener"] = function(_, result)
    local callbackCommandId = result.callbackCommandId
    vim.lsp.commands[callbackCommandId] = nil
    return require("spring_boot.jdtls").execute_command("sts.java.removeClasspathListener", { callbackCommandId })
  end
end
return M
