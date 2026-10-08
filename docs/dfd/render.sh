#!/usr/bin/env bash
# Re-render every DFD (Levels 0-2 here, Level 3 in features/):  bash render.sh [name-without-extension ...]
# The .mmd files are generated: run  python docs/dfd/build_dfd.py  first.
# Needs @mermaid-js/mermaid-cli 12+ (npm install it in a scratch folder; npx
# alone fails on puppeteer) and MMDC pointing at its node_modules/.bin/mmdc.
# PNGs are rendered at 1.5x the diagram's natural size, so text is the same
# size on every diagram.
set -euo pipefail
cd "$(dirname "$0")"
MMDC="${MMDC:-mmdc}"
# Names are relative to this folder; the feature diagrams (Level 3) are features/dfd-3-*.
names=("$@"); [ ${#names[@]} -eq 0 ] && names=($(ls dfd-*.mmd features/dfd-*.mmd | sed 's/\.mmd$//'))
for n in "${names[@]}"; do
  "$MMDC" -i "$n.mmd" -o "$n.svg" -b white -q
  size=$(grep -o 'viewBox="[^"]*"' "$n.svg" | head -1 | tr -d '"' | awk '{w=$3; h=$4; m=(w>h?w:h); printf "%d", m*1.5}')
  "$MMDC" -i "$n.mmd" -o "$n.png" -b white --size "$size" -q
  echo "rendered $n (${size}px)"
done
