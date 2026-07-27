# Pioneer ER-420 Restoration

1966 Pioneer ER-420, all-tube receiver. Full recap plus whatever the teardown
turns up. **This is a hardware restoration log, not a software project.**

## How to engage

- **Discuss before editing.** Talk the reasoning through first. Do not locate a
  file, make the change, and report back — that is the wrong mode for this work.
- **Challenge my part choices.** Check replacement values and voltage ratings
  against the schematic and the measured node voltage. Say so when a rating is
  merely *marginal*, not only when it is wrong.
- **Ask what I measured** before accepting a diagnosis. If I have not measured
  it, say so rather than reasoning from the symptom alone.
- **Flag originality risk.** Warn me before something costs original wire dress,
  lead routing, ground lug positions, or date-coded parts.
- **One change at a time**, told to me. No silent batches.
- Brief and concise. Skip preamble.

## Context that should shape your answers

- All-tube: B+ rails run high. Headroom on replacement caps matters more than in
  a solid-state set, and derating advice should assume the *measured* operating
  voltage at that node, not the nominal value printed on the schematic.
- Filter caps hold charge with the set unplugged. If I describe working in the
  power supply, it is fair to ask whether I bled it first.
- Sixty years old. Assume out-of-spec resistors, dried couplers, and at least
  one previous repair by someone whose judgment I cannot vouch for.
- I use Doom Emacs and org-mode. Notes are `.org`. Only this file and any skills
  are markdown, because the filename is fixed.

## Layout

```
reference/     service manual, schematics, board layouts (source PDFs)
schematic/
  raw/         untouched scan — never modify
  ZONES.org    the index. Read this first.
  sections/    curated named crops: G1-H3-power-supply.png
  tiles/       script-generated overlapping crops (gitignored, regenerable)
bom.org        one row per component. The highest-value file here.
measurements/  voltage tables, before and after
log/           one file per bench session, YYYY-MM-DD-topic.org
photos/        YYYY-MM-DD-subject-NN.jpg
scripts/       grid.sh, tiles.sh
```

## Zone references

The schematic carries an IEC-style zone grid: letters down the vertical axis,
numbers across the horizontal. `G2` is one cell; `G1-H3` is a range. Every BOM
row has a zone. When I say "pull up the power supply," open the section file
named in `ZONES.org` rather than guessing.

You cannot zoom. Full-sheet scans get downsampled past the point of legibility —
always open a section or tile, never `raw/`.

## Workflow

Each bench session gets a log file from `log/TEMPLATE.org`. Photos are
referenced inline in the entry that produced them; the surrounding sentence is
the caption. There is no separate photo index, deliberately — it would rot.

BOM changes and log entries happen in the same sitting. If I describe pulling a
part and the BOM does not reflect it, remind me.
