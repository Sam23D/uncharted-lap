#!/usr/bin/env bash
# Remove the dev-only Godot MCP Pro plugin from a project.godot (default: ./project.godot).
# The plugin (addons/godot_mcp) is not in git; builds and fresh clones must not reference it.
set -euo pipefail
f="${1:-project.godot}"
python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r'^MCP[A-Za-z]+="\*res://addons/godot_mcp/[^\n]*\n', "", s, flags=re.M)
s = re.sub(r'"res://addons/godot_mcp/plugin\.cfg",? ?', "", s)
s = re.sub(r'^enabled=PackedStringArray\(\)\n', "", s, flags=re.M)
s = re.sub(r"\[editor_plugins\]\n+(?=\[|\Z)", "", s)
open(p, "w").write(s)
PY
if grep -q godot_mcp "$f"; then echo "still references godot_mcp" >&2; exit 1; fi
