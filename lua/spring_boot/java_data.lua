local M = {}

local handlers

--- Requests the Spring Boot language server sends to the client, and the jdtls
--- command that answers each of them.
---
--- `sts/javadocHoverLink` exists to work around
--- https://github.com/spring-projects/sts4/issues/1229
local commands = {
  ["sts/javaType"] = "sts.java.type",
  ["sts/javadocHoverLink"] = "sts.java.javadocHoverLink",
  ["sts/javaLocation"] = "sts.java.location",
  ["sts/javadoc"] = "sts.java.javadoc",
  ["sts/javaSearchTypes"] = "sts.java.search.types",
  ["sts/javaSearchPackages"] = "sts.java.search.packages",
  ["sts/javaSubTypes"] = "sts.java.hierarchy.subtypes",
  ["sts/javaSuperTypes"] = "sts.java.hierarchy.supertypes",
  ["sts/javaCodeComplete"] = "sts.java.code.completions",
  ["sts/project/gav"] = "sts.project.gav",
}

--- Every request carries the arguments jdtls needs, so they all reduce to a
--- single `workspace/executeCommand` on the jdtls client.
---@return table<string, lsp.Handler>
M.handlers = function()
  if handlers then
    return handlers
  end
  handlers = {}
  for method, command in pairs(commands) do
    handlers[method] = function(_, result)
      return require("spring_boot.jdtls").execute_command(command, result)
    end
  end
  return handlers
end

return M
