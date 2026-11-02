# Uncharted Lap

A small trading game in the spirit of *Uncharted Waters: New Horizons*, made with Godot 4.5. Sail between 12 ports, trade 14 goods, hire a crew and cartographers to chart new seas, fight or outrun pirates, and trade up from a Sloop to a **Galleon** to win.

Full rules: **[game-mechanics.md](game-mechanics.md)**.

## Play

Download the latest build from [Releases](https://github.com/Sam23D/uncharted-lap/releases):

- **Web:** unzip the web zip and serve the folder with any static server (e.g. `python3 -m http.server`), then open `index.html`. It doesn't run from `file://`.
- **Linux:** unzip, then run `uncharted-lap.x86_64`.
- **Windows:** unzip, then run `uncharted-lap.exe`. The build is unsigned, so SmartScreen may warn you: choose "More info", then "Run anyway".

Controls: the mouse. Enter continues or starts a voyage, and Esc opens the menu. The game autosaves in every port.

## Develop

Requires [Godot 4.5.1](https://godotengine.org/download).

```sh
godot --path .                      # open the editor
tools/strip_mcp.sh                  # once, on a fresh clone: removes a dev-only editor plugin that isn't in git
```

Game data (ports, goods, ships, crew, pirates, rules) lives in `data/*.json`. Prices, routes and charts are generated: edit `tools/trade_data.py`, then run `python3 tools/trade_data.py --write`. It checks the balance rules first.

## Test

```sh
for t in tests/*_check.gd; do godot --headless --path . --script "res://$t" || echo "FAIL $t"; done
```

## Build

Install the Godot 4.5.1 export templates, then:

```sh
tools/release.sh 0.1.0                      # Web → dist/uncharted-lap-0.1.0-web.zip
tools/release.sh 0.1.0 web linux windows    # all platforms
REF=. tools/release.sh 0.1.0                # include uncommitted changes
```

It builds from a clean copy, strips the dev plugin, runs every check, then exports and zips into `dist/` (not in git). Set `GODOT=/path/to/godot` if `godot` isn't on your PATH.

## Credits and license

Created by s.blanc. Art: [Kenney](https://kenney.nl) (CC0). Engine: [Godot](https://godotengine.org) (MIT). See [CREDITS.md](CREDITS.md).

The code is released under the [MIT license](LICENSE). Release notes are in [CHANGELOG.md](CHANGELOG.md).
