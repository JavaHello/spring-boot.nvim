local M = {}

M.Windows = "Windows"
M.Linux = "Linux"
M.Mac = "Mac"

M.os_type = function()
  local has = vim.fn.has
  local t = M.Linux
  if has("win32") == 1 or has("win64") == 1 then
    t = M.Windows
  elseif has("mac") == 1 then
    t = M.Mac
  end
  return t
end

M.is_win = M.os_type() == M.Windows
M.is_linux = M.os_type() == M.Linux
M.is_mac = M.os_type() == M.Mac

M.java_bin = function()
  local java_home = vim.env["JAVA_HOME"]
  if java_home then
    return java_home .. "/bin/java"
  end
  return "java"
end

M.get_client = function(name)
  local clients = vim.lsp.get_active_clients({ name = name })
  if clients and #clients > 0 then
    return clients[1]
  end
  return nil
end

M.get_spring_boot_client = function()
  return M.get_client("spring-boot")
end

M.execute_command = function(command, param, callback)
  local bootls_client = M.get_spring_boot_client()
  if bootls_client == nil then
    vim.notify("spring-boot client not found", vim.log.levels.ERROR)
    return
  end
  local cb = callback
    or function(err, _)
      if err then
        vim.notify("Error executeCommand: " .. command, vim.log.levels.ERROR)
      end
    end
  bootls_client.request("workspace/executeCommand", {
    command = command,
    arguments = param,
  }, cb)
end
M.execute_command_sync = function(command, param)
  local bootls_client = M.get_spring_boot_client()
  if bootls_client == nil then
    vim.notify("spring-boot client not found", vim.log.levels.ERROR)
    return
  end
  return bootls_client.request_sync("workspace/executeCommand", {
    command = command,
    arguments = param,
  })
end

M.is_application_yml_file = function(filename)
  local r = string.match(filename, "application.*%.ya?ml$") or string.match(filename, "bootstrap.*%.ya?ml$")
  return r ~= nil
end

M.is_application_properties_file = function(filename)
  local r = string.match(filename, "application.*%.properties$") or string.match(filename, "bootstrap.*%.properties$")
  return r ~= nil
end

M.is_application_properties_buf = function(bufnr)
  local rfilename = vim.api.nvim_buf_get_name(bufnr)
  return M.is_application_properties_file(rfilename)
end

M.is_application_yml_buf = function(bufnr)
  local rfilename = vim.api.nvim_buf_get_name(bufnr)
  return M.is_application_yml_file(rfilename)
end

return M
