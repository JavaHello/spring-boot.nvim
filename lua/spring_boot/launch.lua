local util = require("spring_boot.util")
local uv = vim.uv

local M = {}

--- Markers used to find the workspace root, in decreasing priority.
M.root_markers = { ".git", "mvnw", "gradlew" }

--- Resolves the log file, letting the user derive it from the workspace root.
---@param opts bootls.Config
---@param root_dir? string
---@return string
M.logfile = function(opts, root_dir)
  local log_file = opts.log_file
  if type(log_file) == "function" then
    return log_file(root_dir)
  elseif type(log_file) == "string" then
    return log_file
  end
  return util.is_win and "NUL" or "/dev/null"
end

--- An exploded jar is a directory containing `BOOT-INF/`.
---@param ls_path string
---@return boolean
M.is_exploded = function(ls_path)
  return vim.fn.isdirectory(ls_path .. "/BOOT-INF") ~= 0
end

--- Builds the language server command line, or nil when no server was found.
---@param opts bootls.Config
---@param root_dir? string
---@return string[]|nil
M.bootls_cmd = function(opts, root_dir)
  local ls_path = opts.ls_path
  if not ls_path then
    return nil
  end

  local log_file = M.logfile(opts, root_dir)
  local cmd = vim.list_extend({
    opts.java_cmd or util.java_bin(),
    "-XX:TieredStopAtLevel=1",
    "-Xmx1G",
    "-XX:+UseZGC",
  }, opts.jvm_args or {})

  vim.list_extend(cmd, {
    "-Dsts.lsp.client=vscode",
    "-Dsts.log.file=" .. log_file,
  })

  if M.is_exploded(ls_path) then
    vim.list_extend(cmd, {
      "-cp",
      table.concat({
        ls_path .. "/BOOT-INF/classes",
        ls_path .. "/BOOT-INF/lib/*",
      }, util.is_win and ";" or ":"),
      "-Dspring.config.location=file:" .. ls_path .. "/BOOT-INF/classes/application.properties",
      "org.springframework.ide.vscode.boot.app.BootLanguageServerBootApp",
    })
  else
    vim.list_extend(cmd, {
      -- Fix appearance of LOG-FILE-UNDEFINED files
      -- https://github.com/spring-projects/spring-tools/commit/522acf1fa7fc074cbd24ffece25f3368ba5ebe4d
      "-Dspring.profiles.active=file-logging",
      "-Dlogging.file.name=" .. log_file,
      "-Dlogging.level.root=" .. (opts.log_level or "warn"),
      "-jar",
      ls_path,
    })
  end
  return cmd
end

--- Verdicts of `project_filter`, keyed by the predicate and then by workspace
--- root. `root_dir()` runs on every FileType event and the predicate may read
--- build files, so each workspace is judged once. The weak keys mean a
--- predicate that is no longer referenced takes its verdicts with it.
local filter_cache ---@type table<function, table<string, boolean>>

--- Drops every memoized `project_filter` verdict, so workspaces are judged
--- again on the next FileType event.
M.clear_project_filter_cache = function()
  filter_cache = setmetatable({}, { __mode = "k" })
end
M.clear_project_filter_cache()

---@param opts bootls.Config
---@param root_dir string
---@return boolean
local function passes_project_filter(opts, root_dir)
  local filter = opts.project_filter
  if not filter then
    return true
  end
  local verdicts = filter_cache[filter]
  if not verdicts then
    verdicts = {}
    filter_cache[filter] = verdicts
  end
  if verdicts[root_dir] == nil then
    local ok, result = pcall(filter, root_dir)
    if not ok then
      -- Fail open: a broken predicate should not silently disable the server.
      vim.notify("spring_boot: project_filter failed: " .. tostring(result), vim.log.levels.WARN)
      verdicts[root_dir] = true
    else
      verdicts[root_dir] = result and true or false
    end
  end
  return verdicts[root_dir]
end

--- Decides whether the language server should attach to `bufnr`, and to which
--- workspace root.
---
--- This doubles as a gate: `on_dir` is deliberately never called for yaml or
--- properties files that are not Spring Boot configuration, nor when no
--- language server could be found, nor for a workspace rejected by
--- `project_filter`. See |lsp-root_dir()|.
---@param bufnr integer
---@param on_dir fun(root_dir?: string)
M.root_dir = function(bufnr, on_dir)
  local opts = require("spring_boot.config")
  if not opts.ls_path then
    return
  end
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype
  if filetype == "yaml" and not util.is_application_yml_file(filename) then
    return
  end
  if filetype == "jproperties" and not util.is_application_properties_file(filename) then
    return
  end
  local root_dir = vim.fs.root(bufnr, M.root_markers) or uv.cwd()
  if not passes_project_filter(opts, root_dir) then
    return
  end
  on_dir(root_dir)
end

-- 参考资料
-- https://github.com/spring-projects/sts4/issues/76
-- https://github.com/spring-projects/sts4/issues/1128
-- https://github.com/emacs-lsp/lsp-java/blob/master/lsp-java-boot.el
return M
