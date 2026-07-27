#!/usr/bin/env bash
# import-photos.sh — pull bench photos from the Dropbox inbox into the repo.
#
#   ./import-photos.sh [subject-slug]
#   ./import-photos.sh chassis-top
#
# For each new image in $INBOX:
#   1. reads the EXIF capture date
#   2. resizes to 1600px on the long edge (Claude downsamples past ~1500 anyway)
#   3. strips ALL metadata — including GPS, which iPhone embeds at
#      address-level precision and which you do not want in a repo you might
#      one day push or excerpt onto a forum
#   4. names it YYYY-MM-DD[-subject]-NN.jpg
#   5. records the source name so re-running skips what is already in
#
# The date survives in the filename, which is where it is actually useful.
# Full-resolution originals stay in Dropbox untouched — this only ever reads
# from the inbox.

set -euo pipefail

SUBJECT="${1:-}"
INBOX="${INBOX:-$HOME/Dropbox/er-420}"
DEST="${DEST:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/photos}"
LONGEDGE="${LONGEDGE:-1600}"
QUALITY="${QUALITY:-88}"

if command -v magick >/dev/null 2>&1; then
  MAGICK="magick"; IDENTIFY="magick identify"
elif command -v convert >/dev/null 2>&1; then
  MAGICK="convert"; IDENTIFY="identify"
else
  echo "ImageMagick not found (brew install imagemagick)" >&2; exit 1
fi

[ -d "$INBOX" ] || { echo "inbox not found: $INBOX" >&2; exit 1; }
mkdir -p "$DEST"
MANIFEST="${DEST}/.imported"
touch "$MANIFEST"

slug=""
[ -n "$SUBJECT" ] && slug="-${SUBJECT}"

imported=0
skipped=0

# NUL-delimited so filenames with spaces and commas — which is exactly what
# Dropbox produces ("Photo Jul 24 2026, 9 36 24 PM.jpg") — survive intact.
while IFS= read -r -d '' src; do
  base="$(basename "$src")"

  if grep -Fqx -- "$base" "$MANIFEST"; then
    skipped=$(( skipped + 1 ))
    continue
  fi

  # EXIF capture date, falling back to file mtime.
  raw="$($IDENTIFY -format '%[EXIF:DateTimeOriginal]' "$src" 2>/dev/null || true)"
  if [ -n "$raw" ]; then
    date="$(echo "$raw" | cut -d' ' -f1 | tr ':' '-')"
  else
    date="$(date -r "$src" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"
    echo "  no EXIF date on ${base}, using file mtime"
  fi

  # Next free sequence number for this date + subject.
  n=1
  while :; do
    out="$(printf '%s/%s%s-%02d.jpg' "$DEST" "$date" "$slug" "$n")"
    [ -e "$out" ] || break
    n=$(( n + 1 ))
  done

  if ! $MAGICK "$src" -auto-orient -resize "${LONGEDGE}x${LONGEDGE}>" \
       -quality "$QUALITY" -strip "$out" 2>/dev/null; then
    echo "  FAILED: ${base}"
    echo "  (if HEIC: ImageMagick needs libheif — on macOS try" >&2
    echo "   sips -s format jpeg \"\$f\" --out converted.jpg)" >&2
    continue
  fi

  printf '%s\n' "$base" >> "$MANIFEST"
  echo "  $(basename "$out")  <-  ${base}"
  imported=$(( imported + 1 ))

done < <(find "$INBOX" -maxdepth 1 -type f \
           \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
              -o -iname '*.heic' \) -print0 | sort -z)

echo
echo "imported ${imported}, skipped ${skipped} (already in)"
[ "$imported" -gt 0 ] && echo "reference them inline in today's log entry."
exit 0
