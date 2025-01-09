local classpath = require("spring_boot.classpath")
local java_data = require("spring_boot.java_data")
local ls_config = require("spring_boot.ls_config")
local util = require("spring_boot.util")

local M = {}

M.root_dir = function()
  local ok, jdtls = pcall(require, "jdtls.setup")
  if ok then
    return jdtls.find_root({ ".git", "mvnw", "gradlew" }) or vim.loop.cwd()
  end
  return vim.loop.cwd()
end

---@param opts bootls.Config
M.logfile = function(opts, rt_dir)
  local lf = "/dev/null"
  if opts.log_file ~= nil then
    if type(opts.log_file) == "function" then
      lf = opts.log_file(rt_dir)
    elseif type(opts.log_file) == "string" then
      lf = opts.log_file == "" and nil or opts.log_file
    end
  end
  return lf
end

M.bootls_cmd = function(config, rt_dir, java_cmd)
  if not config.ls_path then
    vim.notify("Spring Boot LS is not installed", vim.log.levels.WARN)
    return
  end
  if config.exploded_ls_jar_data then
    local boot_classpath = {}
    table.insert(boot_classpath, config.ls_path .. "/BOOT-INF/classes")
    table.insert(boot_classpath, config.ls_path .. "/BOOT-INF/lib/*")

    return {
      config.java_cmd or java_cmd or util.java_bin(),
      "-XX:TieredStopAtLevel=1",
      "-Xmx1G",
      "-XX:+UseZGC",
      "-cp",
      table.concat(boot_classpath, util.is_win and ";" or ":"),
      "-Dsts.lsp.client=vscode",
      "-Dsts.log.file=" .. M.logfile(config, rt_dir),
      "-Dspring.config.location=file:" .. config.ls_path .. "/BOOT-INF/classes/application.properties",
      -- "-Dlogging.level.org.springframework=DEBUG",
      "org.springframework.ide.vscode.boot.app.BootLanguageServerBootApp",
    }
  else
    return {
      config.java_cmd or java_cmd or util.java_bin(),
      "-XX:TieredStopAtLevel=1",
      "-Xmx1G",
      "-XX:+UseZGC",
      "-Dsts.lsp.client=vscode",
      "-Dsts.log.file=" .. M.logfile(config, rt_dir),
      "-jar",
      config.ls_path,
    }
  end
end

M._update_ls_config = true
M.update_ls_config = function(opts)
  if not M._update_ls_config then
    return {}
  end
  M._update_ls_config = false
  local result = vim.tbl_deep_extend("keep", ls_config, opts.server)
  if not result.root_dir then
    result.root_dir = M.root_dir()
  end
  result.cmd = (result.cmd and #result.cmd > 0) and result.cmd or M.bootls_cmd(opts, result.root_dir, opts.java_cmd)
  if not result.cmd then
    return {}
  end
  result.init_options.workspaceFolders = result.root_dir
  return result
end

M.setup = function(opts)
  local current_ls_config = M.update_ls_config(opts)
  classpath.register_classpath_service(current_ls_config)
  java_data.register_java_data_service(current_ls_config)
  vim.lsp.commands["vscode-spring-boot.ls.start"] = function(_, _, _)
    util.boot_execute_command("sts.vscode-spring-boot.enableClasspathListening", { true })
  end
  if opts.autocmd then
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
