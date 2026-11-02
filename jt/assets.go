package main

import (
	"embed"
	"text/template"
)

//go:embed assets
var assets embed.FS

func asset(name string) string {
	data, err := assets.ReadFile("assets/" + name)
	if err != nil {
		panic(err)
	}
	return string(data)
}

var briefTemplate = template.Must(template.New("brief").Parse(asset("brief.md.tmpl")))

// slashCommands are installed as /jt:<name>. strip is gone from this list: it was
// a slash command wrapping one deterministic call, so it spent a model turn on
// what `jt strip` does directly. obsoleteCommands get removed on install.
var (
	slashCommands    = []string{"file", "board", "start", "burst", "decide", "cleanup"}
	obsoleteCommands = []string{"strip"}
)
