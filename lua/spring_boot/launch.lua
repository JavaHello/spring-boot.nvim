local M = {}
local config = require("spring_boot.config")
local vscode = require("spring_boot.vscode")
local classpath = require("spring_boot.classpath")
local java_data = require("spring_boot.java_data")
local util = require("spring_boot.util")

local root_dir = function()
  local ok, jdtls = pcall(require, "jdtls.setup")
  if ok then
    return jdtls.find_root({ ".git", "mvnw", "gradlew" }) or vim.loop.cwd()
  end
  return vim.loop.cwd()
end

local bootls_path = function()
  if config.ls_path then
    return config.ls_path
  end
  local bls = vscode.find_one("/vmware.vscode-spring-boot-*/language-server")
  if bls then
    return bls
  end
end

M.enable_classpath_listening = function()
  util.boot_execute_command("sts.vscode-spring-boot.enableClasspathListening", { true })
end

local logfile = function(rt_dir)
  local lf
  if config.log_file ~= nil then
    if type(config.log_file) == "function" then
      lf = config.log_file(rt_dir)
    elseif type(config.log_file) == "string" then
      lf = config.log_file == "" and nil or config.log_file
    end
  end
  return lf or "/dev/null"
end

local function bootls_cmd(rt_dir, java_cmd)
  local boot_path = bootls_path()
  if not boot_path then
    vim.notify("Spring Boot LS is not installed", vim.log.levels.WARN)
    return
  end
  if config.exploded_ls_jar_data then
    local boot_classpath = {}
    table.insert(boot_classpath, boot_path .. "/BOOT-INF/classes")
    table.insert(boot_classpath, boot_path .. "/BOOT-INF/lib/*")

    local cmd = {
      java_cmd or util.java_bin(),
      "-XX:TieredStopAtLevel=1",
      "-Xmx1G",
      "-XX:+UseZGC",
      "-cp",
      table.concat(boot_classpath, util.is_win and ";" or ":"),
      "-Dsts.lsp.client=vscode",
      "-Dsts.log.file=" .. logfile(rt_dir),
      "-Dspring.config.location=file:" .. boot_path .. "/BOOT-INF/classes/application.properties",
      -- "-Dlogging.level.org.springframework=DEBUG",
      "org.springframework.ide.vscode.boot.app.BootLanguageServerBootApp",
    }
    return cmd
  else
    local server_jar = vim.split(vim.fn.glob(boot_path .. "/spring-boot-language-server*.jar"), "\n")
    if #server_jar == 0 then
      vim.notify("Spring Boot LS jar not found", vim.log.levels.WARN)
      return
    end
    local cmd = {
      java_cmd or util.java_bin(),
      "-XX:TieredStopAtLevel=1",
      "-Xmx1G",
      "-XX:+UseZGC",
      "-Dsts.lsp.client=vscode",
      "-Dsts.log.file=" .. logfile(rt_dir),
      "-jar",
      server_jar[1],
    }
    return cmd
  end
end

local ls_config = {
  name = "spring-boot",
  filetypes = { "java", "yaml", "jproperties" },
  -- root_dir = root_dir,
  init_options = {
    -- workspaceFolders = root_dir,
    enableJdtClasspath = false,
  },
  settings = {
    spring_boot = {},
  },
  handlers = {},
  commands = {},
  get_language_id = function(bufnr, filetype)
    if filetype == "yaml" then
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if util.is_application_yml_file(filename) then
        return "spring-boot-properties-yaml"
      end
    elseif filetype == "jproperties" then
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if util.is_application_properties_file(filename) then
        return "spring-boot-properties"
      end
    end
    return filetype
  end,
}
classpath.register_classpath_service(ls_config)
java_data.register_java_data_service(ls_config)

vim.lsp.commands["vscode-spring-boot.ls.start"] = function(_, _, _)
  M.enable_classpath_listening()
  return {}
end

ls_config.handlers["sts/highlight"] = function() end
ls_config.handlers["sts/moveCursor"] = function(err, result, ctx, config)
  -- TODO: move cursor
  return { applied = true }
end

M.setup = function(_)
  ls_config = vim.tbl_deep_extend("keep", ls_config, config.server)
  local capabilities = ls_config.capabilities or vim.lsp.protocol.make_client_capabilities()
  capabilities.workspace = {
    executeCommand = { value = true },
  }
  ls_config.capabilities = capabilities
  if not ls_config.root_dir then
    ls_config.root_dir = root_dir()
  end
  ls_config.cmd = (ls_config.cmd and #ls_config.cmd > 0) and ls_config.cmd
    or bootls_cmd(ls_config.root_dir, config.java_cmd)
  if not ls_config.cmd then
    return
  end
  ls_config.init_options.workspaceFolders = ls_config.root_dir
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
