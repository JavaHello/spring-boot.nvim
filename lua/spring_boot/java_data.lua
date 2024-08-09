local M = {}
local jdtls = require("spring_boot.jdtls")

M.register_java_data_service = function(client)
  client.handlers["textDocument/inlayHint"] = function()end
  client.handlers["sts/javaType"] = function(_, result)
    return jdtls.execute_command("sts.java.type", result)
  end

  client.handlers["sts/javadocHoverLink"] = function(_, result)
    -- fix: https://github.com/spring-projects/sts4/issues/1229
    return jdtls.execute_command("sts.java.javadocHoverLink", result)
  end

  client.handlers["sts/javaLocation"] = function(_, result)
    return jdtls.execute_command("sts.java.location", result)
  end

  client.handlers["sts/javadoc"] = function(_, result)
    return jdtls.execute_command("sts.java.javadoc", result)
  end

  client.handlers["sts/javaSearchTypes"] = function(_, result)
    -- TODO
    print("sts/javaSearchTypes")
    print(vim.inspect(result))
  end

  client.handlers["sts/javaSearchPackages"] = function(_, result)
    -- TODO
    print("sts/javaSearchPackages")
    print(vim.inspect(result))
  end

  client.handlers["sts/javaSubTypes"] = function(_, result)
    return jdtls.execute_command("sts.java.hierarchy.subtypes", result)
  end

  client.handlers["sts/javaSuperTypes"] = function(_, result)
    -- TODO
    print("sts/javaSuperTypes")
    print(vim.inspect(result))
  end

  client.handlers["sts/javaCodeComplete"] = function(_, result)
    return jdtls.execute_command("sts.java.code.completions", result)
  end
end

return M
