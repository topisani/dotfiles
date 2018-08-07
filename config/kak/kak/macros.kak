
def snake-to-camel -override %{
    exec -draft "S_<ret><a-;>;<a-`>h<a-k>_<ret>d"
    # Make sure the entire string is selected
    exec "<a-;>H<a-;>"
}
