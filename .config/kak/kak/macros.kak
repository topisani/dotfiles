
def snake-to-camel -override %{
    exec -draft "S_<ret><a-;>;<a-`>h<a-k>_<ret>d"
    # Make sure the entire string is selected
    exec "<a-;>H<a-;>"
}

def format-table -override %{
   eval -draft %[
     exec %[ <a-i>p ]
     exec -draft %[ s\h*\|\h*<ret>c<space>|<space><esc> %]
     exec -draft %[ s\|<ret>& %]
   ]
}

