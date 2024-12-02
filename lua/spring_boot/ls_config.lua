local util = require("spring_boot.util")

local M = {
  name = "spring-boot",
  filetypes = { "java", "yaml", "jproperties" },
  root_dir = "",
  init_options = {
    workspaceFolders = "",
    enableJdtClasspath = false,
  },
  settings = {
    spring_boot = {},
  },
  handlers = {
    ["sts/highlight"] = function() end,
    ["sts/moveCursor"] = function(err, result, ctx, config)
      -- TODO: move cursor
      return { applied = true }
    end,
  },
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
  capabilities = vim.lsp.protocol.make_client_capabilities(),
}

return M
