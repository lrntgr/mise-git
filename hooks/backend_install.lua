-- Internal helper table
local H = {}

--- Installs a specific version of a tool
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall
--- @param ctx {tool: string, version: string, install_path: string} Context
--- @return table Empty table on success
function PLUGIN:BackendInstall(ctx)
  local archiver = require('archiver')
  local file = require('file')

  -- Validate context inputs
  if #(ctx.tool or '') <= 0 then
    error('Tool name cannot be empty')
  end
  if #(ctx.version or '') <= 0 then
    error('Version cannot be empty')
  end
  if #(ctx.install_path or '') <= 0 then
    error('Install path cannot be empty')
  end

  -- Ensure install directory
  local clean = (os.getenv('MISE_GIT_CLEAN_INSTALL') == '1')
  if file.exists(ctx.install_path) and clean then
    PLUGIN.dir_remove(ctx.install_path)
  end
  if not file.exists(ctx.install_path) then
    PLUGIN.dir_create(ctx.install_path)
  end

  -- Check if clone directory exists
  local clone_dir = file.join_path(PLUGIN.path_get(), ctx.tool)
  if not file.exists(clone_dir) then
    error(string.format('Missing clone directory: %s', PLUGIN.quote(clone_dir)))
  end

  -- Archive repository at given version
  local archive_file = file.join_path(clone_dir, ctx.version .. '.zip')
  H.archive(clone_dir, ctx.version, archive_file, ctx.tool)

  -- Decompress archive to the install directory
  local err = archiver.decompress(archive_file, ctx.install_path)

  -- Remove the archive file
  os.remove(archive_file)

  -- Check if decompressing succeeded
  if err ~= nil then
    error(string.format('Failed to decompress: %s', err))
  end

  return {}
end

-- -------------------------------------------------------------------------- --

-- Check if version is a (remote) branch
H.version_is_branch = function(dir, version)
  local cmd = require('cmd')
  local strings = require('strings')

  local git_cmd = {
    'git',
    '-C',
    PLUGIN.quote(dir),
    'show-ref',
    '--exists',
    'refs/remotes/origin/' .. version,
  }
  local ok, _ = pcall(cmd.exec, strings.join(git_cmd, ' '))
  return ok
end

-- Archive a repository as a '.zip' file
H.archive = function(dir, version, file, tool)
  local cmd = require('cmd')
  local log = require('log')
  local strings = require('strings')

  if H.version_is_branch(dir, version) then
    version = 'origin/' .. version
  end

  local git_cmd = {
    'git',
    '-C',
    PLUGIN.quote(dir),
    'archive',
    '--format=zip',
    '--output=' .. PLUGIN.quote(file),
    version,
  }

  log.info(string.format('Archiving %s', PLUGIN.quote(tool .. '@' .. version)))
  log.debug(string.format('   |__ file=%s', PLUGIN.quote(file)))
  local ok, out = pcall(cmd.exec, strings.join(git_cmd, ' '))
  if not ok then
    error(string.format('Failed to archive %s: %s', dir, tostring(out)))
  end
end
