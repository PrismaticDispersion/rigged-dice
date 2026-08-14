#!/usr/bin/env bash
#
# Build the whole dice set and check it.
#
# Produces, for all 42 dice:
#   dice/<type>/<name>.stl   single-colour print
#   dice/<type>.<name>.3mf   two-colour AMS print (body + numbers)
#   dice/<type>/<name>.png   two-sided preview
#
# Usage:
#   ./build.sh                     everything
#   ./build.sh --type d20 d10      pass any generate.py flag straight through
#   OPENSCAD=/path/to/openscad ./build.sh
#
set -euo pipefail

# ---------------------------------------------------------------------------
# EDIT ME: where your OpenSCAD lives. An AppImage, a binary on $PATH such as
# plain "openscad", or /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD on a
# Mac all work. The OPENSCAD environment variable overrides this.
# ---------------------------------------------------------------------------
OPENSCAD="${OPENSCAD:-$HOME/3DObjects/OpenSCAD.AppImage}"

cd "$(dirname "$0")"

# Accept either a path or a bare command name found on $PATH.
if [ ! -x "$OPENSCAD" ]; then
    if command -v "$OPENSCAD" >/dev/null 2>&1; then
        OPENSCAD="$(command -v "$OPENSCAD")"
    else
        echo "OpenSCAD not found at: $OPENSCAD" >&2
        echo "Edit OPENSCAD at the top of $0, or run:" >&2
        echo "    OPENSCAD=/path/to/openscad $0" >&2
        exit 1
    fi
fi
export OPENSCAD

echo "Using OpenSCAD: $OPENSCAD"
"$OPENSCAD" --version 2>&1 | head -1

echo
echo "== single-colour STLs =="
python3 generate.py "$@"

echo
echo "== two-colour 3MFs and previews =="
python3 generate.py --3mf --preview "$@"

echo
echo "== verifying =="
python3 verify.py
