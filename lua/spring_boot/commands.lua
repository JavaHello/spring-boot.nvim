local M = {}

--- The symbol queries the language server understands, in the order they are
--- offered. `@` is every Spring annotation, `@+` bean definitions, `@/`
--- request mappings and `@>` prototypes.
--- see https://github.com/spring-projects/sts4/wiki/Boot-Java-Editor-Support#symbol-search
local SYMBOL_QUERIES = {
  { name = "Annotations", query = "@", description = "shows all Spring annotations in the code" },
  { name = "Beans", query = "@+", description = "shows all defined beans" },
  { name = "RequestMappings", query = "@/", description = "shows all defined request mappings" },
  { name = "Prototype", query = "@>", description = "shows all functions (prototype implementation)" },
}

---@param name string
---@return { name: string, query: string, description: string }?
local function symbol_query(name)
  for _, entry in ipairs(SYMBOL_QUERIES) do
    if entry.name == name then
      return entry
    end
  end
end

---@param choice string
local function find_symbols(choice)
  local entry = symbol_query(choice)
  if not entry then
    local names = vim.tbl_map(function(e)
      return e.name
    end, SYMBOL_QUERIES)
    vim.notify(
      ("spring_boot: unknown symbol query '%s', expected one of %s"):format(choice, table.concat(names, ", ")),
      vim.log.levels.WARN
    )
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  if #vim.lsp.get_clients({ name = "spring-boot", bufnr = buf }) == 0 then
    vim.notify("spring_boot: no Spring Boot language server on this buffer", vim.log.levels.WARN)
    return
  end
  vim.lsp.buf.workspace_symbol(entry.query)
end

local function cache_command(args)
  local dir = require("spring_boot.cache").dir()
  local entries = require("spring_boot.cache").entry_count(dir)
  if entries == 0 then
    vim.notify("spring_boot: no symbol cache at " .. dir, vim.log.levels.INFO)
    return
  end
  if not args.bang then
    local answer = vim.fn.confirm(("Delete %d symbol cache files from %s?"):format(entries, dir), "&Yes\n&No", 2)
    if answer ~= 1 then
      return
    end
  end
  local ok, message = require("spring_boot.cache").clear()
  vim.notify("spring_boot: " .. message, ok and vim.log.levels.INFO or vim.log.levels.WARN)
end

--- Registers the user commands of the plugin. Safe to call more than once.
M.register = function()
  vim.api.nvim_create_user_command("SpringBoot", function(args)
    if args.args ~= "" then
      find_symbols(args.args)
      return
    end
    vim.ui.select(SYMBOL_QUERIES, {
      prompt = "Spring Symbol:",
      format_item = function(entry)
        return ("%s - %s"):format(entry.name, entry.description)
      end,
    }, function(entry)
      if entry then
        find_symbols(entry.name)
      end
    end)
  end, {
    desc = "Find Spring Boot symbols: annotations, beans, request mappings, prototypes",
    nargs = "?",
    complete = function()
      return vim.tbl_map(function(entry)
        return entry.name
      end, SYMBOL_QUERIES)
    end,
  })

  vim.api.nvim_create_user_command("SpringBootClearCache", cache_command, {
    desc = "Delete the language server's symbol cache and index the sources again",
    bang = true,
  })
end

return M
