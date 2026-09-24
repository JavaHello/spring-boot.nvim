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
---
--- The client has to be initialized for this to stick — at that point
--- `get_spring_boot_client()` finds it.
---@return boolean sent
local function request_classpath_listening()
  local util = require("spring_boot.util")
  local client = util.get_spring_boot_client()
  if not (client and client.initialized) then
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

  if not vim.lsp.is_enabled("spring-boot") then
    if entries == 0 then
      return false, ("no symbol cache at %s"):format(dir)
    end
    local ok, err = pcall(vim.fn.delete, dir, "rf")
    return ok,
      ok and ("removed %d symbol cache files from %s"):format(entries, dir)
        or ("could not delete %s: %s"):format(dir, err)
  end

  local function remove()
    return pcall(vim.fn.delete, dir, "rf")
  end

  -- Stop the client first: a server that is still running answers from the
  -- symbols it read and stores them back, so a cache deleted underneath it
  -- reappears.
  vim.lsp.enable("spring-boot", false)
  -- Let the clients detach before deleting what they may still hold.
  vim.wait(1000, function()
    return #vim.lsp.get_clients({ name = "spring-boot" }) == 0
  end)

  local removed = true
  if entries > 0 then
    removed = remove()
  end

  -- Starts again on the buffers that are open, and waits for it to answer: the
  -- handshake below needs an initialized client, and the cache is dropped a
  -- second time once it is up.
  vim.lsp.enable("spring-boot")
  local started = vim.wait(10000, function()
    local client = require("spring_boot.util").get_spring_boot_client()
    return client ~= nil and client.initialized ~= nil
  end, 100)

  -- The server that was just stopped can still be on its way out and write the
  -- symbols it held back to disc *after* the first deletion. Left there, they
  -- would be exactly the entries this command is meant to drop, and the fresh
  -- server would trust them instead of scanning. Anything written before this
  -- moment is dropped, and nothing is written from here on: the new server
  -- only scans once it is told to listen for the classpath.
  if started and entries > 0 then
    remove()
  end

  local what = entries > 0 and ("removed %d symbol cache files from %s"):format(entries, dir)
    or ("no symbol cache at %s"):format(dir)
  if not removed then
    return false, ("could not delete %s"):format(dir)
  end
  if not started then
    return true, what .. "; the language server did not come back up, reopen a Java or configuration buffer"
  end
  return true,
    what .. (request_classpath_listening() and ", re-indexing" or ", re-open a Java or configuration buffer")
end

return M
