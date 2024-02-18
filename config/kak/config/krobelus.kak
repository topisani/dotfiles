
try %{
	define-command my-kakoune-lsp-overrides %{
		# # This is slow because it restarts all language servers.
		# set-option global lsp_config "%opt{lsp_config}
		# [language.python.settings._]
		# pylsp.configurationSources = ['pycodestyle', 'flake8']
		# "
	}
}

define-command -override my-lsp-debug %{
	set-option global lsp_cmd "kak-lsp -s %val{session} -vvvv --log /tmp/kak-lsp-%val{session}.log"
}
define-command -override my-lsp-no-debug %{
	set-option global lsp_cmd "kak-lsp -s %val{session} -v --log /tmp/kak-lsp-%val{session}.log"
}

declare-option -hidden -docstring "nop if non-idempotent parts of the configuration have been loaded" str ok
try %{
	declare-user-mode git
	declare-user-mode git-am
	declare-user-mode git-apply
	declare-user-mode git-bisect
	declare-user-mode git-blame
	declare-user-mode git-branchstack
	declare-user-mode git-cherry-pick
	declare-user-mode git-commit
	declare-user-mode git-diff
	declare-user-mode git-fetch
	declare-user-mode git-merge
	declare-user-mode git-push
	declare-user-mode git-rebase
	declare-user-mode git-reset
	declare-user-mode git-revert
	declare-user-mode git-revise
	declare-user-mode git-yank
	declare-user-mode git-stash
	declare-user-mode git-gl
	declare-user-mode make
	declare-user-mode reference
	declare-user-mode snippets
	declare-user-mode toggle

	set-option global ok 'fail errror loading plugins'

	# Set the session name to the Git repo or the CWD unless we already
	# have a session name that doesn't look like a PID (via "kak -s").
	evaluate-commands %sh{
		expr -- "$kak_session" : '^[0-9]*$' >/dev/null || exit
		root="$(git rev-parse --show-toplevel 2>/dev/null)"
		root=${root##*/}
		root="${root:-$PWD}"
		session_name="$(printf %s "$root" | sed s/[^a-zA-Z0-9_-]/_/g)"
		echo "try %{ rename-session $session_name }"
	}

	## Symflower integration
	nop %{
		try %{ source ~/git/symflower-kakoune/rc/symflower.kak }
		try %{ remove-hooks global my-symflower }
		hook -group my-symflower global BufCreate .*/symflower.kak %{
			set-option buffer disabled_hooks "%opt{disabled_hooks}|my-format"
		}
		hook -group my-symflower global BufCreate \*symflower\* %{
			add-highlighter buffer/symflower group
			add-highlighter buffer/symflower/ regex %opt{lsp_location_format} 1:cyan 2:green 3:green
			add-highlighter buffer/symflower/ line %{%opt{grep_current_line}} default+b
		}
		map global user d %{:enter-user-mode symflower<ret>} -docstring "symflower..."
	}

	## plugins
	evaluate-commands %sh{
		plugin_dir="$kak_config/bundle/plugins"
		mkdir -p "$plugin_dir"
		[ -d "$kak_config/bundle/plugins/kak-bundle" ] ||
		git clone https://codeberg.org/jdugan6240/kak-bundle "$plugin_dir/kak-bundle"
		echo 'source "%val{config}/bundle/plugins/kak-bundle/rc/kak-bundle.kak"'
		echo 'bundle https://codeberg.org/jdugan6240/kak-bundle'
	}
	bundle https://github.com/eraserhd/kak-ansi
	bundle https://github.com/Delapouite/kakoune-buffers
	bundle-config kakoune-buffers %{
		map global buffers "'" :info-buffers<ret> -docstring 'info'
		map global buffers c %{:edit ~/git/g/.config/kak/kakrc<ret>} -docstring 'edit ~/git/g/.config/kak/kakrc'
		map global buffers C %exp{:edit %val{config}/kakrc<ret>} -docstring %exp{edit "%val{config}/kakrc"}
		map global buffers m %{:buffer *make*<ret>} -docstring "*make*"
		map global buffers M %{:buffer make<ret>} -docstring "make"
		map global buffers g %{:buffer %opt{my_grep_buffer}<ret>} -docstring "*grep* or equivalent"
		map global buffers v %{:buffer %opt{my_git_buffer}<ret>} -docstring "*git*"
		map global buffers t %{:my-colon-edit todo<ret>} -docstring "todo"
	}
	bundle https://gitlab.com/Screwtapello/kakoune-cargo
	bundle-config kakoune-cargo %{
		map global cargo C %{:cargo clippy<ret>} -docstring "clippy"
		map global cargo m %{:write-all<ret>:cargo build<ret>} -docstring "build"
	}
	bundle https://github.com/Delapouite/kakoune-cd
	bundle-config kakoune-cd %{
		# map global user C %{:enter-user-mode cd<ret>} -docstring "cd..."
	}
	bundle https://github.com/occivink/kakoune-find
	bundle https://github.com/occivink/kakoune-phantom-selection
	bundle-config kakoune-cd %{
		map global user a :phantom-selection-add-selection<ret>
		map global user z :phantom-selection-select-all<ret>
		map global user A %{:phantom-selection-select-all; phantom-selection-clear<ret>}
		map global normal <down> :phantom-selection-iterate-next<ret>
		map global normal <up> :phantom-selection-iterate-prev<ret>
		map global insert <down> <esc>:phantom-selection-iterate-next<ret>i
		map global insert <up> <esc>:phantom-selection-iterate-prev<ret>i
	}
	bundle https://gitlab.com/Screwtapello/kakoune-repl-buffer
	bundle https://github.com/Delapouite/kakoune-text-objects
	bundle https://github.com/andreyorst/smarttab.kak
	bundle-config smarttab.kak %{
		require-module smarttab
		set-option global softtabstop 4
		hook -group my-smarttab global WinSetOption filetype=(asciidoc|bazel|c|cpp|java|python|rust|fish|toml|ts|yaml) expandtab
	}
	# bundle https://codeberg.org/jdugan6240/kak-dap
	bundle-load

	evaluate-commands %sh{
		mkdir -p ~/git
		for plugin in \
		plug.kak \
		kak-ansi \
		kakoune-buffers \
		kakoune-cargo \
		kakoune-cd \
		kakoune-find \
		kakoune-phantom-selection \
		kakoune-repl-buffer \
		kakoune-text-objects \
		smarttab.kak \
		;
		do {
			[ -L ~/git/"$plugin" ] && [ -e ~/git/"$plugin" ] || ln -sf "$kak_config/bundle/plugins/$plugin" ~/git/
		} done

		if command -v kak-lsp >/dev/null; then {
			# kakoune-lsp dev mode: source lsp.kak directly to avoid the need for a rebuild, and create a verbose log.
			if test -n "$lsp"; then {
				echo source $lsp/rc/lsp.kak
				mkdir -p $lsp/t
				:> $lsp/t/log
				echo "set-option global lsp_cmd 'kak-lsp -s ${kak_session} -vvvv --log $lsp/t/log --config $lsp/kak-lsp.toml'"
			} else {
				kak-lsp -s $kak_session --kakoune
				echo my-lsp-no-debug
				echo my-kakoune-lsp-overrides
			} fi
		} fi

		kak-tree-sitter -dks --session $kak_session
	}
	set-option global ok nop
}
evaluate-commands %opt{ok}

try %{
	# Recommended mappings
	map global user l %{:enter-user-mode lsp<ret>} -docstring "LSP mode"
	map global goto d '<esc>:lsp-definition<ret>' -docstring 'definition'
	map global goto r '<esc>:lsp-references<ret>' -docstring 'references'
	map global goto y '<esc>:lsp-type-definition<ret>' -docstring 'type definition'
	map global insert <tab> '<a-;>:try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' -docstring 'Select next snippet placeholder'
	# map global normal <tab> ':try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' -docstring 'Select next snippet placeholder'
	map global object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
	map global object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
	map global object e '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
	map global object k '<a-semicolon>lsp-object Class Interface Struct<ret>' -docstring 'LSP class interface or struct'
	map global object d '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
	map global object D '<a-semicolon>lsp-diagnostic-object<ret>' -docstring 'LSP errors'

	map global lsp 1 :lsp-enable<ret> -docstring "lsp-enable"
	map global lsp w :lsp-enable-window<ret> -docstring "lsp-enable-window"
	map global lsp 2 :lsp-disable<ret> -docstring "lsp-disable"
	map global lsp W :lsp-disable-window<ret> -docstring "lsp-disable-window"

	map global lsp F :lsp-formatting-sync<ret> -docstring "lsp-formatting-sync"
}

define-command -override kak-tree-sitter-highlight-try-enable %{}
try %{
	# From kak-tree-sitter-textobjects-enable
	map global object q   '<a-;> kak-tree-sitter-req-textobjects function<ret>'  -docstring 'function (tree-sitter)'
	map global object t   '<a-;> kak-tree-sitter-req-textobjects class<ret>'  -docstring 'class (tree-sitter)'
	map global object '#' '<a-;> kak-tree-sitter-req-textobjects comment<ret>'  -docstring 'comment (tree-sitter)'
	map global object 'v' '<a-;> kak-tree-sitter-req-textobjects parameter<ret>'  -docstring 'parameter (tree-sitter)'
}

## comments
define-command -override my-comment %{
	try comment-line catch comment-block
}
define-command -override my-copy-and-comment %{
	evaluate-commands -save-regs ^ %{
		execute-keys -draft %{ZxyP:comment-line<ret>z}
	}
}

## clipboard
define-command -override my-clipboard-paste %{
	execute-keys %{!copy paste<ret>}
}
define-command -override my-clipboard-paste-prompt %{
	evaluate-commands -verbatim set-register t %sh{
		copy paste
	}
}
define-command -override my-clipboard-yank %{
	execute-keys -draft %{,y<a-|>copy >/dev/null 2>&1<ret>}
}
define-command -override my-yank-buffile %{ evaluate-commands %sh{
	x=$(realpath -- "$kak_buffile")
	printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
	printf %s "$x" |
	copy >/dev/null 2>&1
}}
define-command -override my-yank-buffile-relative -params 0..1 %{ evaluate-commands %sh{
	x=$(realpath --relative-to "$(git rev-parse --show-toplevel || echo "$PWD")" -- "$kak_buffile")
	printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
	test -n "$1" && exit
	printf %s "$x" | copy >/dev/null 2>&1
}}
define-command -override my-yank-buffile-relative-and-line %{ evaluate-commands %sh{
	x=$(realpath --relative-to "$(git rev-parse --show-toplevel || echo "$PWD")" -- "$kak_buffile"):$kak_cursor_line
	printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
	printf %s "$x" | copy >/dev/null 2>&1
}}
define-command -override my-yank-bufdir-relative -params 0..1 %{ evaluate-commands %sh{
	x="$(realpath --relative-to "$PWD" -- "${kak_buffile%/*}")"/
	printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
	test -n "$1" && exit
	printf %s "$x" | copy >/dev/null 2>&1
}}

## files
define-command -override my-goto-file -docstring "jump to file:line:col at cursor" %{
	evaluate-commands -save-regs ^ %{
		try %{
			execute-keys -save-regs '' Z
			execute-keys %{<semicolon><a-a><a-w>1s(?:cargo:warning=)?([^\s]+)(?::(\d+))(?::(\d+)\b(?![.]))<ret>)<space><esc>,<esc>}
		} catch %{
			execute-keys -save-regs '' z
			execute-keys %{<semicolon><a-a><a-w>1s(?:cargo:warning=)?([^:\s]+)(?::(\d+))?(?::(\d+)\b(?![.]))?<ret>)<space><esc>,<esc>}
		}
	}
	execute-keys -with-hooks "gf%reg{2}g<a-h>%reg{3}lh"
}
define-command -override my-colon-edit -docstring "my-colon-edit <filename>[:<line>[:<column>]]: open file at position" -params 1 %{
	try %{
		evaluate-commands %sh{
			echo "edit -existing -- $1" | sed 's/:/ /g'
		}
	} catch %{
		# Accept paths that are relative to the project root, even if we are in a subdirectory.
		try %{
			evaluate-commands %sh{
				echo "edit -existing -- $(git rev-parse --show-toplevel)/$1" | sed 's/:/ /g'
			}
		} catch %{
			edit -- %arg{1}
		}
	}
}
try %{ complete-command -menu my-colon-edit file }
define-command -override my-edit-sibling -docstring "edit a file in the current buffer's directory" %{
	evaluate-commands -save-regs '"' %{
		my-yank-bufdir-relative internal
		execute-keys %{:edit <c-r>"}
	}
}
define-command -override my-mkdir -docstring "create the buffer's directory" %{
	nop %sh{mkdir -p -- "${kak_buffile%/*}"}
}
define-command -override my-find-edit -params 1 %{edit -- %arg{@}}
try %{ complete-command -menu my-find-edit shell-script-candidates %{ find -type f | sed s,^./,, } }

define-command -override my-git-edit -params 1 %{
	edit -existing -- %arg{@}
} -menu -shell-script-candidates %{ git ls-files }
try %{ complete-command -menu my-git-edit shell-script-candidates %{ git ls-files } }
define-command -override my-git-edit-root -params 1 %{
	edit -existing -- %arg{@}
}
try %{ complete-command -menu my-git-edit-root shell-script-candidates %{ git ls-files "$(git rev-parse --show-toplevel)" } }

define-command -override my-rename-buffile %{
	prompt -init %val{buffile} 'rename to: ' '
	evaluate-commands %sh{
		line="$kak_cursor_line"
		column="$kak_cursor_column"
		mkdir -p "$(dirname "$kak_text")"
		mv "$kak_buffile" "$kak_text"
		echo delete-buffer
		echo edit -existing -- %val{text} $line $column
	}' -file-completion
}

## https://gitlab.com/krobelus/gitlab-offline-review
declare-option -hidden str my_gl_buffer
define-command -override gl-next %{
	lsp-next-location %opt{my_gl_buffer}
}
define-command -override gl-previous %{
	lsp-previous-location %opt{my_gl_buffer}
}
define-command -override gl-resolve -docstring "resolve the thread at cursor" %{
	buffer %opt{my_gl_buffer}
	execute-keys or<esc>
	gl-next
}
define-command -override gl-fetch -docstring %{
	Fetch new comments for the current issue/MR
} %{
	declare-option str-list my_gl_static_words
	nop %sh{
		(
			{
				set -- $(gl staticwords)
				printf %s "set-option global my_gl_static_words $*"
				gl fetch "$kak_buffile" >/tmp/gl-fetch 2>&1 ||
				echo "
				nop %sh{cat /tmp/gl-fetch >&2}
				"
			} | kak -p "$kak_session"
		) >/dev/null 2>&1 </dev/null &
	}
}
define-command -override gl-submit -docstring %{
	Submit comments for the current issue/MR
} %{
	write
	nop %sh{
		(
			{
				gl submit "$kak_buffile" >/tmp/gl-submit 2>&1 ||
				echo "
				nop %sh{cat /tmp/gl-submit >&2}
				echo -markup '{Error}gl error'
				"
			} | kak -p "$kak_session"
		) >/dev/null 2>&1 </dev/null &
	}
	# The review draft will be deleted, so switch to the unresolved threads.
	evaluate-commands %sh{
		if [ ${kak_bufname##*/} = review.gl ]; then {
			[ -f "${kak_bufname%/*}/"todo.gl ] && echo edit "${kak_bufname%/*}/"todo.gl
			[ -f "${kak_bufname%/*}/"comments.gl ] && echo edit "${kak_bufname%/*}/"comments.gl
		} fi
	}
}
define-command -override gl-visit -params 1 -docstring %{
	Read a GitLab URL from system clipboard and visit the corresponding file.
	Fetch the latest comments of this issue or MR in the background.
} %{
	edit %sh{
		set -e
		path=$(gl url2path "$1")
		printf %s/%s "$(git rev-parse --show-toplevel)" "$path"
		( gl fetch "$path" </dev/null >/dev/null 2>&1 ) &
	}
}
define-command -override gl-visit-clipboard -docstring %{
	Read a GitLab URL from system clipboard and visit the corresponding file.
	Fetch the latest comments of this issue or MR in the background.
} %{
	edit %sh{
		set -e
		path=$(gl url2path "$(copy paste)")
		printf %s/%s "$(git rev-parse --show-toplevel)" "$path"
		( gl fetch "$path" </dev/null >/dev/null 2>&1 ) &
	}
}
define-command -override gl-url -docstring %{
	Copy the GitLab URL of the current file
} %{ nop %sh{
	printf %s "$(gl path2url "$kak_buffile")" | copy >/dev/null 2>&1
} }
define-command -override gl-discuss %{
	evaluate-commands -save-regs ontab| %{
		evaluate-commands -draft %{
			execute-keys xH
			set-register t %val{selection}
			execute-keys %{<a-/>^diff --git (\S+) (\S+)$<ret>}
			set-register o %reg{1}
			set-register n %reg{2}
		}
		set-register | %{
			perl -we '{
				$state = "header";
				while (<STDIN>) {
					if (m{^diff\b}) {
						$state = "header";
						next;
					}
					if ($state eq "header") {
						if (m{^---} || m{^\+\+\+}) {
							next;
						}
					}
					if (m{^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@}) {
						$state = "contents";
						$old_line = $1 - 1;
						$new_line = $2 - 1;
					} else {
						if (m{^[ -]}) {
							$old_line++ if defined $old_line;
						}
						if (m{^[ +]}) {
							$new_line++ if defined $new_line;
						}
					}
				}
				print "set-register a $old_line\n";
				print "set-register b $new_line\n";
			}' >"$kak_command_fifo"
		}
		execute-keys -draft Gkx<a-|><ret>
		evaluate-commands %sh{
			branch=${kak_buffile%/review.diff}
			branch=${branch##*/}
			old_file=${kak_reg_o#a/}
			new_file=${kak_reg_n#b/}
			text=$kak_reg_t
			old_line=$kak_reg_a
			new_line=$kak_reg_b
			EDITOR=true gl discuss --branch="$branch" -- "$old_file" "$new_file" "$text" "$old_line" "$new_line"
			echo "edit -existing gl/$branch/review.gl"
		}
	}
}

## grep
define-command -override my-find-apply-changes-force %{
	evaluate-commands -no-hooks %{
		find-apply-changes -force
		write-all
	}
}
define-command -override my-grep -docstring "grep and select matches with <a-s>
works best if grepcmd uses a regex flavor simlar to Kakoune's
" -params .. %{
	try %{
		evaluate-commands %sh{ [ -z "$1" ] && echo fail }
		set-register / "(?S)%arg{1}"
		grep %arg{@}
	} catch %{
		execute-keys -save-regs '' *
		evaluate-commands -save-regs l %{
			evaluate-commands -verbatim grep -- %sh{ printf %s "$kak_main_reg_slash" }
		}
	}
	my-map-quickselect
}
try %{ complete-command my-grep file }

define-command -override my-find -docstring "find" -params ..1 %{
	find %arg{@}
	alias buffer=*find* w my-find-apply-changes-force
	my-map-quickselect
}
define-command -override my-map-quickselect %{ evaluate-commands -save-regs 'l' %{
	evaluate-commands -try-client %opt{toolsclient} %sh{
		printf %s "map buffer=$kak_opt_my_grep_buffer normal <tab> '"
		printf %s '%S^<ret><a-h>/^.*?:\d+(?::\d+):<ret>'
		printf %s '<a-semicolon>l<a-l>'
		printf %s "s$(printf %s "$kak_main_reg_slash" | sed s/"'"/"''"/g"; s/</<lt>/g")<ret>"
		printf %s "'"
	}
}}
declare-option -hidden str my_grep_buffer
define-command -override my-grep-next-match -docstring 'Jump to the next match in a grep-like buffer' %{
	my-grep-next-match-impl %opt{my_grep_buffer}
}
define-command -override my-grep-previous-match -docstring 'Jump to the previous match in a grep-like buffer' %{
	my-grep-previous-match-impl %opt{my_grep_buffer}
}
define-command -override my-grep-next-match-impl -docstring 'Jump to the next match in a grep-like buffer' %{
	evaluate-commands -try-client %opt{jumpclient} %{
		buffer %arg{1}
		# TODO: upstream \n?
		execute-keys ge %opt{grep_current_line} g<a-l> /^[^:\n ]+:\d+:<ret>
		grep-jump
	}
	try %{ evaluate-commands -client %opt{toolsclient} %{
		buffer %arg{1}
		execute-keys gg %opt{grep_current_line}g
	}}
} -params 1
define-command -override my-grep-previous-match-impl -docstring 'Jump to the previous match in a grep-like buffer' %{
	evaluate-commands -try-client %opt{jumpclient} %{
		buffer %arg{1}
		execute-keys "ge %opt{grep_current_line}g<a-h> <a-/>^[^:\n ]+:\d+:<ret>"
		grep-jump
	}
	try %{ evaluate-commands -client %opt{toolsclient} %{
		buffer %arg{1}
		execute-keys gg %opt{grep_current_line}g
	}}
} -params 1
declare-option -hidden str-list my_grep_stack
define-command -override grep-stack-push -docstring "record grep buffer" %{
	evaluate-commands %sh{
		eval set -- $kak_quoted_opt_my_grep_stack
		if printf '%s\n' "$@" | grep -Fxq -- "$kak_bufname"; then {
			exit
		} fi
		newbuf=$kak_bufname-$#
		echo "try %{ delete-buffer! $newbuf }"
		echo "rename-buffer $newbuf"
		echo "set-option -add global my_grep_stack %val{bufname}"
	}
	set-option global my_grep_buffer %val{bufname}
}
define-command -override grep-stack-pop -docstring "restore grep buffer" %{
	evaluate-commands %sh{
		eval set -- $kak_quoted_opt_my_grep_stack
		if [ $# -eq 0 ]; then {
			echo fail "grep-stack-pop: no grep buffer to pop"
			exit
		} fi
		printf 'set-option global my_grep_stack'
		top=
		while [ $# -ge 2 ]; do {
			top=$1
			printf ' %s' "$1"
			shift
		} done
		echo
		echo "delete-buffer $1"
		echo "set-option global my_grep_buffer '$top'"
	}
	try %{
		evaluate-commands -try-client %opt{jumpclient} %{
			buffer %opt{my_grep_buffer}
			grep-jump
		}
	}
}
define-command -override grep-stack-clear -docstring "clear grep buffers" %{
	evaluate-commands %sh{
		eval set --  $kak_quoted_opt_my_grep_stack
		printf 'try %%{ delete-buffer %s }\n' "$@"
	}
	set-option global my_grep_stack
}

## make
define-command -override my-make -params .. -docstring %{
	my-make [<arguments>]: make utility wrapper
	All the optional arguments are forwarded to the make utility
} %{
	try %{
		evaluate-commands -buffer *make* %{
			set-option buffer cargo_current_error_line 1
			try %{ delete-buffer *make.bak* }
			rename-buffer *make.bak*
		}
	}
	make %arg{@}
}
define-command -override -hidden make-jump %{
	evaluate-commands %{
		try %{
			execute-keys <a-h><a-l> s "((?:\w:)?[^:]+):(\d+):(?:(\d+):)?([^\n]+)\z" <ret>l
			set-option buffer make_current_error_line %val{cursor_line}
			make-open-error "%reg{1}" "%reg{2}" "%reg{3}" "%reg{4}"
		}
	}
}

## Git
# TODO remove
hook global WinSetOption filetype=git-(?:commit|diff|log|notes|rebase) %{
	map buffer normal <ret> %exp{:git-jump # %val{hook_param}<ret>} -docstring 'Jump to source from git diff'
	hook -once -always window WinSetOption filetype=.* %exp{
		unmap buffer normal <ret> %%{:git-jump # %val{hook_param}<ret>}
	}
}
declare-option -hidden str my_git_buffer
declare-option -hidden str-list my_git_stack
define-command -override git-stack-push -docstring "record *git* buffer" %{
	evaluate-commands %sh{
		eval set -- $kak_quoted_opt_my_git_stack
		if printf '%s\n' "$@" | grep -Fxq -- "$kak_bufname"; then {
			exit
		} fi
		newbuf=$kak_bufname-$#
		echo "try %{ delete-buffer! $newbuf }"
		echo "rename-buffer $newbuf"
		echo "set-option -add global my_git_stack %val{bufname}"
	}
	set-option global my_git_buffer %val{bufname}
}
define-command -override git-stack-pop -docstring "restore *git* buffer" %{
	evaluate-commands %sh{
		eval set -- $kak_quoted_opt_my_git_stack
		if [ $# -eq 0 ]; then {
			echo fail "git-stack-pop: no *git* buffer to pop"
			exit
		} fi
		printf 'set-option global my_git_stack'
		top=
		while [ $# -ge 2 ]; do {
			top=$1
			printf ' %s' "$1"
			shift
		} done
		echo
		echo "delete-buffer $1"
		echo "set-option global my_git_buffer '$top'"
	}
	try %{
		evaluate-commands -try-client %opt{jumpclient} %{
			buffer %opt{my_git_buffer}
		}
	}
}
define-command -override git-stack-clear -docstring "clear *git* buffers" %{
	evaluate-commands %sh{
		eval set --  $kak_quoted_opt_my_git_stack
		printf 'try %%{ delete-buffer %s }\n' "$@"
	}
	set-option global my_git_stack
}

define-command -override my-conflict-1 -docstring "choose the first side of a conflict hunk" %{
	evaluate-commands -draft %{
		execute-keys <a-l>l<a-/>^<lt>{4}<ret>xd
		execute-keys h/^={4}|^\|{4}<ret>
		execute-keys ?^>{4}<ret>xd
	}
}
define-command -override my-conflict-2 -docstring "choose the second side of a conflict hunk" %{
	evaluate-commands -draft %{
		execute-keys <a-l>l<a-/>^<lt>{4}<ret>
		execute-keys ?^={4}<ret>xd
		execute-keys />{4}<ret>xd
	}
}
define-command -override tig-connect %{
	terminal env "EDITOR=kak-remote-edit.sh %val{session} %val{client}" tig
}
define-command -override tig -params .. %{
	terminal env "EDITOR=kak -c %val{session}" tig %arg{@}
}
define-command -override tig-blame-here -docstring "Run tig blame on the current line" %{
	tig -C %sh{git rev-parse --show-toplevel} blame -C "+%val{cursor_line}" -- %sh{
		dir="$(git rev-parse --show-toplevel)"
		printf %s "${kak_buffile##$dir/}"
	}
}
define-command -override tig-blame-selection -docstring "Run tig -L on the selected lines" %{
	evaluate-commands -save-regs d %{
		evaluate-commands -draft %{
			execute-keys <a-:>
			set-register d %sh{git rev-parse --show-toplevel}
		}
		tig -C %reg{d} %sh{
			anchor=${kak_selection_desc%,*}
			anchor_line=${anchor%.*}
			cursor=${kak_selection_desc#*,}
			cursor_line=${cursor%.*}
			d=$kak_reg_d
			printf %s "-L$anchor_line,$cursor_line:${kak_buffile##$d/}"
		}
	}
}
define-command -override my-git-enter %{ evaluate-commands -save-regs c %{
	try %{
		evaluate-commands -draft %{
			try %{
				execute-keys s\S{2,}<ret>
				evaluate-commands %sh{
					[ "$(git rev-parse --revs-only "$kak_selection")" ] || echo fail
				}
			} catch %{
				try %{ execute-keys <semicolon><a-i>w }
				evaluate-commands %sh{
					[ "$(git rev-parse --revs-only "$kak_selection")" ] || echo fail
				}
			}
			set-register c %val{selection}
		}
		git show %reg{c} --
	} catch %{
		require-module diff
		diff-jump %opt{git_work_tree}
	}
}}
define-command -override my-git-select-commit %{
	try %{
		execute-keys %{<a-/>^commit \S+<ret>}
		execute-keys %{1s^commit (\S+)<ret>}
	} catch %{
		try %{
			execute-keys <a-i>w
			evaluate-commands %sh{
				[ "$(git rev-parse --revs-only "$kak_selection")" ] || echo fail
			}
		} catch %{
			# oneline log
			execute-keys <semicolon>x
			try %{ execute-keys %{s^[0-9a-f]{4,}\b<ret>} }
		}
	}
}
define-command -override my-git-yank-reference %{ evaluate-commands -draft %{
	my-git-select-commit
	evaluate-commands %sh{
		x=$(git log -1 "${kak_selection}" --pretty=reference)
		printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
		printf %s "$x" | copy >/dev/null 2>&1
	}
}}
define-command -override my-git-yank-commit %{ evaluate-commands -draft %{
	my-git-select-commit
	my-clipboard-yank
}}
define-command -override my-git-yank -params 1 %{ evaluate-commands -draft %{
	my-git-select-commit
	evaluate-commands %sh{
		x=$(git log -1 "${kak_selection}" --format="$1")
		printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
		printf %s "$x" | copy >/dev/null 2>&1
	}
}}
define-command -override my-git-fixup %{ evaluate-commands -draft %{
	my-git-select-commit
	git commit --fixup %val{selection}
}}

define-command -override my-git -params 1.. %{ evaluate-commands -draft %{
	nop %sh{
		(
			response=my-git-log-default
			prepend_git=true
			while true; do {
				if [ "$1" = -no-refresh ]; then {
					response=nop
					shift
				} elif [ "$1" = -no-git ]; then {
					prepend_git=false
					shift
				} else {
					break
				} fi
			} done
			if $prepend_git; then
			set -- git "$@"
			fi
			commit=$kak_selection eval set -- "$@"
			escape2() { printf %s "$*" | sed "s/'/''''/g"; }
			escape3() { printf %s "$*" | sed "s/'/''''''''/g"; }
			if output=$(
				EDITOR="kak-remote-edit.sh ${kak_session} ${kak_client} --wait" \
				"$@" 2>&1
			); then {
				response="'
				$response
				echo -debug $ ''$(escape2 "$@") <<<''
				echo -debug ''$(escape2 "$output")>>>''
				'"
			} else {
				response="'
				$response
				echo -debug failed to run ''$(escape2 "$@")''
				echo -debug ''git output: <<<''
				echo -debug ''$(escape2 "$output")>>>''
				hook -once buffer NormalIdle .* ''
				echo -markup ''''{Error}{\\}failed to run $(escape3 "$@"), see *debug* buffer''''
				''
				'"
			} fi
			echo "evaluate-commands -client ${kak_client} $response" |
			kak -p ${kak_session}
		) >/dev/null 2>&1 </dev/null &
	}
}}

define-command -override my-git-with-commit -params 1.. %{ evaluate-commands -draft %{
	try my-git-select-commit
	my-git %arg{@}
}}
define-command -override my-git-autofixup %{
	my-git autofixup %{"$(fork-point.sh)"}
}
define-command -override my-git-autofixup-and-apply %{
	evaluate-commands %sh{
		git-autofixup "$(fork-point.sh)" --exit-code >&2
		if [ $? -ge 2 ]; then {
			echo "fail 'error running git-autofixup $(fork-point.sh)'"
		} fi
	}
	my-git -c sequence.editor=true revise -i --autosquash %{"$(fork-point.sh)"}
}
define-command -override my-git-revise -params .. %{ my-git-with-commit revise %arg{@} }
define-command -override my-git-log -params .. %{
	evaluate-commands %{
		try %{
			buffer *git-log*
			set-option global my_git_line %val{cursor_line}
		} catch %{
			set-option global my_git_line 1
		}
	}
	evaluate-commands -draft %{
		try %{
			buffer *git*
			rename-buffer *git*.bak
		}
	}
	try %{ delete-buffer *git-log* }
	git log --oneline %arg{@}
	hook -once buffer NormalIdle .* %{
		execute-keys %opt{my_git_line}g<a-h>
		execute-keys -draft \
		%{gk!} \
		%{git diff --quiet || echo "Unstaged changes";} \
		%{git diff --quiet --cached || echo "Staged changes";} \
		<ret>
	}
	rename-buffer *git-log*
	evaluate-commands -draft %{
		try %{
			buffer *git*.bak
			rename-buffer *git*
		}
	}
}
define-command -override my-git-log-default -params .. %{
	# my-git-log %exp{%sh{truth.sh}@{1}..} %arg{@}
	my-git-log %exp{%sh{truth.sh}..} %arg{@}
}
declare-option int my_git_line 1
define-command -override my-git-diff -params .. %{
	evaluate-commands -draft %{
		try %{
			buffer *git*
			set-option global my_git_line %val{cursor_line}
		} catch %{
			set-option global my_git_line 1
		}
	}
	try %{ delete-buffer *git* }
	nop %sh{ git diff "$@" > "/tmp/fixdiff.$kak_session" }
	edit -scratch *git*
	set-option buffer filetype git-diff
	try %{
		set-option buffer git_work_tree %sh{git rev-parse --show-toplevel}
		map buffer normal <ret> %{:require-module diff; diff-jump %opt{git_work_tree}<ret>}
	}
	execute-keys %{|cat /tmp/fixdiff.$kak_session<ret>}
	execute-keys %opt{my_git_line}g
}
define-command -override my-git-show -params .. %{
	nop %sh{
		git show "$@" > "/tmp/fixdiff.$kak_session"
	}
	git show %arg{@}
}
define-command -override my-git-range-diff -params .. %{
	try %{ delete-buffer *git-range-diff* }
	edit -scratch *git-range-diff*
	set-option buffer filetype git-range-diff
	execute-keys "|git range-diff --color %arg{@}<ret>"
	ansi-render
}
define-command -override my-fixdiff %{
	write -force "/tmp/fixdiff.%val{session}.new"
	nop %sh{
		fixdiff "/tmp/fixdiff.$kak_session" "/tmp/fixdiff.$kak_session.new" &&
		rm "/tmp/fixdiff.$kak_session.new"
	}
}
define-command -override my-git-branchstack -params .. %{
	my-git-with-commit \
	-c rerere.autoUpdate=true branchstack -r %{"$(truth.sh)"..} \
	%arg{@}
}
define-command -override my-git-branchstack-push %{ evaluate-commands -draft %{
	try my-git-select-commit
	evaluate-commands %sh{
		commit=${kak_selection}
		if ! branch=$(git branchstack-branch "$commit"); then {
			echo fail no branch
		} fi
		echo my-git -no-refresh -c rerere.autoUpdate=true branchstack -r '%{"$(truth.sh)"..}' "$branch"
		maybe_force=$(test "$branch" != master && printf %s --force)
		push_remote=$(git config branch."$branch".pushRemote \
		|| git config remote.pushDefault \
		|| echo origin)
		echo my-git -no-refresh push $maybe_force "$push_remote" "$branch"
	}
}}
define-command -override my-git-branchstack-yank-branch %{ evaluate-commands -draft %{
	my-git-select-commit
	evaluate-commands %sh{
		x=$(git branchstack-branch "${kak_selection}")
		printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
		printf %s "$x" | copy >/dev/null 2>&1
	}
}}

## tools
define-command -override my-ranger-connect -params .. %{
	terminal env "EDITOR=kak-remote-edit.sh %val{session} %val{client}" ranger %arg{@}
}
define-command -override my-ranger -params .. %{
	terminal env "EDITOR=kak -c %val{session}" ranger %arg{@}
}
define-command -override my-perldoc -params 1 %{
	edit -scratch *perldoc*
	execute-keys -draft '%d'
	evaluate-commands %sh{ echo "execute-keys %{|perldoc -f \"$1\"<ret>gk}" }
}
define-command -override my-pydoc -params 1 %{
	edit -scratch *pydoc*
	execute-keys -draft '%d'
	evaluate-commands %sh{ echo "execute-keys %{|pydoc \"$1\"<ret>gk}" }
}

## misc
define-command -override my-delete-buffers-matching -params 12 %{
	evaluate-commands %sh{
		cmd=delete-buffer
		if [ "$1" = -f ]; then {
			cmd=delete-buffer!
			shift
		} fi
		buffers_escaped=$(eval printf '%s\\n' "$kak_quoted_buflist" | grep "$@" | sed "s/'/''/g")
		if [ -z "$buffers_escaped" ]; then {
			echo fail no matching buffer
		} else {
			nl=$(printf '\n.')
			IFS=${nl%.}
			printf '%s\n' "$buffers_escaped" |
			while read bufname
			do {
				printf "$cmd '%s'\n" "$bufname"
			}; done
		} fi
	}
}
try %{ complete-command my-delete-buffers-matching buffer }
define-command -override my-client-only %{
	evaluate-commands %sh{
		eval set -- $kak_quoted_client_list
		for client
		do {
			if [ "$client" = "$kak_client" ] ||
			[ "$client" = "$kak_opt_toolsclient" ] ||
			[ "$client" = "$kak_opt_jumpclient" ] ||
			[ "$client" = "$kak_opt_docsclient" ]; then
			continue
			fi
			echo evaluate-commands -client "$client" quit
		} done
	}
}
define-command -override my-doc-key -docstring "show the documentation of a key in normal mode" %{
	# Read a single key.
	evaluate-commands -verbatim on-key %{
		# Switch to the documentation of keys, or open it.
		try %{
			buffer *doc-keys*
		} catch %{
			doc keys
		}
		# Jump to the line where this key is documented.
		evaluate-commands execute-keys %sh{
			kakquote() { printf %s "$*" | sed "s/'/''/g; 1s/^/'/; \$s/\$/'/"; }
			key=$(printf %s "$kak_key" |
			sed '
			s/<semicolon>/;/;
			s/-semicolon/-;/;
			s/</<lt>/;
			')
			kakquote "$(printf "/^\Q%s<ret>vv" "$key")"
		}
	}
}
define-command -override my-change-directory -params ..1 %{ cd %arg{@} }
try %{ complete-command -menu my-change-directory shell-script-candidates %{
	CDPATH=.:~:~/git
	IFS=: set -- $CDPATH
	find $@ -maxdepth 1 -type d -o -type l | sed s,^$HOME,~,
} }
define-command -override my-surround -docstring %{
	Surround all selections with the typed character. 
} %{
	on-key %{
		evaluate-commands %sh{
			left=$kak_key
			right=$kak_key
			pair() {
				( [ "$kak_key" = "$1" ] || [ "$kak_key" = "$2" ] ) && left=$1 && right=$2
			}
			pair '(' ')' || pair '[' ']' || pair '{' '}' || pair '<lt>' '<gt>'
			printf "execute-keys %%{i%s<esc>a%s<esc>}" "$left" "$right"
		}
	}
}
define-command -override my-indent-info %{
	info "
	aligntab(default=false): %opt{aligntab}
	tabstop(default=8):      %opt{tabstop}
	indentwidth(default=4)   %opt{indentwidth}

	[smarttab]
	smarttab_mode:		 %opt{smarttab_mode}
	softtabstop:             %opt{softtabstop}
	"
}
define-command -override my-complete-fish %{
	evaluate-commands -draft -save-regs /lc %{
		evaluate-commands -draft %{
			# try to guess the token start
			try %{
				execute-keys -draft h<a-h><a-k>\h\z<ret>
			} catch %{
				execute-keys <a-b>
			}
			set-register l "%val{cursor_line}.%val{cursor_column}@%val{timestamp}"
		}
		execute-keys <a-h>
		execute-keys s\A[^\n]*<ret>
		nop %sh{
			(
				fish -c 'complete -C "$argv"' -- "$kak_selection" | perl -ne '
				sub quote {
					$SQ = "'\''";
					$token = shift;
					$token =~ s/$SQ/$SQ$SQ/g;
					return "$SQ$token$SQ";
				}
				BEGIN {
					$cmd = "set-option " . quote("buffer=". $ENV{kak_bufname}) . " shell_completions $ENV{kak_reg_l}";
				}
				s/\\/\\/g; s/\|/\\|/g;
				m/([^\t]*)(?:\t([^\n]*))?/ or next;
				$text = $1;
				$description = "{\\}$2";
				$cmd .= " " . quote "$text||$text\t$description";
				END {
					print $cmd;
				}
				' | kak -p "$kak_session" >/dev/null 2>&1 &
			) >/dev/null 2>&1 </dev/null
		}
	}
}
define-command -override my-pop-register -params 1 %{
	evaluate-commands %sh{
		# kak_quoted_reg_colon
		# kak_quoted_reg_pipe
		# kak_quoted_reg_slash
		(
			printf %s "set-register $1"
			eval eval set -- \$kak_quoted_reg_$1
			shift
			printf " %s" "$@"
		) | tee /dev/stderr
	}
}

define-command -override my-hull %{
	evaluate-commands -save-regs ^ %{
		evaluate-commands -save-regs ab %{
			execute-keys %exp{%reg{hash}()}
			execute-keys '"aZ'
			execute-keys ,"bZ"az(,"b<a-z>u
			execute-keys -save-regs '' Z
		}
		execute-keys z
	}
}

## wrapping
define-command -override my-wrap -params 1 %{
	try %{
		add-highlighter "%arg{1}/my-wrap" wrap -word -indent -width %val{window_width} -marker ^
	} catch %{
		remove-highlighter "%arg{1}/my-wrap"
	}
}
define-command -override my-format-hooks %{
	hook -group my-format global BufWritePre .*(?:\.(?:c|cc|cpp|fish|h|java|kak|rs|smt|smt2|xml)|kakrc)$ format-buffer
	hook -group my-format global BufWritePre .*[.]go %{
		try %{ lsp-code-action-sync '^Organize Imports$' }
		lsp-formatting-sync
	}
}
define-command -override my-noformat-hooks %{
	remove-hooks global my-format
}

define-command -override my-makehl %{ evaluate-commands -draft %{ try %{
	buffer *make*
	add-highlighter buffer/make ref make
}}}
define-command -override my-nomakehl %{ evaluate-commands -draft %{ try %{
	buffer *make*
	remove-highlighter buffer/make
}}}
remove-hooks global make-highlight

## options
set-option global autoreload yes
set-option global autowrap_column 80
set-option global autowrap_fmtcmd 'fmt.sh -w %c'
set-option global fs_check_timeout 1000
set-option global grepcmd 'rg --vimgrep'
set-option global indentwidth 0
set-option global startup_info_version 20230901
# set-option global startup_info_version 99990101

declare-option completions shell_completions
try %{
	set-option -remove global completers option=shell_completions
}
set-option global completers option=shell_completions %opt{completers}

## hooks
try %{
	remove-hooks global my
	remove-hooks global my-cargo
	remove-hooks global my-editorconfig
	remove-hooks global my-format
	remove-highlighter global/my
	remove-highlighter global/my-number
}
add-highlighter global/my group
my-format-hooks
hook -group my-editorconfig global WinSetOption filetype=.* %{
	try %{
		editorconfig-load
		autoconfigtab
	}
	autowrap-disable
}
hook -group my global KakBegin .* %{
	evaluate-commands %sh{
		# Same as tmux-terminal but add -a to create the window next to the current one.
		if [ -n "$TMUX" ]; then
		printf %s '
		define-command -override tmux-terminal-window -params .. %{
			# add -a
			tmux-terminal-impl "new-window -a -t %sh{tmux display-message -p -t $kak_client_env_TMUX_PANE '\''#{client_session}'\''}:" %arg{@}
		}
		'
		fi
	}
}
hook -group my global ModuleLoaded x11 %{ set-option global termcmd 'konsole -e /bin/sh -c' }
hook -group my global ModuleLoaded sway|wayland %{ set-option global termcmd 'foot /bin/sh -c' }
hook -group my global BufCreate \*grep\* %{ alias buffer w my-find-apply-changes-force }
hook -group my global WinSetOption filetype=python %{
	set-option buffer formatcmd 'autopep8 -'
	set-option buffer lintcmd 'pylint'
	set-option buffer indentwidth 4
	set-option buffer tabstop 4
}
hook -group my global WinSetOption filetype=yaml %{
	set-option buffer indentwidth 2
	set-option buffer tabstop 2
}
hook -group my global BufCreate .*[.]gl|\*gl-issue\* %{
	set-option buffer filetype grep
	set-option buffer extra_word_chars '_' '-'
	set-option buffer comment_line >
	set-option buffer disabled_hooks "%opt{disabled_hooks}|my-editorconfig"
	declare-option str-list my_gl_static_words
	set-option buffer static_words %opt{my_gl_static_words}
	require-module diff
	add-highlighter -override buffer/my-gl-diff ref diff
	add-highlighter -override buffer/my-wrap wrap -word -indent -marker <
}
hook -group my global BufSetOption filetype=fish %{
	set-option buffer indentwidth 4
	set-option buffer tabstop 4
	set-option buffer formatcmd fish_indent
}
hook -group my global WinSetOption filetype=kak %{
	set-option buffer formatcmd kakfmt
}
hook -group my global WinSetOption filetype=(c|cpp|java|protobuf) %{
	set-option buffer formatcmd "clang-format -style=file -assume-filename=%val{buffile}"
}
hook -group my global WinSetOption filetype=go %{
	set-option buffer formatcmd gofmt
}
hook -group my global BufCreate .*\.prr %{
	set-option buffer filetype diff
}
hook -group my global BufCreate .*\.smt(?:lib|2|2.6)? %{
	set-option buffer filetype lisp
}
hook -group my global BufCreate .*\.xml %{
	set-option buffer filetype xml
}
hook -group my global BufCreate .*/todo %{
	set-option buffer filetype mail # hack-ish
}
hook -group my global WinSetOption filetype=lisp %{
	set-option buffer formatcmd smtfmt
}
hook -group my global WinSetOption filetype=xml %{
	set-option buffer formatcmd 'xmllint -format -recover /dev/stdin'
}
hook -group my global WinSetOption filetype=rust %{
	set-option buffer indentwidth 4
	set-option buffer tabstop 4
	set-option buffer formatcmd rustfmt
}
hook -group my-cargo global WinSetOption filetype=rust %{
	map buffer user m %{:write-all<ret>:cargo<c-p><ret><esc>} -docstring 'last cargo command'
	map global user j %{:cargo-next-error<ret><esc>} -docstring 'cargo next error'
	map global user k %{:cargo-previous-error<ret><esc>} -docstring 'cargo previous error'
	map global user n %{:enter-user-mode cargo<ret>} -docstring 'cargo...'
	map buffer make = %{:cargo format<ret>} -docstring 'cargo format'
	map buffer make j %{:cargo-next-error<ret>} -docstring 'next error'
	map buffer make k %{:cargo-previous-error<ret>} -docstring 'previous error'
	try %{
		map buffer buffers m %{:buffer *cargo*<ret>} -docstring *cargo*
	}
}
hook -group my global BufCreate .*/git-revise-todo %{
	set-option buffer filetype git-rebase
}
hook -group my global WinSetOption filetype=git-rebase %{
	# map window normal <ret> :my-git-enter<ret>
	set-option buffer extra_word_chars '_' '-'
}
hook -group my global WinSetOption filetype=(diff|git-diff|git-commit|mail) %{
	set-option buffer autowrap_column 72
}
hook -group my global WinSetOption filetype=git-log %{
	# map buffer normal <ret> :my-git-enter<ret>
	# hook -once -always window WinSetOption filetype=.* %{
	# 	unmap buffer normal <ret> :my-git-enter<ret>
	# }
}
hook -group my global BufCreate \*git\* %{
	alias buffer w my-fixdiff
	alias buffer buffers-pop git-stack-pop
	alias buffer buffers-clear git-stack-clear
}
hook -group my global WinDisplay \*git\* %{
	git-stack-push
}
hook -group my global BufCreate .*/todo %{
	set-option buffer disabled_hooks "%opt{disabled_hooks}|file-detection"
}
hook -group my global BufCreate .*/\.gitsendemail\.msg\.\w* %{
	execute-keys -draft %{]p<a-!>cat compose.eml<ret><a-o>}
	write
}
hook -group my global BufClose \*git(-diff|-show)?\* %{
	nop %sh{
		rm -f "/tmp/fixdiff.$kak_session"
	}
}
try %{ set-option global autocomplete insert|prompt|no-regex-prompt }
# set-option global disabled_hooks (?:.*)-insert|grep-jump|(?!grep)(?!lsp-goto)(?:.*)-highlight
set-option global disabled_hooks (?:.*)-insert|grep-jump
hook -group my global WinDisplay \*(?:callees|callers|diagnostics|goto|find|grep|implementations|lint-output|references)\*(?:-\d+)? %{
	grep-stack-push
}
hook -group my global WinDisplay .*[.]gl %{
	set-option global my_gl_buffer %val{bufname}
}
hook global WinSetOption filetype=sh %{
	set-option buffer lintcmd "shellcheck -fgcc -Cnever"
	set-option buffer extra_word_chars '_' '-'
}

define-command -override my-write -params .. -docstring %{
	write [<switches>] [<filename>]: write the current buffer to its file or to <filename> if specified
	Switches:
	-sync         force the synchronization of the file onto the filesystem
	-method <arg> explicit writemethod (replace|overwrite)
} %{
	write -force %arg{@}
}
try %{ complete-command my-write file }

## global aliases

# Most default aliases are obsoleted by interactive completion.
# Still, let's keep them for now because some plugins rely on them.

alias global m my-make
alias global g my-grep
alias global f my-find
alias global rb rename-buffer
alias global rs rename-session
alias global w my-write

alias global buffers-pop grep-stack-pop
alias global buffer-clear grep-stack-clear

# A file path with line and optional column.
set-register f (?:\w:)?[^:]+:\d+(?::\d+)?:[^\n]*
# Global Go symbol.
set-register g ^(var|func|type)[^\n]*?
# C/C++ style comments.
set-register c \s*/\*([^*]|[\r\n]|(\*+([^*/]|[\r\n])))*\*+/|//[^\n"`]*\n
# Multi-line parenthesized expression.
set-register p ^\([^\n]*[^)]\n.*?(?=\n\()
set-register n [^\n]
set-register i (?i)

set-face global SnippetsNextPlaceholders bright-white,black+F
set-face global SnippetsOtherPlaceholders white,black+F
set-face global PhantomSelection bright-white,black+F

## keys
map global goto g c -docstring 'window center'
map global goto c <esc>:my-comment<ret> -docstring '(un)comment lines'
map global goto h <esc>:clangd-switch-source-header<ret> -docstring "clangd switch source/header"
map global goto n <esc>:my-grep-next-match<ret> -docstring 'grep-next-match'
map global goto o <esc>:my-copy-and-comment<ret> -docstring 'copy and comment'
map global goto p <esc>:my-grep-previous-match<ret> -docstring 'grep-previous-match'
map global goto v <esc>:my-goto-file<ret> -docstring 'file:line:col at cursor'

map global insert <c-[> <esc>
map global insert <c-j> <ret>
map global insert <c-f> <a-semicolon>:my-complete-fish<ret>
map global insert <c-s> <c-r>"
map global insert <c-q> <c-v>
map global insert <c-v> <esc><semicolon>:my-clipboard-paste<ret>a

map global normal <a-percent> %{:my-hull<ret>}
map global normal <c-h> %{:my-git-enter<ret>}
map global normal <c-l> %{:my-yank-buffile-relative-and-line<ret>} -docstring 'copy relative buffer file path and line'
map global normal <c-|> %{:my-pop-register pipe<ret>} -docstring 'pop-register pipe'
map global normal <c-/> %{:my-pop-register slash<ret>} -docstring 'pop-register slash'
map global normal <c-_> %{:my-pop-register slash<ret>} -docstring 'pop-register slash'
map global normal <c-n> %{:lsp-next-location %opt{my_grep_buffer}<ret>} -docstring 'lsp next'
map global normal <c-p> %{:lsp-previous-location %opt{my_grep_buffer}<ret>} -docstring 'lsp previous'
map global normal <c-r> %{:buffers-pop<ret>} -docstring 'pop grep/git buffer'
map global normal <c-v> :my-clipboard-paste<ret>
map global normal <c-y> %{:my-clipboard-yank<ret>}
map global normal = %{|fmt.sh -w $kak_opt_autowrap_column<ret>}
map global normal "'" %{:enter-buffers-mode<ret>} -docstring "buffers..."
map global user g %{:enter-user-mode git<ret>} -docstring 'git...'

map global normal <c-B> ':execute-keys %val{window_height}K<ret>'
map global normal <c-F> ':execute-keys %val{window_height}J<ret>'
map global normal <c-U> ':execute-keys %sh{echo $(($kak_window_height / 2))}K<ret>'
map global normal <c-D> ':execute-keys %sh{echo $(($kak_window_height / 2))}J<ret>'

map global view u '<esc>:execute-keys %sh{echo $(($kak_window_height / 2))} vkv<ret>' -docstring 'scroll half page up'
map global view d '<esc>:execute-keys %sh{echo $(($kak_window_height / 2))} vjv<ret>' -docstring 'scroll half page down'
map global view <c-b> '<esc>:execute-keys %val{window_height} vkv<ret>' -docstring 'scroll one page up'
map global view <c-f> '<esc>:execute-keys %val{window_height} vjv<ret>' -docstring 'scroll one page down'

map global view V '<a-semicolon>:set-option current windowing_placement vertical<ret>' -docstring 'place future windows in vertical split'
map global view B '<a-semicolon>:set-option current windowing_placement horizontal<ret>' -docstring 'place future windows in horizontal split'
map global view w '<a-semicolon>:set-option current windowing_placement window<ret>' -docstring 'place future windows in separate window'
map global view T '<a-semicolon>:set-option current windowing_placement tab<ret>' -docstring 'place future windows in a new tab'

map global object m %{c^[<lt>=|]{4\,}[^\n]*\n,^[<gt>=|]{4\,}[^\n]*\n<ret>} -docstring 'conflict markers'
map global object r p -docstring 'paragraph'
map global object R p -docstring 'paragraph'

map global prompt <c-[> <esc>
map global prompt <c-j> <ret>
map global prompt <c-s> <c-r>"
map global prompt <c-q> <c-v>
map global prompt <c-v> %{<a-semicolon>:my-clipboard-paste-prompt<ret><c-r>t}

map global user / /(?S)(?i) -docstring 'search'
map global user <a-/> <a-/>(?S)(?i) -docstring 'search (extend)'
map global user ? ?(?S)(?i) -docstring 'backwards search (extend)'
map global user <a-?> <a-?>(?S)(?i) -docstring 'backwards search (extend)'
map global user e %{: my-colon-edit } -docstring 'edit <filename>[:<line>[:<column>]]'
map global user <a-e> %{: edit %sh{git rev-parse --show-toplevel}<a-!>/} -docstring 'edit (project root)'
map global user E %{:my-edit-sibling<ret>} -docstring 'edit in current buffer directory'
map global user f %{: my-find-edit } -docstring "edit (fuzzy completion with all files)"
map global user y %{:my-yank-buffile-relative<ret>} -docstring 'copy relative buffer file path'
map global user <c-y> %{:my-yank-buffile-relative-and-line<ret>} -docstring 'copy relative buffer file path and line'

map global user '"' %{:with-option windowing_placement vertical new<ret>}
map global user '%' %{:with-option windowing_placement horizontal new<ret>}
map global user c %{:with-option windowing_placement window new<ret>} -docstring "new"
map global user C %{:with-option windowing_placement tab new<ret>} -docstring "new tab"
map global user 1 %{:new<ret>} -docstring "new"

map global user 2 %{:my-rename-buffile<ret>} -docstring 'rename current buffer file'
map global user 3 %{:my-doc-key<ret>}
map global user 4 %{: repl-buffer-new } -docstring 'repl-buffer-new...'
map global user <a-r> %{:my-ranger-connect .<ret>} -docstring 'ranger connect'
map global user <a-R> %{:my-ranger-connect %sh{dirname "$kak_buffile"}<ret>} -docstring 'ranger connect (in buffer directory)'
map global user b %{: buffer } -docstring 'buffer...'
map global user <c-l> <c-l>
map global user <minus> %{: execute-keys -draft -with-maps <lt>a-a>p=<ret>} -docstring 'hard-wrap paragraph'
map global user = %{:format<ret>} -docstring 'format'
map global user h %{:enter-user-mode reference<ret>} -docstring 'help...'
map global user i %{:enter-user-mode snippets<ret>} -docstring 'snippets...'
map global user I %{:my-indent-info<ret>}
map global user j %{:make-next-error<ret><esc>} -docstring 'next error'
map global user k %{:make-previous-error<ret><esc>} -docstring 'previous error'
map global user m %{:write-all<ret>:m <c-p><ret><esc>} -docstring 'make'
map global user n %{:enter-user-mode -lock make<ret>} -docstring 'make...'
map global user o %{:enter-user-mode toggle<ret>} -docstring 'toggle...'
map global user Q %{:kill<ret>} -docstring 'kill'
map global user q %{:quit<ret>} -docstring 'quit'
map global user r %{:my-ranger .<ret>} -docstring 'ranger'
map global user R %{:my-ranger %sh{dirname "$kak_buffile"}<ret>} -docstring 'ranger (in buffer directory)'
try %{ map global user s %{:source "%val{config}/kakrc"<ret>} -docstring 'source "%val{config}/kakrc"' }
map global user t %{:tig<ret>} -docstring "tig"
map global user u %{:my-surround<ret>} -docstring 'surround'
map global user U %{:surround-enter-insert-mode<ret>} -docstring 'surround (insert mode)'
map global user v %{:evaluate-commands -- %reg{.}<ret>} -docstring 'evaluate selection'
map global user V %{<a-|> sh -c 'in=$(cat); swaymsg "$in"'<ret>} -docstring 'swaymsg selection'
map global user w %{:w<ret>} -docstring 'write'
map global user x %{:nop %sh{chmod +x "$kak_buffile"}<ret>} -docstring 'chmod +x'
map global user Y %{:my-yank-buffile<ret>} -docstring 'copy absolute buffer file path'

# My user modes

map global git 1 %{:my-conflict-1<ret>} -docstring "conflict: use ours"
map global git 2 %{:my-conflict-2<ret>} -docstring "conflict: use theirs"
map global git a %{:enter-user-mode git-apply<ret>} -docstring "apply selection..."
map global git b %{:enter-user-mode git-blame<ret>} -docstring "blame..."
map global git B %{:enter-user-mode git-bisect<ret>} -docstring 'bisect...'
map global git A %{:enter-user-mode git-cherry-pick<ret>} -docstring 'cherry-pick...'
map global git c %{:enter-user-mode git-commit<ret>} -docstring "commit..."
map global git d %{:enter-user-mode git-diff<ret>} -docstring "diff..."
map global git e %{:my-git-edit } -docstring "edit..."
map global git E %{:my-git-edit-root } -docstring "edit (repo root)..."
map global git f %{:enter-user-mode git-fetch<ret>} -docstring 'fetch...'
map global git F %{:gl-fetch<ret>} -docstring 'gl fetch'
map global git g %{:enter-user-mode git-branchstack<ret>} -docstring 'branchstack...'
map global git l %{:my-git-log-default<ret>} -docstring 'log'
map global git L %{:my-git-log } -docstring 'log'
map global git m %{:enter-user-mode git-am<ret>} -docstring 'am...'
map global git M %{:enter-user-mode git-merge<ret>} -docstring 'merge...'
map global git o %{:enter-user-mode git-reset<ret>} -docstring "reset..."
map global git p %{:enter-user-mode git-push<ret>} -docstring 'push...'
map global git r %{:enter-user-mode git-rebase<ret>} -docstring "rebase..."
map global git s %{:my-git-show<ret>} -docstring 'git show'
map global git t %{:enter-user-mode git-revert<ret>} -docstring "revert..."
map global git u %{:enter-user-mode git-gl<ret>} -docstring 'gl...'
map global git v %{:enter-user-mode git-revise<ret>} -docstring "revise..."
map global git W %{:w<ret>: git add -f -- "%val{buffile}"<ret>} -docstring "write - Write and stage the current file (force)"
map global git w %{:w<ret>: git add -- "%val{buffile}"<ret>} -docstring "write - Write and stage the current file"
map global git y %{:enter-user-mode git-yank<ret>} -docstring "yank..."
map global git z %{:enter-user-mode git-stash<ret>} -docstring "stash..."

map global git-am a %{:my-git am --abort<ret>} -docstring 'abort'
map global git-am r %{:my-git am --continue<ret>} -docstring 'continue'
map global git-am s %{:my-git am --skip<ret>} -docstring 'skip'

map global git-apply a %{:git apply<ret>} -docstring 'apply'
map global git-apply 3 %{:git apply --3way<ret>} -docstring 'apply using 3way merge'
map global git-apply r %{:git apply --reverse<ret>} -docstring 'reverse'
map global git-apply s %{:git apply --cached<ret>} -docstring 'stage'
map global git-apply u %{:git apply --reverse --cached<ret>} -docstring 'unstage'
map global git-apply i %{:git apply --index<ret>} -docstring 'apply to worktree and index'

map global git-bisect B %{:my-git-with-commit bisect bad %{"$commit"}<ret>}
map global git-bisect G %{:my-git-with-commit bisect good %{"$commit"}<ret>}

map global git-blame t %{:tig-blame-here<ret>} -docstring "tig blame"
map global git-blame s %{:tig-blame-selection<ret>} -docstring "tig blame selection"
map global git-blame a %{:git blame<ret>} -docstring "git blame"
map global git-blame b %{:git blame-jump<ret>} -docstring "git blame-jump"

map global git-branchstack s %{:my-git-branchstack %{"$(git branchstack-branch "$commit")"}<ret>} -docstring "export as branch"
map global git-branchstack f %{:my-git-branchstack %{"$(git branchstack-branch "$commit")"} --force<ret>} -docstring "export as branch (force)"
map global git-branchstack b %{:my-git-branchstack-yank-branch<ret>} -docstring "yank branch name"
map global git-branchstack p %{:my-git-branchstack-push<ret>} -docstring "push branch"

map global git-cherry-pick a %{:my-git cherry-pick --abort<ret>} -docstring 'abort'
map global git-cherry-pick p %{:my-git-with-commit cherry-pick %{"$commit"}<ret>} -docstring 'cherry-pick commit'
map global git-cherry-pick r %{:my-git cherry-pick --continue<ret>} -docstring 'continue'
map global git-cherry-pick s %{:my-git cherry-pick --skip<ret>} -docstring 'skip'

map global git-commit a %{:my-git commit --amend<ret>} -docstring 'amend'
map global git-commit A %{:my-git commit --amend --all<ret>} -docstring 'amend all'
map global git-commit r %{:my-git commit --amend --reset-author<ret>} -docstring 'amend resetting author'
map global git-commit c %{:my-git commit<ret>} -docstring 'commit'
map global git-commit C %{:my-git commit --all<ret>} -docstring 'commit all'
map global git-commit F %{:my-git commit --fixup=} -docstring 'fixup...'
map global git-commit f %{:my-git-fixup<ret>} -docstring 'fixup commit at cursor'
map global git-commit u %{:my-git-autofixup<ret>} -docstring 'autofixup'
map global git-commit o %{:my-git-autofixup-and-apply<ret>} -docstring 'autofixup and apply'

map global git-diff d %{:my-git-diff<ret>} -docstring "Show unstaged changes"
map global git-diff s %{:my-git-diff --staged<ret>} -docstring "Show staged changes"
map global git-diff h %{:my-git-diff HEAD<ret>} -docstring "Show changes between HEAD and working tree"
map global git-diff S %{:git status<ret>} -docstring "Show status"

map global git-fetch f %{:my-git pull --rebase<ret>} -docstring 'pull'
map global git-fetch a %{:my-git fetch --all<ret>} -docstring 'fetch all'
map global git-fetch o %{:my-git fetch origin<ret>} -docstring 'fetch origin'

map global git-merge a %{:my-git merge --abort<ret>} -docstring 'abort'
map global git-merge m %{:my-git-with-commit merge %{"$commit"}<ret>} -docstring 'merge'
map global git-merge r %{:my-git merge --continue<ret>} -docstring 'continue'
map global git-merge s %{:my-git merge --skip<ret>} -docstring 'skip'

map global git-push p %{:my-git push<ret>} -docstring 'push'
map global git-push f %{:my-git push --force<ret>} -docstring 'push --force'
map global git-push m %{:my-git-with-commit push %{"$(git config branch.master.pushRemote || git config remote.pushDefault || echo origin)"} %{"${commit}":master}<ret>} -docstring 'push commit to master'

map global git-rebase a %{:my-git rebase --abort<ret>} -docstring 'abort'
map global git-rebase b %{:my-git-with-commit rerebase %{"$commit"^}<ret>} -docstring 'rerebase'
map global git-rebase e %{:my-git rebase --edit-todo<ret>} -docstring 'edit todo'
map global git-rebase i %{:my-git-with-commit rebase --interactive %{"${kak_selection}"^}<ret>} -docstring 'interactive rebase commit'
map global git-rebase r %{:my-git rebase --continue<ret>} -docstring 'continue'
map global git-rebase s %{:my-git rebase --skip<ret>} -docstring 'skip'
map global git-rebase u %{:my-git rebase --interactive<ret>} -docstring 'interactive rebase'

map global git-reset o %{:my-git-with-commit reset %{"$commit"}<ret>} -docstring 'mixed reset'
map global git-reset s %{:my-git-with-commit reset --soft %{"$commit"}<ret>} -docstring 'soft reset'
map global git-reset O %{:my-git-with-commit reset --hard %{"$commit"}<ret>} -docstring 'hard reset'

map global git-revert a %{:my-git revert --abort<ret>} -docstring 'abort'
map global git-revert t %{:my-git-with-commit revert %{"$commit"}<ret>} -docstring 'revert'
map global git-revert r %{:my-git revert --continue<ret>} -docstring 'continue'
map global git-revert s %{:my-git revert --skip<ret>} -docstring 'skip'

map global git-revise a %{:my-git-revise --reauthor %{"$commit"}<ret>} -docstring 'reauthor'
map global git-revise e %{:my-git-revise --interactive --edit %{"$(fork-point.sh)"}<ret>} -docstring 'edit all since fork-point'
map global git-revise E %{:my-git-revise --interactive --edit %{"$commit"^}<ret>} -docstring 'edit all since commit'
map global git-revise f %{:my-git-revise %{"$commit"}<ret>} -docstring 'fixup selected commit'
map global git-revise i %{:my-git-revise --interactive %{"${kak_selection}^"}<ret>} -docstring 'interactive %(commit)'
map global git-revise u %{:my-git-revise --interactive %{"$(fork-point.sh)"}<ret>} -docstring 'interactive %{upstream}'
map global git-revise w %{:my-git-revise --edit %{"$commit"}<ret>} -docstring 'edit'

map global git-yank a %{:my-git-yank '%aN <lt>%aE>'<ret>} -docstring 'copy author'
map global git-yank m %{:my-git-yank '%s%n%n%b'<ret>} -docstring 'copy message'
map global git-yank c %{:my-git-yank-commit<ret>} -docstring 'copy commit'
map global git-yank r %{:my-git-yank-reference<ret>} -docstring 'copy pretty commit reference'

map global git-stash z %{:my-git stash push<ret>} -docstring 'push'
map global git-stash p %{:my-git stash pop<ret>} -docstring 'pop'

map global git-gl a %{Z<a-/>^(?:> )?\<plus><ret>x1s^(?:> )?\<plus>([^\n]*)<ret>yzpi```suggestion<ret><esc><semicolon>o```<esc>kx} -docstring "gl suggestion"
map global git-gl d %{:gl-discuss<ret>} -docstring 'gl discuss'
map global git-gl f %{:gl-fetch<ret>} -docstring 'gl fetch'
map global git-gl s %{:gl-submit<ret>} -docstring 'gl submit'
map global git-gl u %{:gl-url<ret>} -docstring 'gl url'
map global git-gl v %{:gl-visit } -docstring "gl visit"

map global make s %{:set global makecmd ''<c-b><esc>} -docstring 'set makecmd'
map global make j %{:make-next-error<ret>} -docstring 'next error'
map global make k %{:make-previous-error<ret>} -docstring 'previous error'
map global make n %{<esc>:gl-next<ret><esc>} -docstring 'gl next discussion'
map global make p %{<esc>:gl-previous<ret><esc>} -docstring 'gl previous discussion'

map global reference m %{<a-i>w:man %val{selection}<ret>} -docstring 'man page'
map global reference p %{<a-i>w:my-perldoc %val{selection}<ret>} -docstring 'perldoc'
map global reference y %{<a-i>w:my-pydoc %val{selection}<ret>} -docstring 'perldoc'

map global snippets s %{or<esc>/^[\S]*:\d+:<ret>} -docstring 'resolve thread'

map global toggle A %{:ansi-clear; ansi-disable<ret>} -docstring 'ansi-clear & ansi-disable'
map global toggle a %{:ansi-render; ansi-enable<ret>} -docstring 'ansi-render & ansi-enable'
map global toggle c %{:colorscheme default<ret>} -docstring 'colorscheme default'
map global toggle C %{:colorscheme black-on-white<ret>} -docstring 'colorscheme black-on-white'
map global toggle D %{:set-option global docsclient ''<ret>} -docstring 'unset docsclient'
map global toggle d %{:set-option global docsclient %val{client}<ret>} -docstring 'set as docsclient'
map global toggle g %{:lsp-indent-guides-enable global<ret>} -docstring 'indent guides'
map global toggle G %{:lsp-indent-guides-disable global<ret>} -docstring 'no indent guides'
map global toggle f %{:my-format-hooks<ret>} -docstring 'format on save'
map global toggle F %{:my-noformat-hooks<ret>} -docstring 'don''t format on save'
map global toggle i %{:lsp-inlay-diagnostics-enable global<ret>} -docstring 'enable LSP inlay diagnostics'
map global toggle I %{:lsp-inlay-diagnostics-disable global<ret>} -docstring 'disable LSP inlay diagnostics'
map global toggle h %{:lsp-inlay-hints-enable global<ret>} -docstring 'enable LSP inlay hints'
map global toggle H %{:lsp-inlay-hints-disable global<ret>} -docstring 'disable LSP inlay hints'
map global toggle J %{:set-option global jumpclient ''<ret>} -docstring 'unset jumpclient'
map global toggle j %{:set-option global jumpclient %val{client}<ret>} -docstring 'set as jumpclient'
map global toggle l %{:set-option global incsearch true<ret>} -docstring 'incsearch'
map global toggle L %{:set-option global incsearch false<ret>} -docstring 'no incsearch'
map global toggle o %{:my-lsp-debug<ret>} -docstring 'LSP debug log'
map global toggle O %{:my-lsp-no-debug<ret>} -docstring 'LSP no debug log'
map global toggle m %{:set-option global autocomplete insert|prompt|no-regex-prompt<ret>} -docstring "enable insert mode autocompletion"
map global toggle M %{:set-option global autocomplete prompt|no-regex-prompt<ret>} -docstring "disable insert mode autocompletion"
map global toggle n %{:add-highlighter global/my-number number-lines -hlcursor<ret>} -docstring "line numbers"
map global toggle N %{:remove-highlighter global/my-number<ret>} -docstring "no line number"
map global toggle R %{:autowrap-disable<ret>} -docstring 'no autowrap'
map global toggle r %{:autowrap-enable<ret>} -docstring 'autowrap'
map global toggle s %{:add-highlighter global/my-show-whitespaces show-whitespaces<ret>} -docstring 'spaces'
map global toggle S %{:remove-highlighter global/my-show-whitespaces<ret>} -docstring 'no spaces'
map global toggle T %{:set-option global toolsclient ''<ret>} -docstring 'unset toolsclient'
map global toggle t %{:set-option global toolsclient %val{client}<ret>} -docstring 'set as toolsclient'
map global toggle W %{:my-wrap buffer<ret>} -docstring 'wrap (buffer)'
map global toggle w %{:my-wrap global<ret>} -docstring 'wrap'

