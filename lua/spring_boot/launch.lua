local classpath = require("spring_boot.classpath")
local java_data = require("spring_boot.java_data")
local util = require("spring_boot.util")

local M = {}

M.root_dir = function()
  local ok, jdtls = pcall(require, "jdtls.setup")
  if ok then
    return jdtls.find_root({ ".git", "mvnw", "gradlew" }) or vim.loop.cwd()
  end
  return vim.loop.cwd()
end

M.enable_classpath_listening = function()
  util.boot_execute_command("sts.vscode-spring-boot.enableClasspathListening", { true })
end

M.logfile = function(config)
  local lf = "/dev/null"
  if config.log_file ~= nil then
    if type(config.log_file) == "function" then
      lf = config.log_file(config.root_dir)
    elseif type(config.log_file) == "string" then
      lf = config.log_file == "" and nil or config.log_file
    end
  end
  return lf
end

M.bootls_cmd = function(config)
  local boot_path = config.root_dir
  if config.exploded_ls_jar_data then
    local boot_classpath = {}
    table.insert(boot_classpath, boot_path .. "/BOOT-INF/classes")
    table.insert(boot_classpath, boot_path .. "/BOOT-INF/lib/*")

    return {
      config.java_cmd or util.java_bin(),
      "-XX:TieredStopAtLevel=1",
      "-Xmx1G",
      "-XX:+UseZGC",
      "-cp",
      table.concat(boot_classpath, util.is_win and ";" or ":"),
      "-Dsts.lsp.client=vscode",
      "-Dsts.log.file=" .. M.logfile(config),
      "-Dspring.config.location=file:" .. boot_path .. "/BOOT-INF/classes/application.properties",
      -- "-Dlogging.level.org.springframework=DEBUG",
      "org.springframework.ide.vscode.boot.app.BootLanguageServerBootApp",
    }
  else
    return {
      config.java_cmd or util.java_bin(),
      "-XX:TieredStopAtLevel=1",
      "-Xmx1G",
      "-XX:+UseZGC",
      "-Dsts.lsp.client=vscode",
      "-Dsts.log.file=" .. M.logfile(config),
      "-jar",
      config.ls_path,
    }
  end
end

vim.lsp.commands["vscode-spring-boot.ls.start"] = function(_, _, _)
  M.enable_classpath_listening()
  return {}
end

M.setup = function(opts)
  local ls_config = vim.tbl_deep_extend("keep", require("spring_boot.ls_config"), opts.server)
  ls_config.root_dir = opts.root_dir or M.root_dir()
  classpath.register_classpath_service(ls_config)
  java_data.register_java_data_service(ls_config)
  ls_config.capabilities.workspace = {
    executeCommand = { value = true },
  }
  ls_config.cmd = M.bootls_cmd(opts)
  if not ls_config.cmd then
    return
  end
  ls_config.init_options.workspaceFolders = opts.root_dir
  local group = vim.api.nvim_create_augroup("spring_boot_ls", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = group,
    pattern = { "java", "yaml", "jproperties" },
    desc = "Spring Boot Language Server",
    callback = function(e)
      if e.file == "java" and vim.bo[e.buf].buftype == "nofile" then
        return
      end
      if vim.endswith(e.file, "pom.xml") then
        return
      end
      if vim.endswith(e.file, ".yaml") or vim.endswith(e.file, ".yml") then
        if not util.is_application_yml_file(e.file) then
          return
        end
      end
      vim.lsp.start(ls_config)
    end,
  })
end

-- 参考资料
-- https://github.com/spring-projects/sts4/issues/76
-- https://github.com/spring-projects/sts4/issues/1128
-- https://github.com/emacs-lsp/lsp-java/blob/master/lsp-java-boot.el
return M
