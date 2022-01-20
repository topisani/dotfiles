require-module c-family

# Highlight qualifiers
#  addhl shared/cpp/code/ regex %{([\w_0-9]+)::} 1:module

# Highlight attributes
addhl shared/cpp/code/annotation regex '(\[\[)(.*?)(\]\])' 0:annotation
addhl shared/cpp/code/ regex '\b(co_await|co_yield|co_return)\b' 0:keyword

# Highlight doc comments

rmhl shared/cpp/line_comment
rmhl shared/cpp/comment

add-highlighter shared/cpp/doc_comment region '/\*\*[^/]' \*/ group
add-highlighter shared/cpp/doc_comment2 region /// $ ref cpp/doc_comment

add-highlighter shared/cpp/comment region /\* \*/ group
add-highlighter shared/cpp/line_comment region // $ group

add-highlighter shared/cpp/comment/ fill comment
add-highlighter shared/cpp/line_comment/ ref cpp/comment
add-highlighter shared/cpp/comment/ regex '(TODO|NOTE|NOTES|PREV|FIXME)' 1:identifier

add-highlighter shared/cpp/doc_comment/ fill string
add-highlighter shared/cpp/doc_comment/ regex '\h*(///|\*/?|/\*\*+)' 1:comment 
add-highlighter shared/cpp/doc_comment/ regex '`.*?`' 0:module
add-highlighter shared/cpp/doc_comment/ regex '\\\w+' 0:module
add-highlighter shared/cpp/doc_comment/ regex '@\w+' 0:module

add-highlighter shared/cpp/macro/macro_def regex ^\h*#define\h+(\w*)(\([^)]*\))? 1:cppMacro 2:Default
define-command -hidden c-family-alternative-file -override %{
  evaluate-commands %sh{
    file="${kak_buffile##*/}"
    file_noext="${file%.*}"
    dir=$(dirname "${kak_buffile}")

    # Set $@ to alt_dirs
    eval "set -- ${kak_opt_alt_dirs}"

    case ${file} in
      *.c|*.cc|*.cpp|*.cxx|*.C|*.inl|*.m)
        for alt_dir in "$@"; do
          for ext in h hh hpp hxx H; do
            altname="${dir}/${alt_dir}/${file_noext}.${ext}"
            if [ -f ${altname} ]; then
              printf 'edit %%{%s}\n' "${altname}"
              exit
            fi
          done
        done
      ;;
      *.h|*.hh|*.hpp|*.hxx|*.H)
        for alt_dir in "$@"; do
          for ext in c cc cpp cxx C m inl; do
            altname="${dir}/${alt_dir}/${file_noext}.${ext}"
            if [ -f ${altname} ]; then
              printf 'edit %%{%s}\n' "${altname}"
              exit
            fi
          done
        done
      ;;
      *)
        echo "echo -markup '{Error}extension not recognized'"
        exit
      ;;
    esac
    echo "echo -markup '{Error}alternative file not found'"
  }
}

declare-user-mode gdbrepeat
map global gdbrepeat N ': gdb-session-new '            -docstring 'new session'
map global gdbrepeat n ': gdb-next<ret>'               -docstring 'step over (next)'
map global gdbrepeat s ': gdb-step<ret>'               -docstring 'step in (step)'
map global gdbrepeat f ': gdb-finish<ret>'             -docstring 'step out (finish)'
map global gdbrepeat a ': gdb-advace<ret>'             -docstring 'advance'
map global gdbrepeat r ': gdb-start<ret>'              -docstring 'start'
map global gdbrepeat R ': gdb-run<ret>'                -docstring 'run'
map global gdbrepeat c ': gdb-continue<ret>'           -docstring 'continue'
map global gdbrepeat , ': gdb-run-to-cursor<ret>'      -docstring 'run/continue to cursor'
map global gdbrepeat g ': gdb-jump-to-location<ret>'   -docstring 'jump'
map global gdbrepeat G ': gdb-toggle-autojump<ret>'    -docstring 'toggle autojump'
map global gdbrepeat t ': gdb-toggle-breakpoint<ret>'  -docstring 'toggle breakpoint'
map global gdbrepeat T ': gdb-backtrace<ret>'          -docstring 'backtrace'
map global gdbrepeat p ': gdb-print<ret>'              -docstring 'print'
map global gdbrepeat q ': gdb-session-stop<ret>'       -docstring 'stop'

def clang-format -docstring "Format buffer using clang-format" %{
  exec -draft '%|clang-format -assume-filename "<c-r>%"<ret>'
  echo "Formatted selection"
}

set global c_include_guard_style pragma

decl str other_file
#  set -add global modeline_vars other_file

def fzf-hpp-files %{
  fzf "edit $1" "find . -name '*.hpp'"
}

def fzf-cpp-files %{
  fzf "edit $1" "find . -name '*.cpp'"
}

def make-ask %{
  prompt 'Run: %opt[makecmd] ' 'make %val{text}'
}

# filetype hook
filetype-hook (cpp|c) %{
  lsp-setup
  lsp-enable-semantic-tokens

  map window filetype  d       ': enter-user-mode -lock gdbrepeat<ret>'  -docstring 'GDB...'
  map window filetype  <tab>   ': other-or-alt<ret>'                     -docstring 'Other file'
  map window filetype  =       ': clang-format<ret>'                     -docstring 'clang-format selection'
  map window filetype  m       ': make<ret>'                             -docstring 'Make'
  map window filetype  M       ': make-ask<ret>'                         -docstring 'Make prompt'
  map window filetype  <c-f>   ': fzf-hpp-files<ret>'                    -docstring 'Find header files'
  map window filetype  <C-S-F> ': fzf-cpp-files<ret>'                    -docstring 'Find cpp files'

	set-indent window 2
}


filetype-hook (cmake|make) %{
  map window filetype  d       ': enter-user-mode -lock gdbrepeat<ret>'  -docstring 'GDB...'
  map window filetype  m       ': make<ret>'                             -docstring 'Make'
  map window filetype  M       ': make-ask<ret>'                         -docstring 'Make prompt'
  map window filetype  <c-f>   ': fzf-hpp-files<ret>'                    -docstring 'Find header files'
  map window filetype  <C-S-F> ': fzf-cpp-files<ret>'                    -docstring 'Find cpp files'
}

def other-or-alt -docstring \
"Jump to alternative file.
If the current buffer has an 'other_file' option, use that.
Otherwise, calls :alt" \
%{ eval %sh{
  if [[ -n "$kak_opt_other_file" ]]; then
    echo "try %[ edit -existing '$(dirname $kak_buffile)/$kak_opt_other_file' ] catch %[ alt ]"
  else
    echo alt
  fi
}}
