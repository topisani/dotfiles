function __jt_ids
    jt json -a 2>/dev/null | string replace -rf '.*"id":"([^"]*)".*"summary":"([^"]*)".*' '$1\t$2'
end

complete -c jt -f
complete -c jt -n __fish_use_subcommand -a list    -d 'board of open tasks'
complete -c jt -n __fish_use_subcommand -a json    -d 'board as JSONL'
complete -c jt -n __fish_use_subcommand -a new     -d 'file a task'
complete -c jt -n __fish_use_subcommand -a show    -d 'full description'
complete -c jt -n __fish_use_subcommand -a set     -d 'update trailers'
complete -c jt -n __fish_use_subcommand -a start   -d 'claim, rebase onto work tip, edit'
complete -c jt -n __fish_use_subcommand -a done    -d 'mark done, off the default board'
complete -c jt -n __fish_use_subcommand -a strip   -d 'strip trailers, leaves the board'
complete -c jt -n __fish_use_subcommand -a block   -d 'mark blocked, with a reason'
complete -c jt -n __fish_use_subcommand -a defer   -d 'mark deferred, with a reason'
complete -c jt -n __fish_use_subcommand -a evo     -d 'evolution trail'
complete -c jt -n __fish_use_subcommand -a tip     -d 'current work tip'
complete -c jt -n __fish_use_subcommand -a grind   -d 'run batches unattended, fresh context each'
complete -c jt -n __fish_use_subcommand -a install -d 'write Claude commands + completions'

complete -c jt -n '__fish_seen_subcommand_from show set start done strip block defer evo' -a '(__jt_ids)'
complete -c jt -n '__fish_seen_subcommand_from list json' -s a -l all -d 'include done tasks'
complete -c jt -n '__fish_seen_subcommand_from json' -s q -l brief -d 'drop bodies'
complete -c jt -n '__fish_seen_subcommand_from new' -s p -l priority -d 'priority' -x -a 'P0 P1 P2 P3'
complete -c jt -n '__fish_seen_subcommand_from new' -s s -l scope -d 'files it touches' -x
complete -c jt -n '__fish_seen_subcommand_from new' -s b -l blocked-by -d 'blocked by task' -x -a '(__jt_ids)'
complete -c jt -n '__fish_seen_subcommand_from new' -l body -d 'body text' -x
complete -c jt -n '__fish_seen_subcommand_from install' -l dir -d 'Claude commands dir' -x -a '(__fish_complete_directories)'
complete -c jt -n '__fish_seen_subcommand_from install' -s n -l dry-run -d 'show what would be written'
complete -c jt -n '__fish_seen_subcommand_from grind' -s r -l rounds -d 'max batches' -x
complete -c jt -n '__fish_seen_subcommand_from grind' -s C -l dir -d 'workspace to run in' -x -a '(__fish_complete_directories)'
complete -c jt -n '__fish_seen_subcommand_from grind' -l model -d 'model per batch' -x -a 'fable opus sonnet haiku'
complete -c jt -n '__fish_seen_subcommand_from grind' -l budget -d 'per-round spend cap (USD)' -x
complete -c jt -n '__fish_seen_subcommand_from grind' -l command -d 'slash command per batch' -x
complete -c jt -n '__fish_seen_subcommand_from grind' -l log -d 'log dir' -x -a '(__fish_complete_directories)'
complete -c jt -n '__fish_seen_subcommand_from grind' -l here -d 'allow the default workspace'
complete -c jt -n '__fish_seen_subcommand_from grind' -s n -l dry-run -d 'show what would run'
