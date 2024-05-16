local M = {}
local config = require("spring_boot.config")
local vscode = require("spring_boot.vscode")
local classpath = require("spring_boot.classpath")
local java_data = require("spring_boot.java_data")
local util = require("spring_boot.util")

local root_dir = function()
  return require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew" }) or vim.loop.cwd()
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

M.jdt_extensions_jars = function()
  local bundles = {}
  local function bundle_jar(path)
    for _, jar in ipairs(config.jdt_extensions_jars) do
      if vim.endswith(path, jar) then
        return true
      end
    end
  end
  local spring_boot_path = config.jdt_extensions_path or vscode.find_one("/vmware.vscode-spring-boot-*/jars")
  if spring_boot_path then
    for _, bundle in ipairs(vim.split(vim.fn.glob(spring_boot_path .. "/*.jar"), "\n")) do
      if bundle_jar(bundle) then
        table.insert(bundles, bundle)
      end
    end
  end
  return bundles
end

M.enable_classpath_listening = function()
  util.execute_command("sts.vscode-spring-boot.enableClasspathListening", { true })
end

local logfile = function(rt_dir)
  if config.log_file ~= nil then
    return config.log_file(rt_dir)
  end
  return "/dev/null"
end

local function bootls_cmd(rt_dir)
  local boot_path = bootls_path()
  if not boot_path then
    vim.notify("Spring Boot LS is not installed", vim.log.levels.WARN)
    return
  end
  local boot_classpath = {}
  table.insert(boot_classpath, boot_path .. "/BOOT-INF/classes")
  table.insert(boot_classpath, boot_path .. "/BOOT-INF/lib/*")

  local cmd = {
    util.java_bin(),
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
end

local ls_config = {
  -- cmd = bootls_cmd(),
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

M.setup = function(opts)
  config = opts
  local capabilities = config.server.capabilities or vim.lsp.protocol.make_client_capabilities()
  capabilities.workspace = {
    executeCommand = { value = true },
  }
  ls_config.capabilities = capabilities
  local rt_dir = config.server.root_dir or root_dir()
  ls_config.cmd = config.server.cmd or bootls_cmd(rt_dir)
  if not ls_config.cmd then
    return
  end
  ls_config.root_dir = rt_dir
  ls_config.init_options.workspaceFolders = rt_dir
  if config.server.on_attach then
    ls_config.on_attach = config.server.on_attach
  end
  if config.server.on_init then
    ls_config.on_init = config.server.on_init
  end
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
      vim.lsp.start(ls_config)
    end,
  })
end

-- 参考资料
-- https://github.com/spring-projects/sts4/issues/76
-- https://github.com/spring-projects/sts4/issues/1128
-- https://github.com/emacs-lsp/lsp-java/blob/master/lsp-java-boot.el
return M
