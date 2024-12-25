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
  local clients = vim.lsp.get_clients({ name = name })
  if clients and #clients > 0 then
    return clients[1]
  end
  vim.notify("Client not found: " .. name, vim.log.levels.ERROR)
  return nil
end

M.get_spring_boot_client = function()
  local clients = vim.lsp.get_clients({ name = "spring-boot" })
  if clients and #clients > 0 then
    return clients[1]
  end
  return nil
end

M._boot_command_co = {}
local function boot_client_execute_command(client, command, param, callback)
  local err, resp = M.execute_command(client, command, param, callback)
  if err then
    print("Error executeCommand: " .. command .. "\n" .. vim.inspect(err))
  end
  return resp
end

M.boot_ls_init = function(_, _)
  for _, co in ipairs(M._boot_command_co) do
    coroutine.resume(co)
  end
  M._boot_command_co = {}
end

M.boot_execute_command = function(command, param, callback)
  local client = M.get_spring_boot_client()
  if client then
    return boot_client_execute_command(client, command, param, callback)
  end
  vim.notify("Spring Boot LS is not ready, waiting for start", vim.log.levels.INFO)
  local pco = coroutine.running()
  local co = coroutine.create(function()
    local resp = boot_client_execute_command(M.get_spring_boot_client(), command, param, callback)
    coroutine.resume(pco, resp)
    return resp
  end)
  table.insert(M._boot_command_co, co)
  return coroutine.yield()
end

M.execute_command = function(client, command, param, callback)
  local co
  if not callback then
    co = coroutine.running()
    if co then
      callback = function(err, resp)
        coroutine.resume(co, err, resp)
      end
    end
  end
  client.request("workspace/executeCommand", {
    command = command,
    arguments = param,
  }, callback, nil)
  if co then
    return coroutine.yield()
  end
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
