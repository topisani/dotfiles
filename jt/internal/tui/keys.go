package tui

import "charm.land/bubbles/v2/key"

// keyMap is every board binding. The footer and the help overlay are generated
// from it, so what's documented is what's bound.
type keyMap struct {
	Up, Down, First, Last   key.Binding
	ScrollDown, ScrollUp    key.Binding
	NextTab, PrevTab        key.Binding
	Full, Esc, Enter        key.Binding
	Filter, FilterN, Search key.Binding
	Tree                    key.Binding
	Help, Refresh, Quit     key.Binding
	Graph, Jjui, Copy, Undo key.Binding
	New, Edit, Status, Prio key.Binding
	Scope, Waits            key.Binding
	Start, Done, Accept     key.Binding
	Block, Defer, Reopen    key.Binding
	Decide, Strip           key.Binding
	PageDown, PageUp        key.Binding
	Left, Right             key.Binding
}

func bind(help, desc string, keys ...string) key.Binding {
	return key.NewBinding(key.WithKeys(keys...), key.WithHelp(help, desc))
}

// hint is a binding that only exists to be displayed.
func hint(help, desc string) key.Binding { return bind(help, desc, help) }

var keys = keyMap{
	Up:         bind("j/k", "move", "k", "up"),
	Down:       bind("j/k", "move", "j", "down"),
	First:      bind("g/G", "first/last", "g", "home"),
	Last:       bind("g/G", "first/last", "G", "end"),
	ScrollDown: bind("J/K", "scroll pane", "J", "ctrl+d", "pgdown"),
	ScrollUp:   bind("J/K", "scroll pane", "K", "ctrl+u", "pgup"),
	NextTab:    bind("tab", "next pane", "tab", "l", "right"),
	PrevTab:    bind("h/l", "switch pane", "shift+tab", "h", "left"),
	Full:       bind("enter", "full-screen", "enter"),
	Esc:        bind("esc", "back", "esc"),
	Enter:      bind("enter", "choose", "enter"),
	Tree:       bind("t", "tree/lanes", "t"),
	Filter:     bind("f", "filter", "f"),
	FilterN:    bind("1-4", "pick filter", "1", "2", "3", "4"),
	Search:     bind("/", "search", "/"),
	Help:       bind("?", "help", "?"),
	Refresh:    bind("r", "refresh", "r"),
	Quit:       bind("q", "quit", "q"),
	Graph:      bind("v", "graph", "v"),
	Jjui:       bind("O", "open in jjui", "O"),
	Copy:       bind("y", "copy id", "y"),
	Undo:       bind("u", "undo jj op", "u"),
	New:        bind("n", "new", "n"),
	Edit:       bind("e", "edit in $EDITOR", "e"),
	Status:     bind("s", "status", "s"),
	Prio:       bind("p", "priority", "p"),
	Scope:      bind("o", "scope", "o"),
	Waits:      bind("w", "waits on", "w"),
	Start:      bind("S", "start", "S"),
	Done:       bind("d", "done", "d"),
	Accept:     bind("a", "accept", "a"),
	Block:      bind("b", "block", "b"),
	Defer:      bind("D", "defer", "D"),
	Reopen:     bind("R", "reopen", "R"),
	Decide:     bind("B", "decide", "B"),
	Strip:      bind("x", "strip trailers", "x"),
	PageDown:   bind("space", "page down", "ctrl+d", "pgdown", "space"),
	PageUp:     bind("ctrl+u", "page up", "ctrl+u", "pgup"),
	Left:       bind("h/l", "pan", "h", "left"),
	Right:      bind("h/l", "pan", "l", "right"),
}

// shortHelp is the footer for the board.
func (k keyMap) shortHelp(testing bool) []key.Binding {
	out := []key.Binding{k.Up, k.NextTab, k.Tree, k.Search, k.Filter, k.New, k.Start, k.Status, k.Prio, k.Edit, k.Done, k.Decide, k.Graph, k.Help, k.Quit}
	if testing {
		return append([]key.Binding{k.Accept, k.Reopen}, out...)
	}
	return out
}

// fullHelp is the help overlay, one slice per column.
func (k keyMap) fullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Up, k.First, k.PrevTab, k.ScrollDown, k.Full, k.Search, k.FilterN, k.Filter},
		{k.Tree, k.Graph, k.Jjui, k.Refresh, k.Copy, k.Undo, k.Help, k.Quit},
		{k.New, k.Edit, k.Status, k.Prio, k.Scope, k.Waits},
		{k.Start, k.Done, k.Accept, k.Reopen, k.Block, k.Defer, k.Decide, k.Strip},
	}
}
