local M = {}

--- How long to wait for jdtls before answering the server without its result.
--- The server gives up on a classpath listener after `INITIALIZE_TIMEOUT`
--- (10s, in `JdtLsProjectCache`) and from then on treats the project as
--- unavailable, which costs every configuration-property diagnostic — no
--- "unknown property" warning, nothing. jdtls only gets to the forwarded
--- command after its project import, which was measured at 23.7s, so the wait
--- is capped below that deadline: the bare answer is enough for the server,
--- and the listener is registered either way.
local LISTENER_TIMEOUT_MS = 8000

--- How long the classpath events have to stay quiet before the settings are
--- sent, and how many bursts per client are answered with a settings push.
local SETTLE_MS = 1500
local MAX_PUSHES = 2

--- Per client: the number of the last classpath event seen, and how many
--- times the settings have been sent for it.
local bursts = {} ---@type table<integer, { generation: integer, count: integer }>

--- Sends the settings once a burst of classpath events has gone quiet.
---
--- The settings sent at initialization reach a server that knows no projects
--- yet, so nothing gets indexed from that call. With the projects present the
--- notification instead makes the server index them from source
--- (`SpringSymbolIndex.configurationChanged` → `initializeProject(project,
--- clean = true)`), which is what repairs a cache entry claiming a project
--- holds no symbols. See |spring_boot.settings|.
---
--- That makes the timing matter: the server registers one project per event,
--- and a project it registers *after* the notification is indexed from its
--- cache entry instead — a bad entry then keeps that project empty for good.
--- Waiting for the quiet puts the notification after the last project of a
--- burst; the wait is re-armed by every event, so a staggered burst is covered
--- as well. The budget keeps later bursts (a changed `pom.xml`, say) from
--- re-indexing every project again — those carry new cache keys anyway, so
--- their sources are parsed regardless.
local function push_settings_when_settled()
  local util = require("spring_boot.util")
  local client = util.get_spring_boot_client()
  if not client then
    return
  end
  local burst = bursts[client.id]
  if not burst then
    burst = { generation = 0, count = 0 }
    bursts[client.id] = burst
  end
  if burst.count >= MAX_PUSHES then
    return
  end
  burst.generation = burst.generation + 1
  local generation = burst.generation
  vim.defer_fn(function()
    local current = bursts[client.id]
    if not current or current.generation ~= generation or client:is_stopped() then
      -- Another event is still waiting for its own quiet, or the client is gone.
      return
    end
    current.count = current.count + 1
    require("spring_boot.settings").push(client)
  end, SETTLE_MS)
end

local handlers

--- Handlers for the classpath listener requests the Spring Boot language
--- server sends to the client. Both merely forward the request to jdtls and
--- answer the server with jdtls' result, as the vscode client does.
---
--- The `callbackCommandId` the server picks is only known at request time, so
--- these callbacks have to be registered on `vim.lsp.commands` rather than
--- declared statically: the eventual `workspace/executeCommand` comes back
--- from jdtls, not from the client these handlers belong to.
---@return table<string, lsp.Handler>
M.handlers = function()
  if handlers then
    return handlers
  end
  handlers = {
    ["sts/addClasspathListener"] = function(_, result)
      local callbackCommandId = result.callbackCommandId
      vim.lsp.commands[callbackCommandId] = function(param, _)
        local forwarded = require("spring_boot.util").boot_execute_command(callbackCommandId, param)
        push_settings_when_settled()
        return forwarded
      end
      return require("spring_boot.jdtls").execute_command(
        "sts.java.addClasspathListener",
        { callbackCommandId },
        LISTENER_TIMEOUT_MS
      )
    end,
    ["sts/removeClasspathListener"] = function(_, result)
      local callbackCommandId = result.callbackCommandId
      vim.lsp.commands[callbackCommandId] = nil
      return require("spring_boot.jdtls").execute_command(
        "sts.java.removeClasspathListener",
        { callbackCommandId },
        LISTENER_TIMEOUT_MS
      )
    end,
  }
  return handlers
end

return M
