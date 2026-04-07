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
