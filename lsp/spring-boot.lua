---@brief
---
--- The Spring Boot language server, taken from the
--- [vscode-spring-boot](https://marketplace.visualstudio.com/items?itemName=vmware.vscode-spring-boot)
--- extension.
---
--- Configure it with |spring_boot.setup()|, which also enables it unless
--- `auto_enable` is false, or enable it yourself with: >lua
---   vim.lsp.enable("spring-boot")
--- <
--- Any field can be overridden from `after/lsp/spring-boot.lua`.
---
--- NOTE: `vim.lsp.config` loads this file with `loadfile()`, possibly before
--- the plugin is on the runtimepath. It therefore must not `require()`
--- anything at load time — every `require` below lives inside the function
--- that needs it.

--- Binds a handler provided by `lua/spring_boot/<mod>.lua` lazily, so that
--- loading this file never loads the plugin.
---@param mod string
---@param method string
---@return lsp.Handler
local function handler(mod, method)
  return function(err, result, ctx, config)
    return require("spring_boot." .. mod).handlers()[method](err, result, ctx, config)
  end
end

---@type vim.lsp.Config
return {
  -- The client name is part of the public interface, keep it "spring-boot".
  filetypes = { "java", "yaml", "jproperties" },

  -- Only the delta: the client deep-merges this over
  -- |vim.lsp.protocol.make_client_capabilities()|.
  capabilities = {
    workspace = {
      executeCommand = { value = true },
    },
  },

  init_options = {
    enableJdtClasspath = false,
  },

  settings = {},

  -- Gating lives here, not in `filetypes`: the server only applies to
  -- application.yml / application.properties (and to java files).
  root_dir = function(bufnr, on_dir)
    require("spring_boot.launch").root_dir(bufnr, on_dir)
  end,

  -- A function, so the server is resolved when one actually starts, and so
  -- that overriding `cmd` replaces it wholesale instead of merging into it.
  cmd = function(dispatchers, config)
    local opts = require("spring_boot.config")
    local cmd = require("spring_boot.launch").bootls_cmd(opts, config.root_dir)
    if not cmd then
      -- Returning nil would fail later with an unhelpful "attempt to index a
      -- nil value (local 'rpc')"; raising surfaces a warning instead.
      error("Spring Boot LS is not installed. Run :checkhealth spring_boot")
    end
    return vim.lsp.rpc.start(cmd, dispatchers)
  end,

  -- The workspace folder is only known per buffer, so it cannot be declared
  -- statically in `init_options`.
  before_init = function(params, config)
    if type(params.initializationOptions) ~= "table" then
      params.initializationOptions = {}
    end
    params.initializationOptions.workspaceFolders = config.root_dir
  end,

  get_language_id = function(bufnr, filetype)
    return require("spring_boot.util").language_id(bufnr, filetype)
  end,

  on_init = function(client, init_result)
    require("spring_boot.util").boot_ls_init(client, init_result)
  end,

  handlers = {
    -- The server asking the editor to run a command, e.g. to enable classpath
    -- listening. Handled on this client, so no global handler is needed.
    ["workspace/executeClientCommand"] = function(err, result, ctx, config)
      return require("spring_boot").execute_client_command(err, result, ctx, config)
    end,
    ["sts/highlight"] = function() end,
    ["sts/moveCursor"] = function()
      -- TODO: move cursor
      return { applied = true }
    end,
    ["sts/addClasspathListener"] = handler("classpath", "sts/addClasspathListener"),
    ["sts/removeClasspathListener"] = handler("classpath", "sts/removeClasspathListener"),
    ["sts/javaType"] = handler("java_data", "sts/javaType"),
    ["sts/javadocHoverLink"] = handler("java_data", "sts/javadocHoverLink"),
    ["sts/javaLocation"] = handler("java_data", "sts/javaLocation"),
    ["sts/javadoc"] = handler("java_data", "sts/javadoc"),
    ["sts/javaSearchTypes"] = handler("java_data", "sts/javaSearchTypes"),
    ["sts/javaSearchPackages"] = handler("java_data", "sts/javaSearchPackages"),
    ["sts/javaSubTypes"] = handler("java_data", "sts/javaSubTypes"),
    ["sts/javaSuperTypes"] = handler("java_data", "sts/javaSuperTypes"),
    ["sts/javaCodeComplete"] = handler("java_data", "sts/javaCodeComplete"),
    ["sts/project/gav"] = handler("java_data", "sts/project/gav"),
  },

  commands = {
    ["vscode-spring-boot.ls.start"] = function()
      require("spring_boot.util").boot_execute_command("sts.vscode-spring-boot.enableClasspathListening", { true })
    end,
  },
}
