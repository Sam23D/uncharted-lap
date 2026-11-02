# Uncharted Lap

A small trading game in the spirit of *Uncharted Waters: New Horizons*, made with Godot 4.5. Sail between 12 ports, trade 14 goods, hire a crew and cartographers to chart new seas, fight or outrun pirates, and trade up from a Sloop to a **Galleon** to win.

Full rules: **[game-mechanics.md](game-mechanics.md)**.

## Play

- **Web:** build it (see below) and serve `dist/web/` with any static server, e.g. `python3 -m http.server -d dist/web`.
- **Desktop:** open the project in Godot 4.5.1 and press Play.

Controls: mouse; Enter starts a new voyage.

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

## Credits

Created by s.blanc. Art: [Kenney](https://kenney.nl) (CC0). Engine: [Godot](https://godotengine.org) (MIT).
