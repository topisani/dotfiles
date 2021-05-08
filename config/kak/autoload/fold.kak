decl range-specs folded_ranges
addhl global/folded_ranges replace-ranges folded_ranges

def fold-selections -override %{
  eval -itersel %{
    set -add window folded_ranges "%val[selection_desc]|{Folded}[...]"  
  }
}

def fold-clear -override %{
  set window folded_ranges %val[timestamp]
}

alias global fold fold-selections
