local classpath = require("spring_boot.classpath")
local java_data = require("spring_boot.java_data")
local ls_config = require("spring_boot.ls_config")
local util = require("spring_boot.util")
local uv = vim.uv or vim.loop
local M = {}

M.root_dir = function()
  return vim.fs.root(0, { ".git", "mvnw", "gradlew" }) or uv.cwd()
end

---@param opts bootls.Config
M.logfile = function(opts)
  local lf
  if opts.log_file ~= nil then
    if type(opts.log_file) == "function" then
      lf = opts.log_file(opts.server.root_dir)
    elseif type(opts.log_file) == "string" then
      lf = opts.log_file
    end
  end
  return lf or "/dev/null"
end

M.bootls_cmd = function(config)
  if config.exploded_ls_jar_data then
    local boot_classpath = {}
    table.insert(boot_classpath, config.ls_path .. "/BOOT-INF/classes")
    table.insert(boot_classpath, config.ls_path .. "/BOOT-INF/lib/*")

    return {
      config.java_cmd or util.java_bin(),
      "-XX:TieredStopAtLevel=1",
      "-Xmx1G",
      "-XX:+UseZGC",
      "-cp",
      table.concat(boot_classpath, util.is_win and ";" or ":"),
      "-Dsts.lsp.client=vscode",
      "-Dsts.log.file=" .. M.logfile(config),
      "-Dspring.config.location=file:" .. config.ls_path .. "/BOOT-INF/classes/application.properties",
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

--- 使用 ftplugin 启动时，调用此方法
---@param opts bootls.Config
---@return vim.lsp.ClientConfig
M.update_ls_config = function(opts)
  local client_config = vim.tbl_deep_extend("keep", opts.server, ls_config)
  if not client_config.root_dir then
    client_config.root_dir = M.root_dir()
  end
  if not client_config.cmd or #client_config.cmd == 0 then
    if not opts.ls_path then
      vim.notify("Spring Boot LS is not installed", vim.log.levels.WARN)
      return {}
    end
    client_config.cmd = M.bootls_cmd(opts)
  end
  client_config.init_options.workspaceFolders = client_config.root_dir

  classpath.register_classpath_service(client_config)
  java_data.register_java_data_service(client_config)
  vim.lsp.commands["vscode-spring-boot.ls.start"] = function(_, _, _)
    util.boot_execute_command("sts.vscode-spring-boot.enableClasspathListening", { true })
  end
  return client_config
end

M.ls_autocmd = function(opts)
  local current_ls_config = M.update_ls_config(opts)
  local group = vim.api.nvim_create_augroup("spring_boot_ls", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = group,
    pattern = { "java", "yaml", "jproperties" },
    desc = "Spring Boot Language Server",
    callback = function(_)
      M.start(current_ls_config)
    end,
  })
end

M.start = function(opts)
  local buf = vim.api.nvim_get_current_buf()
  local filename = vim.uri_from_bufnr(buf)
  if vim.endswith(filename, "pom.xml") then
    return
  end
  if vim.endswith(filename, ".yaml") or vim.endswith(filename, ".yml") then
    if not util.is_application_yml_file(filename) then
      return
    end
  end
  if "jproperties" == vim.bo[buf].filetype then
    if not util.is_application_properties_file(filename) then
      return
    end
  end
  vim.lsp.start(opts)
end

-- 参考资料
-- https://github.com/spring-projects/sts4/issues/76
-- https://github.com/spring-projects/sts4/issues/1128
-- https://github.com/emacs-lsp/lsp-java/blob/master/lsp-java-boot.el
return M
