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

---@param opts bootls.Config
local bootls_path = function(opts)
  if opts.ls_path then
    return opts.ls_path
  end
  local bls = vscode.find_one("/vmware.vscode-spring-boot-*/language-server")
  if bls then
    return bls
  end
end

M.enable_classpath_listening = function()
  util.boot_execute_command("sts.vscode-spring-boot.enableClasspathListening", { true })
end

---@param opts bootls.Config
local logfile = function(opts, rt_dir)
  local lf
  if opts.log_file ~= nil then
    if type(opts.log_file) == "function" then
      lf = opts.log_file(rt_dir)
    elseif type(opts.log_file) == "string" then
      lf = opts.log_file == "" and nil or opts.log_file
    end
  end
  return lf or "/dev/null"
end

---@param opts bootls.Config
local function bootls_cmd(opts, rt_dir, java_cmd)
  local boot_path = bootls_path(opts)
  if not boot_path then
    vim.notify("Spring Boot LS is not installed", vim.log.levels.WARN)
    return
  end
  if opts.exploded_ls_jar_data then
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
      "-Dsts.log.file=" .. logfile(opts, rt_dir),
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
      "-Dsts.log.file=" .. logfile(opts, rt_dir),
      "-jar",
      server_jar[1],
    }
    return cmd
  end
end

M.ls_config = {
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
classpath.register_classpath_service(M.ls_config)
java_data.register_java_data_service(M.ls_config)

vim.lsp.commands["vscode-spring-boot.ls.start"] = function(_, _, _)
  M.enable_classpath_listening()
  return {}
end

M.ls_config.handlers["sts/highlight"] = function() end
M.ls_config.handlers["sts/moveCursor"] = function(err, result, ctx, config)
  -- TODO: move cursor
  return { applied = true }
end
M._update_config = false
M.update_config = function(opts)
  if M._update_config then
    return
  end
  M._update_config = true
  M.ls_config = vim.tbl_deep_extend("keep", M.ls_config, opts.server)
  local capabilities = M.ls_config.capabilities or vim.lsp.protocol.make_client_capabilities()
  capabilities.workspace = {
    executeCommand = { value = true },
  }
  M.ls_config.capabilities = capabilities
  if not M.ls_config.root_dir then
    M.ls_config.root_dir = root_dir()
  end
  M.ls_config.cmd = (M.ls_config.cmd and #M.ls_config.cmd > 0) and M.ls_config.cmd
    or bootls_cmd(opts, M.ls_config.root_dir, opts.java_cmd)
  if not M.ls_config.cmd then
    return
  end
  M.ls_config.init_options.workspaceFolders = M.ls_config.root_dir
  local on_init = M.ls_config.on_init
  M.ls_config.on_init = function(client, ctx)
    util.boot_ls_init(client, ctx)
    if on_init then
      on_init(client, ctx)
    end
  end
end

M.setup = function(_)
  M.update_config(config)
  if vim.g.spring_boot.autocmd then
    local group = vim.api.nvim_create_augroup("spring_boot_ls", { clear = true })
    vim.api.nvim_create_autocmd({ "FileType" }, {
      group = group,
      pattern = { "java", "yaml", "jproperties" },
      desc = "Spring Boot Language Server",
      callback = function(_)
        M.start(M.ls_config)
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
