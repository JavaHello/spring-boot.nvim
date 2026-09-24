local M = {}

---@param path? string
---@return string
local function describe(path)
  return path or "not found"
end

M.check = function()
  vim.health.start("spring_boot")

  if vim.fn.has("nvim-0.12") == 1 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Neovim 0.12 or newer is required, found " .. tostring(vim.version()))
  end

  local opts = require("spring_boot.config")
  local spring_boot = require("spring_boot")

  -- The java command the server is launched with.
  local java = opts.java_cmd or require("spring_boot.util").java_bin()
  if vim.fn.executable(java) == 1 then
    vim.health.ok("java: " .. java)
  else
    vim.health.error("java is not executable: " .. java, {
      "Install a JDK, or point `java_cmd` at one in require('spring_boot').setup()",
    })
  end

  -- The language server itself.
  if opts.ls_path then
    if vim.fn.isdirectory(opts.ls_path .. "/BOOT-INF") ~= 0 then
      vim.health.ok("language server (exploded jar): " .. opts.ls_path)
    elseif vim.fn.filereadable(opts.ls_path) == 1 then
      vim.health.ok("language server: " .. opts.ls_path)
    else
      vim.health.error("`ls_path` does not exist: " .. opts.ls_path)
    end
  else
    local mason = spring_boot.get_ls_from_mason()
    local vscode = require("spring_boot.vscode").find_one("/vmware.vscode-spring-boot-*/language-server")
    if not mason and not vscode then
      vim.health.error("Spring Boot LS not found", {
        ":MasonInstall vscode-spring-boot-tools",
        "or install the `vmware.vscode-spring-boot` extension in VS Code",
        "or set `ls_path` in require('spring_boot').setup()",
      })
    else
      vim.health.warn("require('spring_boot').setup() has not run yet", {
        "mason: " .. describe(mason),
        "vscode: " .. describe(vscode),
      })
    end
  end

  if vim.env["MASON"] then
    vim.health.info("$MASON: " .. vim.env["MASON"])
  else
    vim.health.warn("$MASON is not set", {
      "Required to discover the language server through mason-registry",
    })
  end

  -- The jdtls extension jars, which give java sources Spring Boot support.
  local jars = spring_boot.java_extensions()
  if #jars > 0 then
    vim.health.ok(("jdtls extension jars (%d)"):format(#jars))
    for _, jar in ipairs(jars) do
      vim.health.info("  " .. jar)
    end
  else
    vim.health.warn("no jdtls extension jars found", {
      "Java sources get no Spring Boot support without them",
      "See require('spring_boot').java_extensions()",
    })
  end

  -- Why the client may not start here, when a predicate decides that.
  if opts.project_filter then
    -- Evaluated uncached on the current directory, so this answers "why is
    -- nothing happening in this project".
    local root_dir = vim.uv.cwd()
    local ok, verdict = pcall(opts.project_filter, root_dir)
    if not ok then
      vim.health.error("project_filter raised for " .. root_dir, { tostring(verdict) })
    elseif verdict then
      vim.health.ok("project_filter accepts " .. root_dir)
    else
      vim.health.warn("project_filter rejects " .. root_dir, {
        "The client will not start in this workspace",
      })
    end
  else
    vim.health.info("no `project_filter`, every workspace attaches")
  end

  -- Whether the client can and did start.
  if vim.lsp.is_enabled("spring-boot") then
    vim.health.ok("`spring-boot` LSP config is enabled")
  else
    vim.health.warn("`spring-boot` LSP config is not enabled", {
      "require('spring_boot').setup() enables it unless `auto_enable` is false",
      "or call vim.lsp.enable('spring-boot') yourself",
    })
  end

  local clients = vim.lsp.get_clients({ name = "spring-boot" })
  if #clients == 0 then
    vim.health.info("no `spring-boot` client running")
  else
    for _, client in ipairs(clients) do
      vim.health.ok(("client %d: root_dir=%s"):format(client.id, client.config.root_dir or "nil"))
    end
  end
end

return M
