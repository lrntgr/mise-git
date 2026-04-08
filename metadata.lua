-- metadata.lua
-- Backend plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html

PLUGIN = { -- luacheck: ignore
  name = 'git',
  version = '0.0.1',
  description = 'A mise backend plugin for git hosted tools',
  author = 'lrntgr',
  homepage = 'https://github.com/lrntgr/mise-git',
  license = 'MIT',
  notes = {
    'Requires `git` to be installed on your system',
  },
}

-- -------------------------------------------------------------------------- --

--- Get the path to 'mise-git' work directory
--- @param dir string|nil Targeted sub-directory
--- @return string|nil path Absolute path of 'mise-git' work directory
PLUGIN.path_get = function(dir)
  local log = require('log')
  local file = require('file')

  -- Use 'MISE_GIT_WORKDIR' environment variable
  local base_dir = os.getenv('MISE_GIT_WORKDIR')

  if not base_dir then
    -- Use 'MISE_DATA_DIR' environment variable
    base_dir = os.getenv('MISE_DATA_DIR')
    base_dir = base_dir and file.join_path(base_dir, 'git')
  end

  if not base_dir then
    -- Use 'XDG_DATA_HOME' environment variable
    base_dir = os.getenv('XDG_DATA_HOME')
    base_dir = base_dir and file.join_path(base_dir, 'mise', 'git')
  end

  if not base_dir then
    local is_win = (package.config:sub(1, 1) == '\\')
    if is_win then
      -- On Windows, use 'LOCALAPPDATA' or 'APPDATA' environment variables
      base_dir = os.getenv('LOCALAPPDATA') or os.getenv('APPDATA')
      if not base_dir then
        error("Missing '%LOCALAPPDATA%' or '%APPDATA' variables")
      end
      base_dir = file.join_path(base_dir, 'mise', 'git')
    else
      -- On Unix, use 'HOME' environment variable
      base_dir = os.getenv('HOME')
      if not base_dir then
        error("Missing 'HOME' variable")
      end
      base_dir = file.join_path(base_dir, '.local', 'share', 'mise', 'git')
    end
  end
  log.debug(string.format("Base directory: '%s'", base_dir))

  local dirs = {
    clone = '.clone',
    archive = '.archive',
  }
  return dirs[dir] and file.join_path(base_dir, dirs[dir]) or base_dir
end

--- Sanitize a given (git) URL
--- @param url string URL to sanitize
--- @return string url Sanitized URL (ie. `git clone` ready)
PLUGIN.url_sanitize = function(url)
  local strings = require('strings')

  if strings.has_prefix(url, 'https|') then
    url = url:gsub('^https|', 'https://')
  elseif strings.has_prefix(url, 'git|') then
    url = url:gsub('^git|', 'git@')
  end
  url = url:gsub('%^', '@')
  url = url:gsub(';', ':')

  return url
end

--- Wrap a given string with single quotes
--- @param val string Value to quote
--- @return string quoted Quoted string
PLUGIN.quote = function(val)
  return "'" .. tostring(val) .. "'"
end

--- Remove/delete an existing directory
--- @param dir string Directory path
PLUGIN.dir_remove = function(dir)
  local cmd = require('cmd')
  local log = require('log')
  local strings = require('strings')

  dir = PLUGIN.quote(dir)
  local is_win = (package.config:sub(1, 1) == '\\')
  local rm_cmd = is_win and { 'rd', '/s/q', dir } or { 'rm', '-rd', dir }

  log.info(string.format('Removing %s', dir))
  local ok, _ = pcall(cmd.exec, strings.join(rm_cmd, ' '))
  if not ok then
    error(string.format('Failed to remove %s', dir))
  end
end
