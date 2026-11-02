#!/usr/bin/env bash
# Build release zips from a clean copy of HEAD (or a given ref) into dist/.
#   tools/release.sh 0.1.0            # Web only (default)
#   tools/release.sh 0.1.0 web linux windows
# Env: GODOT=path to the Godot 4.5.1 editor binary; REF=git ref (default HEAD).
# The dev checkout is never touched: the MCP plugin is stripped in a temporary worktree.
set -euo pipefail
VERSION="${1:?usage: tools/release.sh <version> [web] [linux] [windows]}"; shift || true
TARGETS=("${@:-web}")
GODOT="${GODOT:-$HOME/Desktop/Godot_v4.5.1-stable_linux.x86_64}"
REF="${REF:-HEAD}"
ROOT="$(git rev-parse --show-toplevel)"
DIST="$ROOT/dist"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/uncharted-release.XXXXXX")"
trap 'git -C "$ROOT" worktree remove --force "$WORK/src" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

if [ "$REF" = "." ]; then
	# Uncommitted build: copy tracked + untracked-but-not-ignored files.
	echo "== working tree copy"
	mkdir -p "$WORK/src"
	(cd "$ROOT" && git ls-files -z -co --exclude-standard | tar --null -T - -cf -) | tar -xf - -C "$WORK/src"
else
	echo "== worktree $REF"
	git -C "$ROOT" worktree add --detach "$WORK/src" "$REF" >/dev/null
fi
cd "$WORK/src"
"$ROOT/tools/strip_mcp.sh" project.godot
grep -q "config/version=\"$VERSION\"" project.godot || { echo "project.godot version is not $VERSION" >&2; exit 1; }

echo "== import"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
if "$GODOT" --headless --path . --quit-after 30 2>&1 | grep -E 'SCRIPT ERROR|ERROR'; then
	echo "boot errors" >&2; exit 1
fi

echo "== checks"
fail=0; n=0
for t in tests/*_check.gd; do
	if "$GODOT" --headless --path . --script "res://$t" >/dev/null 2>&1; then n=$((n+1)); else echo "FAIL $t"; fail=1; fi
done
[ "$fail" = 0 ] || { echo "checks failed" >&2; exit 1; }
echo "pass $n"

mkdir -p "$DIST"
for target in "${TARGETS[@]}"; do
	case "$target" in
		web) preset="Web"; out="dist/web/index.html" ;;
		linux) preset="Linux"; out="dist/linux/uncharted-lap.x86_64" ;;
		windows) preset="Windows"; out="dist/windows/uncharted-lap.exe" ;;
		*) echo "unknown target $target" >&2; exit 1 ;;
	esac
	echo "== export $preset"
	mkdir -p "$(dirname "$out")"
	"$GODOT" --headless --path . --export-release "$preset" "$out" 2>&1 | grep -E 'ERROR|error' || true
	[ -s "$out" ] || { echo "export $preset produced nothing" >&2; exit 1; }
	zip="$DIST/uncharted-lap-$VERSION-$target.zip"
	rm -f "$zip"
	(cd "$(dirname "$out")" && zip -q -r "$zip" .)
	rm -rf "$DIST/$target"; cp -r "$(dirname "$out")" "$DIST/$target"
done

echo "== dist"
(cd "$DIST" && sha256sum uncharted-lap-"$VERSION"-*.zip)
