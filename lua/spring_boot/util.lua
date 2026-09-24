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
    return vim.fn.expand(java_home .. "/bin/java")
  end
  return "java"
end

M.get_client = function(name)
  local clients = vim.lsp.get_clients({ name = name })
  if clients and #clients > 0 then
    return clients[1]
  end
  -- vim.notify("Client not found: " .. name, vim.log.levels.ERROR)
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
  -- client.request deprecated
  client:request("workspace/executeCommand", {
    command = command,
    arguments = param,
  }, callback, nil)
  if co then
    return coroutine.yield()
  end
end

--- Whether `filename` is a Spring Boot yaml configuration file.
--- Matches on the basename so that e.g. a file living under a directory named
--- `application-something/` is not mistaken for configuration.
---@param filename string
---@return boolean
M.is_application_yml_file = function(filename)
  local name = vim.fs.basename(filename)
  return name:match("^application.*%.ya?ml$") ~= nil or name:match("^bootstrap.*%.ya?ml$") ~= nil
end

--- Whether `filename` is a Spring Boot properties configuration file.
---@param filename string
---@return boolean
M.is_application_properties_file = function(filename)
  local name = vim.fs.basename(filename)
  return name:match("^application.*%.properties$") ~= nil or name:match("^bootstrap.*%.properties$") ~= nil
end

--- The `languageId` the language server expects for a buffer. Spring Boot
--- configuration files get their own language ids so that the server treats
--- them as configuration rather than as plain yaml/properties.
---@param bufnr integer
---@param filetype string
---@return string
M.language_id = function(bufnr, filetype)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filetype == "yaml" and M.is_application_yml_file(filename) then
    return "spring-boot-properties-yaml"
  end
  if filetype == "jproperties" and M.is_application_properties_file(filename) then
    return "spring-boot-properties"
  end
  return filetype
end

M.is_application_properties_buf = function(bufnr)
  local rfilename = vim.api.nvim_buf_get_name(bufnr)
  return M.is_application_properties_file(rfilename)
end

M.is_application_yml_buf = function(bufnr)
  local rfilename = vim.api.nvim_buf_get_name(bufnr)
  return M.is_application_yml_file(rfilename)
end

--- Build files that can declare a Spring Boot dependency.
local BUILD_FILES = { "pom.xml", "build.gradle", "build.gradle.kts" }

--- Build output directories, which never hold the project's own build files.
--- Dot directories are skipped by the caller.
local IGNORED_DIRS = {
  ["target"] = true,
  ["build"] = true,
  ["out"] = true,
  ["bin"] = true,
  ["node_modules"] = true,
}

--- How deep submodules are searched, and how many build files are read before
--- giving up. Reading every pom of a large monorepo on each new workspace
--- would be far too slow.
local MAX_DEPTH = 3
local MAX_BUILD_FILES = 50

--- Markers identifying a Spring Boot dependency in a build file. The Maven and
--- Gradle dependency form is `spring-boot-starter-*` /
--- `spring-boot-starter-parent`, while a Gradle build may only apply the
--- plugin, as `id 'org.springframework.boot'` — hence both spellings.
local SPRING_BOOT_MARKERS = { "spring-boot", "springframework.boot" }

---@param path string
---@return boolean
local function mentions_spring_boot(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end
  for _, line in ipairs(lines) do
    for _, marker in ipairs(SPRING_BOOT_MARKERS) do
      if line:find(marker, 1, true) then
        return true
      end
    end
  end
  return false
end

--- Whether `root_dir` looks like a Spring Boot project, judged by its Maven or
--- Gradle build files.
---
--- Submodules are searched too: an aggregator `pom.xml` often only lists
--- `<modules>` while the dependency itself lives in the modules. The search is
--- breadth-first, so the root's own build files are always read first, and it
--- is bounded in both depth and number of files read.
---@param root_dir string
---@return boolean
M.has_spring_boot_dependency = function(root_dir)
  if vim.fn.isdirectory(root_dir) == 0 then
    return false
  end
  local queue = { { dir = root_dir, depth = 0 } }
  local index = 1
  local read = 0
  while index <= #queue and read < MAX_BUILD_FILES do
    local current = queue[index]
    index = index + 1
    for _, name in ipairs(BUILD_FILES) do
      local path = vim.fs.joinpath(current.dir, name)
      if vim.fn.filereadable(path) == 1 then
        read = read + 1
        if mentions_spring_boot(path) then
          return true
        end
      end
    end
    if current.depth < MAX_DEPTH then
      for entry, kind in vim.fs.dir(current.dir) do
        if kind == "directory" and entry:sub(1, 1) ~= "." and not IGNORED_DIRS[entry] then
          queue[#queue + 1] = { dir = vim.fs.joinpath(current.dir, entry), depth = current.depth + 1 }
        end
      end
    end
  end
  return false
end

return M
