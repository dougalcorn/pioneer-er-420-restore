#!/usr/bin/env bash
# grid.sh — burn an IEC-style zone grid onto a schematic scan.
#
#   ./grid.sh <input> <cols> <rows> [outdir]
#   ./grid.sh ../schematic/raw/er-420-schematic.png 12 9 ../schematic
#
# Produces two files, leaving the input untouched:
#   <name>-grid.png    margin ticks + labels, bordered. For humans.
#   <name>-cells.png   small in-cell labels only, same pixel dimensions
#                      as the input. This is what tiles.sh crops from, so
#                      every tile carries its own zone labels.
#
# Letters run down the vertical axis, numbers across the horizontal.
# LINES=1 also draws dashed cell boundaries across the drawing. Off by
# default — faint lines crossing traces cause more confusion than they solve.
#
# Untested against your actual scan. Run it on a copy first and look at the
# result before generating a few hundred tiles from it.

set -euo pipefail

IN="${1:?usage: grid.sh <input> <cols> <rows> [outdir]}"
COLS="${2:?need column count}"
ROWS="${3:?need row count}"
OUTDIR="${4:-$(dirname "$IN")}"

LINES="${LINES:-0}"
COLOR="${COLOR:-#FF00FF}"   # magenta — cannot be mistaken for wiring
MARGIN="${MARGIN:-70}"

if command -v magick >/dev/null 2>&1; then
  MAGICK="magick"                    # ImageMagick 7
elif command -v convert >/dev/null 2>&1; then
  MAGICK="convert"                   # ImageMagick 6
else
  echo "ImageMagick not found (brew install imagemagick)" >&2
  exit 1
fi
IDENTIFY="${MAGICK} identify"
[ "$MAGICK" = "convert" ] && IDENTIFY="identify"

(( ROWS <= 26 )) || { echo "rows must be <= 26 (single letters)" >&2; exit 1; }

BASE="$(basename "${IN%.*}")"
W=$($IDENTIFY -format '%w' "$IN")
H=$($IDENTIFY -format '%h' "$IN")
CW=$(( W / COLS ))
CH=$(( H / ROWS ))

LETTERS=(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)

echo "input      ${W} x ${H}"
echo "grid       ${COLS} cols x ${ROWS} rows"
echo "cell       ${CW} x ${CH} px"

# ---------------------------------------------------------------- cells copy
PT_CELL=$(( CW / 12 )); (( PT_CELL < 11 )) && PT_CELL=11

draw_cells=""
for (( r=0; r<ROWS; r++ )); do
  for (( c=0; c<COLS; c++ )); do
    x=$(( c * CW + 6 ))
    y=$(( r * CH + PT_CELL + 4 ))
    draw_cells+=" -draw \"text ${x},${y} '${LETTERS[$r]}$(( c + 1 ))'\""
  done
done

if [ "$LINES" = "1" ]; then
  for (( c=1; c<COLS; c++ )); do
    x=$(( c * CW ))
    draw_cells+=" -draw \"stroke-dasharray 10 10 line ${x},0 ${x},${H}\""
  done
  for (( r=1; r<ROWS; r++ )); do
    y=$(( r * CH ))
    draw_cells+=" -draw \"stroke-dasharray 10 10 line 0,${y} ${W},${y}\""
  done
fi

eval $MAGICK "\"$IN\"" -fill "\"$COLOR\"" -stroke "\"$COLOR\"" -strokewidth 1 \
  -pointsize "$PT_CELL" $draw_cells "\"${OUTDIR}/${BASE}-cells.png\""

# --------------------------------------------------------------- gridded copy
PT_MARG=$(( MARGIN / 2 )); (( PT_MARG < 16 )) && PT_MARG=16
TICK=12

draw_grid=""
for (( c=0; c<COLS; c++ )); do
  cx=$(( MARGIN + c * CW + CW / 2 ))
  bx=$(( MARGIN + c * CW ))
  draw_grid+=" -draw \"text ${cx},$(( MARGIN - 14 )) '$(( c + 1 ))'\""
  draw_grid+=" -draw \"text ${cx},$(( MARGIN + H + PT_MARG + 10 )) '$(( c + 1 ))'\""
  draw_grid+=" -draw \"line ${bx},$(( MARGIN - TICK )) ${bx},${MARGIN}\""
  draw_grid+=" -draw \"line ${bx},$(( MARGIN + H )) ${bx},$(( MARGIN + H + TICK ))\""
done
for (( r=0; r<ROWS; r++ )); do
  cy=$(( MARGIN + r * CH + CH / 2 ))
  by=$(( MARGIN + r * CH ))
  draw_grid+=" -draw \"text $(( MARGIN - PT_MARG - 18 )),${cy} '${LETTERS[$r]}'\""
  draw_grid+=" -draw \"text $(( MARGIN + W + 14 )),${cy} '${LETTERS[$r]}'\""
  draw_grid+=" -draw \"line $(( MARGIN - TICK )),${by} ${MARGIN},${by}\""
  draw_grid+=" -draw \"line $(( MARGIN + W )),${by} $(( MARGIN + W + TICK )),${by}\""
done

eval $MAGICK "\"${OUTDIR}/${BASE}-cells.png\"" \
  -bordercolor white -border "$MARGIN" \
  -fill "\"$COLOR\"" -stroke "\"$COLOR\"" -strokewidth 2 \
  -pointsize "$PT_MARG" -gravity NorthWest $draw_grid \
  "\"${OUTDIR}/${BASE}-grid.png\""

echo
echo "wrote ${OUTDIR}/${BASE}-cells.png   (tiling source)"
echo "wrote ${OUTDIR}/${BASE}-grid.png    (full sheet, margin labels)"
echo
echo "Record the grid in schematic/ZONES.org: ${COLS} x ${ROWS}, cell ${CW} x ${CH}."
