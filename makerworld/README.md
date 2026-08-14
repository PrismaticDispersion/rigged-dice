# MakerWorld variant

`dice_customizer.scad` is a single self-contained file for MakerWorld's
Parametric Model Maker. Upload that one file — it needs nothing else.

## Why it is separate

The main project splits into a library (`dice.scad`) plus small wrappers that
pull it in with `use <>`. MakerWorld cannot work that way:

- it takes **one** `.scad`, so it cannot follow `use <../dice.scad>`
- the OpenSCAD Customizer only builds its UI from **top-level variables in that
  one file**, and a variable set in a wrapper does not reach a library included
  with `use <>` — the same dynamic-scoping rule that made `$fn` fail silently
  in the main project

So the geometry has to be inlined. To stop that copy drifting out of sync,
`dice_customizer.scad` is **generated**:

```sh
./build_makerworld.py       # splices dice.scad under the Customizer front end
```

`dice.scad` stays the single source of truth. **Edit that, not this file** —
regenerate afterwards. The script fails loudly if it cannot find its slice
markers in `dice.scad`, so a rename upstream will not silently produce a stale
file.

## Parameters

| Group | Parameter | Notes |
|---|---|---|
| Die | `sides` | 4, 6, 8, 10, 12 or 20, as a dropdown |
| | `part` | whole die, body only, or numbers only |
| | `die_size` | largest dimension in mm, as you would measure it; 0 keeps the standard size |
| Numbers | `face_1` … `face_20` | free text, one or two characters |
| Style | `font`, `text_scale`, `text_depth`, `rounding`, `mark_6_and_9`, `smoothness` | |
| d4 corner numbers | `d4_corner_offset`, `d4_text_scale` | only affect the d4 |

Faces past the selected side count are ignored, so `face_11`–`face_20` simply do
nothing on a d10.

## Things worth knowing

**Any text, not just numbers.** Repeat a value to load the die, type `00`–`90`
across ten faces for a percentile d10, or use letters and symbols. Anything
longer than two characters is trimmed rather than allowed to overflow the face,
since the layout is built around one or two.

**The d4 is corner-numbered**, like a commercial one. Its four values belong to
the *corners*, not the faces — each face carries the numbers of its three
corners, so whichever corner points up reads the same on all three visible
faces.

**Font.** The default is Liberation Sans, which OpenSCAD ships with, so it
renders anywhere. Arial and other system fonts are not guaranteed to exist on
MakerWorld's renderer, and a missing font silently falls back to something else.

**Two-colour prints.** Generate the model twice, once with `part = body` and
once with `part = numbers`, then load both as parts of a single object in Bambu
Studio. They are exact complements in the same coordinate frame, so they need no
aligning — the number plugs fill the recesses flush.

The `numbers` part reports a non-zero genus, which is correct rather than a
fault: the counters in `6`, `8` and `0` are real holes through those plugs.

## Not yet verified on MakerWorld

Everything here was tested against OpenSCAD 2025.09 locally — every side count,
the part selector, size override, percentile labels, letters and over-long input
all render watertight. **It has not been run through MakerWorld's own
Parametric Model Maker**, so their Customizer parsing and OpenSCAD version could
still hold surprises. Worth one test upload before publishing it there.
