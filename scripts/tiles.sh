#!/usr/bin/env bash
# tiles.sh — cut overlapping, zone-named tiles from the cell-labelled schematic.
#
#   ./tiles.sh <cells-image> <cols> <rows> [tile_w] [tile_h] [stride] [outdir]
#   ./tiles.sh ../schematic/er-420-schematic-cells.png 12 9 3 3 2 ../schematic/tiles
#
# tile_w/tile_h are in CELLS, not pixels. stride is how many cells to advance
# between tiles — make it smaller than tile_w so tiles overlap and nothing
# important lands on a seam. Default 3x3 cells, stride 2.
#
# Output: tiles/tile-A1-C3.png etc. Regenerable, so gitignored.
#
# The arithmetic check at the end is the point: anything over ~1500px on its
# long edge gets downsampled before Claude sees it, which defeats the whole
# exercise. If tiles come out too big, use a finer grid or fewer cells per tile.

set -euo pipefail

IN="${1:?usage: tiles.sh <cells-image> <cols> <rows> [tile_w] [tile_h] [stride] [outdir]}"
COLS="${2:?need column count}"
ROWS="${3:?need row count}"
TW="${4:-3}"
TH="${5:-3}"
STRIDE="${6:-2}"
OUTDIR="${7:-$(dirname "$IN")/tiles}"

LIMIT=1500

if command -v magick >/dev/null 2>&1; then
  MAGICK="magick"; IDENTIFY="magick identify"
elif command -v convert >/dev/null 2>&1; then
  MAGICK="convert"; IDENTIFY="identify"
else
  echo "ImageMagick not found" >&2; exit 1
fi

mkdir -p "$OUTDIR"

W=$($IDENTIFY -format '%w' "$IN")
H=$($IDENTIFY -format '%h' "$IN")
CW=$(( W / COLS ))
CH=$(( H / ROWS ))
PW=$(( CW * TW ))
PH=$(( CH * TH ))

LETTERS=(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)

echo "tile size  ${TW} x ${TH} cells = ${PW} x ${PH} px"

LONG=$PW; (( PH > LONG )) && LONG=$PH
if (( LONG > LIMIT )); then
  echo
  echo "!! ${LONG}px on the long edge exceeds the ~${LIMIT}px downsample threshold."
  echo "!! These tiles will be resized before Claude reads them and you will"
  echo "!! lose part values. Use a finer grid, or fewer cells per tile:"
  echo "!!   suggested max cells per tile at this cell size: $(( LIMIT / (CW > CH ? CW : CH) ))"
  echo
  read -r -p "generate anyway? [y/N] " ok
  [[ "$ok" =~ ^[Yy]$ ]] || exit 1
fi

n=0
for (( r=0; r+TH<=ROWS; r+=STRIDE )); do
  for (( c=0; c+TW<=COLS; c+=STRIDE )); do
    x=$(( c * CW ))
    y=$(( r * CH ))
    from="${LETTERS[$r]}$(( c + 1 ))"
    to="${LETTERS[$(( r + TH - 1 ))]}$(( c + TW ))"
    out="${OUTDIR}/tile-${from}-${to}.png"
    $MAGICK "$IN" -crop "${PW}x${PH}+${x}+${y}" +repage "$out"
    n=$(( n + 1 ))
  done
done

echo "wrote ${n} tiles to ${OUTDIR}"
