def diff -params 1..2  -override -file-completion -docstring \
"Usage: diff [file1] file2
Show diff between two files.
If only one file is provided, the current buffile
is used for the first argument" \
%{ eval %sh{
    in1="$kak_buffile"
    if [[ $# == 2 ]]; then
        in1="$1"
        shift
    fi
    in2="$1"

    echo "edit -scratch '*diff-$in1-$in2*'"
    echo "set buffer filetype diff"
    echo "exec %[!diff -u $in1 $in2<ret>]"
}}

