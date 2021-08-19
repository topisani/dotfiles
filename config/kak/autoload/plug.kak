provide-module plug %{
  # Internal variables
  # Modules
  declare-option -docstring 'plug list of modules' str-list plug_modules
  declare-option -docstring 'plug list of module name and repository pairs' str-list plug_module_to_repository_map

  # Paths
  declare-option -hidden -docstring 'plug XDG_DATA_HOME path' str plug_xdg_data_home_path %sh(echo "${XDG_DATA_HOME:-$HOME/.local/share}")

  declare-option -docstring 'plug kakrc path' str plug_kakrc_path "%val{config}/kakrc"
  declare-option -docstring 'plug core path' str plug_core_path "%val{runtime}/autoload"
  declare-option -docstring 'plug autoload path' str plug_autoload_path "%val{config}/autoload/plugins"
  declare-option -docstring 'plug install path' str plug_install_path "%opt{plug_xdg_data_home_path}/kak/plug/plugins"

  # Hooks
  hook -group plug-kak-begin global KakBegin .* %{
    plug-require-modules
  }

  # Filetype detection
  hook -group plug-detect global BufOpenFifo '\Q*plug*' %{
    set-option buffer filetype plug
  }

  hook -group plug-filetype global WinSetOption filetype=plug %{
    add-highlighter window/plug ref plug
  }

  # Highlighters
  add-highlighter shared/plug regions
  add-highlighter shared/plug/code default-region group
  add-highlighter shared/plug/code/message regex '(?S)^(.+?): (.+?)$' 0:keyword 1:value

  # Add plug keywords to the kakrc
  # https://github.com/mawww/kakoune/blob/master/rc/filetype/kakrc.kak
  hook global ModuleLoaded kak %{
    # Highlight all plug-based commands
    add-highlighter shared/kakrc/code/plug-keywords regex '\b(plug-core|plug-autoload|plug-old|plug-install|plug-upgrade|plug-execute|plug)\b' 0:keyword
  }

  define-command plug -params 2..3 -docstring 'plug <module> <repository> [config]' %{
    set-option -add global plug_modules %arg{1}
    set-option -add global plug_module_to_repository_map %arg{1} %arg{2}
    hook -group plug-module-loaded global User "plug-module-loaded=%arg{1}" %arg{3}
  }

  define-command plug-autoload -params 1..2 -docstring 'plug-autoload <module> [config]' %{
    plug %arg{1} '' %arg{2}
  }

  define-command plug-core -params 0..1 -docstring 'plug-core [config]' %{
    evaluate-commands %sh{
      if [ "$kak_opt_plug_autoload_path/core" -ef "$kak_opt_plug_core_path" ]; then
        echo 'evaluate-commands %arg{1}'
      fi
    }
  }

  define-command plug-require-modules -docstring 'plug-require-modules' %{
    evaluate-commands %sh{
      set -- $kak_opt_plug_modules
      printf 'plug-require-module %s;' "$@"
    }
    trigger-user-hook "plug-modules-loaded"
  }

  define-command -hidden plug-require-module -params 1 -docstring 'plug-require-module <module>' %{
    try %{
      require-module %arg{1}
      trigger-user-hook "plug-module-loaded=%arg{1}"
    } catch %{
      echo -debug "plug-require-module: No such module: %arg{1}"
    }
  }

  # Plugins with no module
  define-command plug-old -params 2..3 -docstring 'plug-old <module> <repository> [config]' %{
    set-option -add global plug_module_to_repository_map %arg{1} %arg{2}
    evaluate-commands %sh{
      if [ -d "$kak_opt_plug_autoload_path/$1" ]; then
        echo 'evaluate-commands %arg{3}'
      fi
    }
  }

  define-command -hidden plug-fifo -params 1.. -docstring 'plug-fifo <command>' %{
    nop %sh(mkfifo plug.fifo)
    edit -scroll -fifo plug.fifo '*plug*'
    nop %sh(("$@" > plug.fifo 2>&1; rm plug.fifo) < /dev/null > /dev/null 2>&1 &)
  }

  define-command plug-install -docstring 'plug-install' %{
    plug-fifo sh -c %{
      kak_opt_plug_core_path=$1
      kak_opt_plug_autoload_path=$2
      kak_opt_plug_install_path=$3
      shift 3
      kak_opt_plug_module_to_repository_map=$@

      # Clean off the autoload
      echo "plug-install:clean: $kak_opt_plug_autoload_path"
      rm -Rf "$kak_opt_plug_autoload_path"
      mkdir -p "$kak_opt_plug_autoload_path"

      # Core
      echo "plug-install:core: $kak_opt_plug_core_path → $kak_opt_plug_autoload_path/core"
      ln -s "$kak_opt_plug_core_path" "$kak_opt_plug_autoload_path/core"

      while [ $# -ge 2 ]; do
        module=$1 repository=$2; shift 2

        # plug-autoload <module> has no <repository> parameter
        if [ -z "$repository" ]; then
          continue
        fi

        # Module variables
        module_autoload_path=$kak_opt_plug_autoload_path/$module
        module_install_path=$kak_opt_plug_install_path/$module

        # Install
        echo "plug-install:install: $repository → $module_install_path"

        # → Install
        if ! [ -d "$module_install_path" ]; then
          (cd; git clone "$repository" "$module_install_path")

        # → Update
        else
          (cd "$module_install_path"; git pull)

        fi

        # Symlink environment
        echo "plug-install:symlink-environment: $module_install_path → $module_autoload_path"
        ln -s "$module_install_path" "$module_autoload_path"
      done
    } -- \
      %opt{plug_core_path} \
      %opt{plug_autoload_path} \
      %opt{plug_install_path} \
      %opt{plug_module_to_repository_map}
  }

  define-command plug-execute -params 2.. -shell-script-candidates 'cd "$kak_opt_plug_install_path" && ls' -docstring 'plug-execute <module> <command>' %{
    plug-fifo sh -c %{
      kak_opt_plug_install_path=$1
      kak_module=$2
      shift 2
      kak_command=$@

      # Execute the command in the plugin directory
      module_path=$kak_opt_plug_install_path/$kak_module
      echo "plug-execute:change-directory: $module_path"
      cd "$module_path"
      "$@"
    } -- \
      %opt{plug_install_path} \
      %arg{@}
  }

  define-command plug-upgrade-example -docstring 'plug-upgrade-example' %{
    info -title plug-upgrade-example %{
      define-command plug-upgrade -docstring 'plug-upgrade' %{
        plug-install
        plug-execute lsp cargo build --release
      }
    }
  }

  define-command plug-clean -docstring 'plug-clean' %{
    nop %sh{
      rm -Rf "$kak_opt_plug_autoload_path" "$kak_opt_plug_install_path"
    }
    echo -markup '{Information}All plugins removed'
  }

  # Mappings ───────────────────────────────────────────────────────────────────

  declare-user-mode plug

  define-command -hidden plug-install-interactive -docstring 'plug-install-interactive' %{
    prompt module: %{
      # Module
      set-register a %val{text}

      prompt repository: %{
        # Repository
        set-register b %val{text}

        # Clone the repository
        nop %sh{
          module=$kak_main_reg_a
          repository=$kak_main_reg_b

          # Module variables
          module_autoload_path=$kak_opt_plug_autoload_path/$module
          module_install_path=$kak_opt_plug_install_path/$module

          # Install
          (cd; git clone "$repository" "$module_install_path")

          # Symlink environment
          ln -s "$module_install_path" "$module_autoload_path"
        }

        # Open a documented scratch buffer
        edit! -scratch '*plug*'
        set-option buffer filetype asciidoc
        set-register c "
Configuration:

```
plug %reg{a} %reg{b}
```

Press `Enter` to copy and open your kakrc.
"
        execute-keys -draft '"cR_y%R'

        # Mappings
        map -docstring 'Copy and open kakrc' buffer normal <ret> ': plug-edit-kakrc %reg{a} %reg{b}<ret>'
      }
    }
  }

  define-command -hidden plug-edit-kakrc -params 2 -docstring 'plug-edit-kakrc <module> <repository>' %{
    # Open the kakrc
    edit %opt{plug_kakrc_path}

    # Copy the plug command to insert.
    set-register dquote "plug %arg{1} %arg{2}
"
  }

  map -docstring 'Install' global plug i ': plug-install-interactive<ret>'
}
