local M = {}

--- The directory the language server keeps its symbol cache in — the server's
--- own default, unless the location was moved with
--- `languageserver.boot.symbol-cache-dir`.
---@return string
M.dir = function()
  local from_env = vim.env["LANGUAGESERVER_BOOT_SYMBOL_CACHE_DIR"]
  if from_env and from_env ~= "" then
    return from_env
  end
  for _, arg in ipairs(require("spring_boot.config").jvm_args or {}) do
    local dir = arg:match("^-Dlanguageserver%.boot%.symbol%-cache%-dir=(.+)$")
    if dir then
      return dir
    end
  end
  return vim.fs.joinpath(vim.fn.expand("~"), ".sts4", ".symbolCache")
end

--- Number of files in `dir`, 0 when it does not exist.
---@param dir string
---@return integer
M.entry_count = function(dir)
  local count = 0
  for _ in vim.fs.dir(dir) do
    count = count + 1
  end
  return count
end

--- Tells the server to listen for classpath changes again.
---
--- jdtls announces a Spring Boot project through
--- `vscode-spring-boot.ls.start` only while the set of those projects changes,
--- and restarting this client does not change it. Without this the restarted
--- server never learns about the project's classpath and indexes nothing, so
--- the handshake it is waiting for is repeated here. Asking twice is harmless:
--- the server ignores the command while listening already.
---@return boolean started
local function request_classpath_listening()
  local util = require("spring_boot.util")
  -- The client is started asynchronously and answers the command only once
  -- initialized, which is also when `get_spring_boot_client()` finds it.
  local ready = vim.wait(5000, function()
    local client = util.get_spring_boot_client()
    return client ~= nil and client.initialized ~= nil
  end, 100)
  if not ready then
    return false
  end
  -- A callback, so the send never yields: this runs from a user command.
  util.boot_execute_command("sts.vscode-spring-boot.enableClasspathListening", { true }, function() end)
  return true
end

--- Deletes the symbol cache and makes the client index the sources again.
---
--- The client is stopped before the directory is touched on purpose: a running
--- server answers from the symbols it already read, and stores them back, so a
--- cache deleted underneath it reappears. Starting it again afterwards makes
--- it parse the sources for real — the cache is only trusted while it is
--- complete, and it records only files the server has seen.
---
--- A cache entry holds the files of a project together with the symbols found
--- in them, and is trusted as long as the files keep their modification time.
--- The server cannot tell "this file has no Spring symbols" from "the scan
--- produced nothing", so one bad entry keeps every bean and endpoint of that
--- project out of the index — and with it the configuration-property
--- diagnostics, which need the same project data.
---@return boolean ok
---@return string message
M.clear = function()
  local dir = M.dir()
  local entries = M.entry_count(dir)
  if entries == 0 then
    return false, ("no symbol cache at %s"):format(dir)
  end

  local enabled = vim.lsp.is_enabled("spring-boot")
  if enabled then
    vim.lsp.enable("spring-boot", false)
    -- Let the clients detach before deleting what they may still hold.
    vim.wait(1000, function()
      return #vim.lsp.get_clients({ name = "spring-boot" }) == 0
    end)
  end

  local ok, err = pcall(vim.fn.delete, dir, "rf")

  -- The client is brought back whatever the deletion did: it was stopped to
  -- free the cache, and leaving it stopped would cost more than the files.
  local restarted = true
  if enabled then
    -- Starts on the buffers that are open, so the index is rebuilt right away.
    vim.lsp.enable("spring-boot")
    restarted = request_classpath_listening()
  end

  if not ok then
    return false, ("could not delete %s: %s"):format(dir, err)
  end
  local removed = ("removed %d symbol cache files from %s"):format(entries, dir)
  if not restarted then
    return true, removed .. "; the language server did not come back up, reopen a Java or configuration buffer"
  end
  return true, removed .. ", re-indexing"
end

return M
