-- Internal helper table
local H = {}
---
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

  -- Ensure that repository is cloned in the work directory
  local dir = file.join_path(PLUGIN.path_get('clone'), ctx.tool)
  local url = PLUGIN.url_sanitize(ctx.tool)
  if file.exists(dir) then
    H.check(dir, url, ctx.tool)
  else
    H.clone(dir, url, ctx.tool)
  end

  -- Fetch tags
  H.fetch(dir, ctx.tool)

  -- Return tags as versions
  return { versions = semver.sort(H.list(dir, ctx.tool)) }
end

-- -------------------------------------------------------------------------- --

-- Wrap a given string with single quotes
H.quote = function(val)
  return "'" .. tostring(val) .. "'"
end

-- Clone a repository
H.clone = function(dir, url, tool)
  local cmd = require('cmd')
  local log = require('log')
  local strings = require('strings')

  -- Clone repository in a new directory
  local git_cmd = {
    'git',
    'clone',
    '--tags',
    url,
    H.quote(dir),
  }
  log.info(string.format('Clone: url=%s, dir=%s', H.quote(url), H.quote(dir)))
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
    H.quote(dir),
    'config',
    '--get',
    'remote.origin.url',
  }
  local ok, out = pcall(cmd.exec, strings.join(git_cmd, ' '))
  if not ok then
    error(
      string.format(
        'Failed to get origin remote of %s: %s',
        H.quote(tool),
        tostring(out)
      )
    )
  end
  out = out:gsub('\n$', '')
  if out ~= strings.trim_space(url) then
    error(
      string.format(
        'Incorrect origin remote of %s: %s vs %s',
        H.quote(tool),
        H.quote(out),
        H.quote(url)
      )
    )
  end
end

-- Fetch tags from 'origin' remote
H.fetch = function(dir, tool)
  local cmd = require('cmd')
  local log = require('log')
  local strings = require('strings')

  -- Fetch remote tags
  local git_cmd = {
    'git',
    '-C',
    H.quote(dir),
    'fetch',
    '--prune-tags',
    '--tags',
  }
  log.info(string.format('Fetching tags of %s...', H.quote(tool)))
  local ok, out = pcall(cmd.exec, strings.join(git_cmd, ' '))
  if not ok then
    error(
      string.format(
        'Failed to fetch origin tags of %s: %s',
        H.quote(tool),
        tostring(out)
      )
    )
  end
end

-- List repository tags
H.list = function(dir, tool)
  local cmd = require('cmd')
  local strings = require('strings')

  -- List local tags
  local git_cmd = {
    'git',
    '-C',
    H.quote(dir),
    'tag',
    '--list',
  }
  local ok, out = pcall(cmd.exec, strings.join(git_cmd, ' '))
  if not ok then
    error(
      string.format(
        'Failed to list tags of %s: %s',
        H.quote(tool),
        tostring(out)
      )
    )
  end

  -- Build a list of valid tags
  local tags = {}
  for _, tag in ipairs(strings.split(out, '\n')) do
    if #(strings.trim_space(tag)) > 0 then
      table.insert(tags, tag)
    end
  end

  return tags
end
