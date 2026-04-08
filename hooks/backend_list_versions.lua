-- Internal helper table
local H = {}

--- Lists available versions for a tool in this backend
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions
--- @param ctx {tool: string} Context (tool = the tool name requested)
--- @return {versions: string[]} Table containing list of available versions
function PLUGIN:BackendListVersions(ctx)
  local file = require('file')
  local semver = require('semver')

  -- Validate tool name
  if #(ctx.tool or '') <= 0 then
    error('Tool name cannot be empty')
  end

  -- Remove clone directory if `MISE_GIT_CLEAN_CLONE` is active
  local dir = file.join_path(PLUGIN.path_get('clone'), ctx.tool)
  if file.exists(dir) and (os.getenv('MISE_GIT_CLEAN_CLONE') == '1') then
    PLUGIN.dir_remove(dir)
  end

  -- Ensure that repository is cloned in the work directory
  local url = PLUGIN.url_sanitize(ctx.tool)
  if file.exists(dir) then
    H.check(dir, url, ctx.tool)
  else
    H.clone(dir, url, ctx.tool)
  end

  -- Fetch refs
  H.fetch(dir, ctx.tool)

  -- Return refs as versions
  return { versions = semver.sort(H.list(dir, ctx.tool)) }
end

-- -------------------------------------------------------------------------- --

-- Clone a repository
H.clone = function(dir, url, tool)
  local cmd = require('cmd')
  local log = require('log')
  local strings = require('strings')

  -- Clone repository in a new directory
  local git_cmd = {
    'git',
    'clone',
    url,
    PLUGIN.quote(dir),
  }
  log.info(string.format('Cloning url=%s...', PLUGIN.quote(url)))
  log.info(string.format('   |__ dir=%s', PLUGIN.quote(dir)))
  local ok, out = pcall(cmd.exec, strings.join(git_cmd, ' '))
  if not ok then
    error(string.format('Failed to clone %s: %s', tool, tostring(out)))
  end
end

-- Check if a repository as the correct 'origin' remote URL
H.check = function(dir, url, tool)
  local cmd = require('cmd')
  local strings = require('strings')

  -- Check that directory is a repository with the correct 'origin' remote
  local git_cmd = {
    'git',
    '-C',
    PLUGIN.quote(dir),
    'config',
    '--get',
    'remote.origin.url',
  }
  local ok, out = pcall(cmd.exec, strings.join(git_cmd, ' '))
  if not ok then
    error(
      string.format(
        'Failed to get origin remote of %s: %s',
        PLUGIN.quote(tool),
        tostring(out)
      )
    )
  end
  out = out:gsub('\n$', '')
  if out ~= strings.trim_space(url) then
    error(
      string.format(
        'Incorrect origin remote of %s: %s vs %s',
        PLUGIN.quote(tool),
        PLUGIN.quote(out),
        PLUGIN.quote(url)
      )
    )
  end
end

-- Fetch refs from 'origin' remote
H.fetch = function(dir, tool)
  local cmd = require('cmd')
  local log = require('log')
  local strings = require('strings')

  -- Fetch remote
  local git_cmd = {
    'git',
    '-C',
    PLUGIN.quote(dir),
    'fetch',
    '--prune',
    '--prune-tags',
    '--tags',
  }
  log.info(string.format('Fetching refs of %s...', PLUGIN.quote(tool)))
  local ok, out = pcall(cmd.exec, strings.join(git_cmd, ' '))
  if not ok then
    error(
      string.format(
        'Failed to fetch origin of %s: %s',
        PLUGIN.quote(tool),
        tostring(out)
      )
    )
  end
end

-- List repository refs
H.list = function(dir, tool)
  local cmd = require('cmd')
  local strings = require('strings')

  -- List refs
  local git_cmd = {
    'git',
    '-C',
    PLUGIN.quote(dir),
    'show-ref',
  }
  local ok, out = pcall(cmd.exec, strings.join(git_cmd, ' '))
  if not ok then
    error(
      string.format(
        'Failed to show refs of %s: %s',
        PLUGIN.quote(tool),
        tostring(out)
      )
    )
  end

  -- Build a list of valid refs
  local refs = {}
  for _, ref in ipairs(strings.split(out, '\n')) do
    if #(strings.trim_space(ref)) > 0 then
      local parts = strings.split(ref, ' ')
      local name = parts[2]

      if strings.has_prefix(name, 'refs/remotes/origin/') then
        name = name:gsub('^refs/remotes/origin/', '')
      elseif strings.has_prefix(name, 'refs/tags/') then
        name = name:gsub('^refs/tags/', '')
      else
        name = nil
      end

      if name then
        table.insert(refs, name)
      end
    end
  end

  return refs
end
