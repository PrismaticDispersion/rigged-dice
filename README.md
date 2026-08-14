# Rigged dice

Loaded polyhedral dice for tabletop games. Six rigged variants of every die type
in a standard D&D set, 42 dice in all.

```
dice.scad      parametric d4/d6/d8/d10/d12/d20 with arbitrary text per face
generate.py    builds the labels, writes wrapper .scad files, renders output
mmu3mf.py      packs body + numbers into one two-colour 3MF (standard library only)
verify.py      checks everything under dice/ is watertight and correctly assembled
dice/          output, one folder per die type + manifest.json
makerworld/    single-file variant for MakerWorld's Parametric Model Maker
legacy/        the original Parametric-Easy-Print-D20 and its renders
```

Want to pick your own numbers instead of the six rigged variants? See
[`makerworld/`](makerworld/) — one self-contained `.scad` with the side count
and every face exposed as parameters.

Each die in `dice/<type>/` comes as:

| File | What it is |
|------|-----------|
| `.3mf` | **for the AMS** — body and numbers as two parts of one object, numbers on filament 2 |
| `.stl` | the same die as one solid, for a single-colour print |
| `.png` | two-sided preview, so you can read the rigged faces without slicing |
| `.scad` | the source, recording exactly which numbers this die carries |

## Building

```sh
./generate.py                    # all 42 dice as single-colour STLs
./generate.py --3mf              # one assembled 2-colour 3MF per die (AMS)
./generate.py --split            # the same two parts as separate STLs
./generate.py --preview          # also write the two-sided PNGs
./generate.py --type d20 d10     # just those types
./generate.py --variant 1 3      # just those variants
./generate.py --dry-run          # print labels, render nothing
./generate.py --seed 12345       # a different set of random draws
./verify.py                      # check the output
```

A full run takes a few seconds. Flags combine, and re-running is cheap, so the
committed set was made with `./generate.py` followed by
`./generate.py --3mf --preview`.

## Two-colour printing on the AMS

Open a `.3mf` and it arrives as **one object with two parts**: `body` on filament
1 and `numbers` on filament 2. Assign your two colours to those slots and slice —
no aligning, no positioning, nothing to assemble.

The numbers are recessed 0.9 mm into the faces and the number part fills those
recesses exactly, ending flush with the surface. `verify.py` proves this for
every die: the two parts' volumes sum to the plain undrilled die to within
float32 precision, so there is no gap to leak through and no overlap to fight
over. Both parts are independently watertight.

The 3MF is written by `mmu3mf.py` using only the standard library — nothing to
install. It follows the layout Bambu Studio and OrcaSlicer write themselves:
each part is its own mesh object, a further object joins them with
`<components>`, and `Metadata/model_settings.config` names each part and pins it
to a filament slot.

The first attempt used the PrusaSlicer convention instead — one merged mesh with
triangle-range volumes in `Slic3r_PE_model.config` — which Bambu Studio silently
ignores, importing the die as a single uncoloured part. If you ever see that
symptom again, that sidecar is the thing to check.

For a single-colour print use the `.stl`, or just print the `.3mf` with both
parts set to the same filament.

## The six variants

Per die type, where "low" and "high" mean that die's own lowest and highest
value — so the d10 runs 0–9 and the percentile die 00–90.

| # | Name | What it does |
|---|------|--------------|
| 1 | `all-low-one-high` | every face lowest, one face highest |
| 2 | `all-high-one-low` | every face highest, one face lowest |
| 3 | `random-top-third` | random values drawn from the top third |
| 4 | `random-bottom-third` | random values drawn from the bottom third |
| 5 | `random-middle-third` | random values drawn from the middle third |
| 6 | `one-middle-one-high` | one random middle value on every face, one face highest |

Thirds are inclusive of their edge values. Face counts are rarely divisible by
three, so each third rounds up and the middle is centered; a value on a boundary
belongs to both neighbouring thirds.

Draws are seeded (`DEFAULT_SEED` in `generate.py`), so a rebuild reproduces the
same dice. The seed is per die type and variant, which means rendering a single
die later gives the same numbers it had in the full run. Every die's exact labels
are recorded in `dice/manifest.json`.

## Die types

| Folder | Faces | Values | Corner-to-corner |
|--------|-------|--------|------------------|
| `d4` | 4 | 1–4 | 24 mm |
| `d6` | 6 | 1–6 | 27.7 mm (a 16 mm cube) |
| `d8` | 8 | 1–8 | 22 mm |
| `d10` | 10 | 0–9 | 21 mm |
| `d10x10` | 10 | 00–90 | 21 mm |
| `d12` | 12 | 1–12 | 25 mm |
| `d20` | 20 | 1–20 | 24 mm |

`d10x10` is the same trapezohedron as `d10` with percentile labels.

## Tuning

The knobs live at the top of `dice.scad`: `smoothness`, `rounding`, `font`,
`text_depth`, `text_scale`, `mark_6_and_9` (the trailing period that separates 6
from 9), and the two `d4_*` corner settings. Per-type sizes are in `size_mm()`.
Edit any of them and re-run `generate.py`.

To print something outside the six variants, call the module directly:

```openscad
use <dice.scad>;
die("d12", ["7","7","7","7","7","7","7","7","7","7","7","7"]);
die("d20", [for (i = [1:20]) str(i)], part = "numbers");   // just the inlay
```

Labels are plain strings, so roman numerals, runes, or symbols all work as long
as the font has the glyphs.

## Geometry notes

The body of each die is the convex hull of a sphere at every vertex, which
rounds the corners and edges in one step while leaving the faces flat. Numbers
are cut at the face centroids, pushed out along the face normal by `rounding` to
meet the real surface.

The d4 is numbered at its **corners**, the way a commercial d4 is: the four
values belong to the vertices, not the faces, and each face carries the numbers
of its three corners. Whichever corner points up reads the same on all three
visible faces. `d4_corner_offset` controls how far into the corners they sit —
push it much past 0.5 and the numbers start riding onto the rounded edges.

Three things here were easy to get wrong, all since fixed:

- **`$fn` cannot be set at the top of an included file.** Special variables are
  dynamically scoped, so `$fn = 48` in `dice.scad` was silently overridden by the
  calling wrapper's (unset) value, giving 5-segment corner spheres and nearly
  sharp edges. It is now a normal variable, `smoothness`, passed explicitly to
  `sphere()`.
- **Face normals are not centroid directions.** True for the Platonic solids, but
  false for the d10: its kite faces are not centered on their own normal, so that
  shortcut buried the numbers inside the solid. Normals come from the cross
  product of two face edges instead.
- **The d10's proportions are fixed by its geometry.** A pentagonal trapezohedron
  only has planar kite faces when the apex height and the ring height are in the
  ratio 9.472136 : 1 (`d10_h` / `d10_c`). The ring radius then sets the size.

The d12 and d20 face lists are derived from their face normals rather than typed
out by hand — the manual lists are long and easy to get subtly wrong.

## Licence

Two parts, see [LICENSE](LICENSE) and [LICENSE-MODELS](LICENSE-MODELS):

- **Code** — `dice.scad`, `generate.py`, `mmu3mf.py`, `verify.py`, `build.sh` —
  MIT. Use it, change it, ship it.
- **The dice designs and any mesh generated from them** — CC BY 4.0. Free for
  any purpose including selling prints, with credit.

`legacy/Parametric-Easy-Print-D20.scad` is third-party: Copyright 2017
HalfwitTomfoolery, CC BY 4.0 or later, redistributed unmodified with its notice
intact. `dice.scad` is an independent implementation that shares no code with
it, though it uses the same approach of hulling spheres at the vertices.
