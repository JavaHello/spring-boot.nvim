local M = {}
local jdtls = require("spring_boot.jdtls")

M.register_java_data_service = function(client)
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
    return jdtls.execute_command("sts.java.search.types", result)
  end

  client.handlers["sts/javaSearchPackages"] = function(_, result)
    return jdtls.execute_command("sts.java.search.packages", result)
  end

  client.handlers["sts/javaSubTypes"] = function(_, result)
    return jdtls.execute_command("sts.java.hierarchy.subtypes", result)
  end

  client.handlers["sts/javaSuperTypes"] = function(_, result)
    return jdtls.execute_command("sts.java.hierarchy.supertypes", result)
  end

  client.handlers["sts/javaCodeComplete"] = function(_, result)
    return jdtls.execute_command("sts.java.code.completions", result)
  end

  client.handlers["sts/project/gav"] = function(_, result)
    return jdtls.execute_command("sts.project.gav", result)
  end
end

return M
