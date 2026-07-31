#!/usr/bin/env bash
# import-labels.sh — pull component ID labels from a labelme JSON into
# component-notes.org, and link them from bom.org.
#
#   ./import-labels.sh photos/some-photo-labeled.json
#
# Reads the "shapes" list from a labelme annotation file. For each
# label matching a known Ref in bom.org:
#   - creates a "* Ref" heading in component-notes.org if none exists
#   - adds a photo bullet under that heading (skipped if already there
#     — safe to re-run on the same file after re-tagging)
#   - turns that Ref's bom.org cell into a link to the heading, if it
#     isn't one already
#
# Labels that don't match a clean designator pattern (like "Fuse" or
# "Switch AC Outlet") or that don't match any bom.org Ref are reported,
# not silently dropped — they're real findings, just not ones bom.org
# has a row for yet.

set -euo pipefail

JSON="${1:?usage: import-labels.sh <labelme.json>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOM="$ROOT/bom.org"
NOTES="$ROOT/component-notes.org"

python3 - "$JSON" "$BOM" "$NOTES" <<'PYEOF'
import json, re, sys

json_path, bom_path, notes_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(json_path) as f:
    data = json.load(f)

photo = data.get("imagePath", "").strip()
if not photo:
    print("No imagePath in JSON, aborting.", file=sys.stderr)
    sys.exit(1)
photo_link = f"[[file:photos/{photo}]]"

labels = []
seen = set()
for shape in data.get("shapes", []):
    label = shape.get("label", "").strip()
    if label and label not in seen:
        seen.add(label)
        labels.append(label)

designator_re = re.compile(r'^[A-Z][A-Z]?[0-9]+[a-z]?$')

with open(bom_path) as f:
    bom_lines = f.readlines()

known_refs = set()
for line in bom_lines:
    if not line.startswith("| "):
        continue
    cols = line.split("|")
    if len(cols) < 3:
        continue
    ref = re.sub(r'\[\[.*?\]\[(.*?)\]\]', r'\1', cols[1].strip())
    if designator_re.match(ref):
        known_refs.add(ref)

matched = [l for l in labels if designator_re.match(l) and l in known_refs]
unmatched = [l for l in labels if l not in matched]

with open(notes_path) as f:
    notes_lines = f.readlines()

heading_idx = {}
for i, line in enumerate(notes_lines):
    m = re.match(r'^\* (\S+)\s*$', line)
    if m:
        heading_idx[m.group(1)] = i

added_photo = []
created_heading = []

for ref in matched:
    if ref not in heading_idx:
        # new heading at end of file
        if notes_lines and not notes_lines[-1].endswith("\n"):
            notes_lines[-1] += "\n"
        notes_lines.append(f"\n* {ref}\n\nPhotos:\n- {photo_link}\n")
        created_heading.append(ref)
        added_photo.append(ref)
        continue
    # find end of this heading's section (next "* " line or EOF)
    start = heading_idx[ref]
    end = start + 1
    while end < len(notes_lines) and not notes_lines[end].startswith("* "):
        end += 1
    section = notes_lines[start:end]
    section_text = "".join(section)
    if photo_link in section_text:
        continue  # already logged
    if "Photos:\n" in section_text:
        # insert a bullet right after "Photos:"
        for j, sline in enumerate(section):
            if sline.strip() == "Photos:":
                section.insert(j + 1, f"- {photo_link}\n")
                break
    else:
        # append a Photos block at the end of this section, before trailing blank
        while section and section[-1].strip() == "":
            section.pop()
        section.append(f"\nPhotos:\n- {photo_link}\n")
    notes_lines[start:end] = section
    # recompute indices since line counts may have shifted
    heading_idx = {}
    for i, line in enumerate(notes_lines):
        m = re.match(r'^\* (\S+)\s*$', line)
        if m:
            heading_idx[m.group(1)] = i
    added_photo.append(ref)

with open(notes_path, "w") as f:
    f.writelines(notes_lines)

# Link matched refs in bom.org that aren't already linked.
linked = []
for i, line in enumerate(bom_lines):
    if not line.startswith("| "):
        continue
    cols = line.split("|")
    if len(cols) < 3:
        continue
    cell = cols[1]
    ref = cell.strip()
    if ref in matched and "[[file:" not in cell:
        width = len(cell)
        link = f"[[file:component-notes.org::*{ref}][{ref}]]"
        new_cell = " " + link + " " * max(1, width - len(link) - 1)
        if len(new_cell) < len(link) + 2:
            new_cell = " " + link + " "
        cols[1] = new_cell
        bom_lines[i] = "|".join(cols)
        linked.append(ref)

with open(bom_path, "w") as f:
    f.writelines(bom_lines)

print(f"Photo: {photo}")
print(f"New component-notes.org headings created: {created_heading or 'none'}")
print(f"Photo bullets added: {added_photo or 'none'}")
print(f"bom.org Refs newly linked: {linked or 'none'}")
if unmatched:
    print(f"Unmatched (not a known bom.org Ref, left for you to handle): {', '.join(unmatched)}")
PYEOF
