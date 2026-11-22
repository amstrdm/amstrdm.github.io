#!/usr/bin/env bash
# Regenerate the Open Graph share images (1200x630) from scripts/og-template.html.
# Requires Google Chrome. Output PNGs are committed under public/og/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TPL="file://$ROOT/scripts/og-template.html"
OUT="$ROOT/public/og"
mkdir -p "$OUT"

shot() { # name, querystring
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --default-background-color=00000000 --force-device-scale-factor=1 \
    --window-size=1200,630 --screenshot="$OUT/$1.png" \
    "$TPL?$2" >/dev/null 2>&1
  echo "  wrote public/og/$1.png"
}

enc() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$1"; }

echo "Generating OG images…"

shot default "kicker=$(enc 'backend & full-stack developer')&title=$(enc 'Antonio Caserta')&sub=$(enc 'Part-time at Seibert. Python, FastAPI, React — lately C++ and firmware for my startup, Arrow.')&accent=mint&file=$(enc '~/caserta/portfolio.md')"

shot episteme "kicker=$(enc 'writeup · full-stack · python')&title=$(enc 'Episteme')&sub=$(enc 'Turning crowd-sourced stock theses into structured, peer-reviewed research.')&accent=blue&file=$(enc '~/caserta/writeups/episteme.md')"

shot polymarket "kicker=$(enc 'writeup · quant research')&title=$(enc 'Is Polymarket efficient enough to trade?')&sub=$(enc 'A long hunt for an edge — in the market’s own order flow, in the traders who win, and in outside data it doesn’t price.')&accent=orange&file=$(enc '~/caserta/writeups/polymarket.md')"

echo "Done."
