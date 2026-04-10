# mise-git (backend plugin)

`mise-git` is a backend plugin for [`mise`](https://mise.jdx.dev/) allowing to
install tools hosted as Git repositories.

## Why ?

To install tools that:
- are hosted on GitHub/GitLab/Forgejo, but with no release assets
- are hosted on custom servers (_eg. Gitea, Bitbucket, a raw SSH server_)
- do not distribute executables, but require building from sources

## Behavior

This backend plugin operates in a `${MISE_GIT_WORKDIR}` working directory.  
It basically:
- runs`git clone` to clone tool repositories in `${MISE_GIT_WORKDIR}/.clone/`
- runs `git fetch` on cloned repositories, to retrieve tags and remote branches
- runs `git show-ref` on cloned repositories, to list available versions
- runs `git archive` on cloned repositories, to store content in `${MISE_GIT_WORKDIR}/.archive/`
- decompress archives in `${MISE_GIT_WORKDIR}/.archive/` to the install path

> [!WARNING]
> As mise format uses `:` and `@` as special characters, `git` URL must be adapted:
> - use `https|` instead of `https://`
> - use `git|` instead of `git@`
> - for the rest:
>     - use `^` instead of `@`
>     - use `;` instead of `:`

## Usage

```console
$ # Configure 'mise' to use this custom backend
$ mise settings experimental=true
$ mise plugin add --force git https://github.com/lrntgr/mise-git.git
$ mise plugin ls --user --urls
Plugin  Url                                     Ref  Sha
git     https://github.com/lrntgr/mise-git.git  HEAD xxxxxxx

$ # Install its own repository, with version being the 'main' branch
$ mise use 'git:https|github.com/lrntgr/mise-git.git@main'
$ mise exec -- mise-git-test.sh --test && echo "OK"
>>> Test of 'mist-git' backend <<<
OK

$ # Install 'bonsai.sh' from GitLab, on its 'HEAD' version
$ mise use 'git:https|gitlab.com/jallbrit/bonsai.sh@HEAD'
$ mise exec -- bonsai.sh -s 123 -g 35,20
     &    &    && & /
      & &&&&     /|/|
   &&&&&&&&&&&&_\/~/
        &\&_&&  &//~
                 /        &
                /   &  &&  &  &
               /| & &&&&&& &&
     &&        /\&/& & &&_/&&
  &&&&&&  &   \\\ &/&/\_/_/ &&
 &&&&__&  &_&& /|    _/
&&&&_& \__\_\_ /~
                 /|
                 /|
                 /|
                 \
   :___________./~~\.___________:
    \                          /
     \________________________/
     (_)                    (_)

$ # Use 'postinstall' hook to build 'cmatrix' from sources
$ cat >> mise.toml << 'EOF'
[tools."git:https|github.com/abishekvashok/cmatrix"]
version = "v2.0"
postinstall = '''
#!/usr/bin/bash
set -e
unset MISE_TOOL_VERSION
export DIR=${MISE_TOOL_INSTALL_PATH}

mise -C ${DIR} use cmake@3.20
mise -C ${DIR} exec -- cmake -S ${DIR} -B ${DIR}/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${DIR}
mise -C ${DIR} exec -- cmake --build ${DIR}/build
mise -C ${DIR} exec -- cmake --install ${DIR}/build
'''
EOF
$ mise exec -- cmatrix -s
$ # Enjoy the matrix, press any key to end
```

## Documentation

- [Backend Plugin Development](https://mise.jdx.dev/backend-plugin-development.html) - Complete guide
- [Backend Architecture](https://mise.jdx.dev/dev-tools/backend_architecture.html) - How backends work
- [Lua modules reference](https://mise.jdx.dev/plugin-lua-modules.html) - Available modules

## License

MIT
