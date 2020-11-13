# C++
import lsp

hook global BufCreate .*[.](ipp|ixx|inl) %{
  set-option buffer filetype cpp
}

#provide-module my-cpp %{
require-module c-family

# Highlight qualifiers
addhl shared/cpp/code/ regex %{([\w_0-9]+)::} 1:module

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
#add-highlighter shared/cpp/code/macro regex '\b[A-Z_]{3,}\b' 0:cqueryMacros

# define-command -hidden -override c-family-insert-on-newline %[ evaluate-commands -itersel -draft %[
#   execute-keys \;
#   try %[
#     evaluate-commands -draft -save-regs '/"' %[
#       # copy the commenting prefix
#       execute-keys -save-regs '' k <a-x>1s^\h*(//+\h*)<ret> y
#       try %[
#         # if the previous two comments aren't empty, create a new one
#         execute-keys K<a-x><a-K>^(\h*//+\h*\n){2}<ret> jj<a-x>s^\h*<ret>P
#       ] catch %[
#         # if there is no text in the previous comment, remove it completely
#         execute-keys d
#       ]
#     ]
#   ]
#   try %[
#     # if the previous line isn't within a comment scope, break
#     execute-keys -draft k<a-x> <a-k>^(\h*/\*|\h+\*(?!/))<ret>
# 
#     # find comment opening, validate it was not closed, and check its using star prefixes
#     execute-keys -draft <a-?>/\*<ret><a-H> <a-K>\*/<ret> <a-k>\A\h*/\*([^\n]*\n\h*\*)*[^\n]*\n\h*.\z<ret>
# 
#     try %[
#       # if the previous line is opening the comment, insert star preceeded by space
#       execute-keys -draft k<a-x><a-k>^\h*/\*<ret>
#       execute-keys -draft i*<space><esc>
#     ] catch %[
#        try %[
#         # if the next line is a comment line insert a star
#         execute-keys -draft j<a-x><a-k>^\h+\*<ret>
#         execute-keys -draft i*<space><esc>
#       ] catch %[
#         try %[
#           # if the previous line is an empty comment line, close the comment scope
#           /*
#           execute-keys -draft kK<a-x><a-k>^(\h+\*\h+\n){2}<ret> ;<a-x>d <a-x>1s\*(\h*)<ret>c/<esc>
#         ] catch %[
#           # if the previous line is a non-empty comment line, add a star
#           execute-keys -draft i*<space><esc>
#         ]
#       ]
#     ]
# 
#     # trim trailing whitespace on the previous line
#     try %[ execute-keys -draft s\h+$<ret> d ]
#     # align the new star with the previous one
#     execute-keys K<a-x>1s^[^*]*(\*)<ret>&
#   ]
# ] ]

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

new-mode gdbrepeat
map-all gdbrepeat -repeat %{
  n gdb-next              'step over (next)'
  s gdb-step              'step in (step)'
  f gdb-finish            'step out (finish)'
  a gdb-advace            'advance'
  r gdb-start             'start'
  R gdb-run               'run'
  c gdb-continue          'continue'
  , gdb-run-to-cursor     'run/continue to cursor'
  g gdb-jump-to-location  'jump'
  G gdb-toggle-autojump   'toggle autojump'
  t gdb-toggle-breakpoint 'toggle breakpoint'
  T gdb-backtrace         'backtrace'
  p gdb-print             'print'
  q gdb-session-stop      'stop'
}
map-mode gdbrepeat N ":gdb-session-new " 'new session' -raw

def clang-format -docstring "Format buffer using clang-format" %{
  exec -draft '%|clang-format -assume-filename "<c-r>%"<ret>'
  echo "Formatted selection"
}

set global c_include_guard_style pragma

decl str other_file
set -add global modeline_vars other_file

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
  echo -debug "cpphook"
  lsp-setup

  map-all filetype -scope window %{
    d     "enter-user-mode gdbrepeat" 'GDB...'
    <tab> "other-or-alt"              'Other file'
    =     "clang-format"              'clang-format selection'
    h "ccls-navigate L"               'Previous declaration'    -repeat
    j "ccls-navigate D"               'First child declaration' -repeat
    k "ccls-navigate U"               'Parent declaration'      -repeat
    l "ccls-navigate R"               'Next declaration'        -repeat
    m "make"                          "Make"
    M make-ask "Make prompt"
    <c-f> "fzf-hpp-files"             "Find header files"
    <C-S-F> "fzf-cpp-files"             "Find cpp files"
  }

  set window tabstop 2
  set window indentwidth 2

  hook window -group semantic-tokens BufReload .* lsp-semantic-tokens
  hook window -group semantic-tokens NormalIdle .* lsp-semantic-tokens
  hook window -group semantic-tokens InsertIdle .* lsp-semantic-tokens
}


filetype-hook (cmake|make) %{
  map-all filetype -scope window %{
    d     "enter-user-mode gdbrepeat" 'GDB...'
    m "make"                          "Make"
    M make-ask "Make prompt"
    <c-f> "fzf-hpp-files"             "Find header files"
    <C-S-F> "fzf-cpp-files"             "Find cpp files"
  }
}
#}
