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
| | `colors` | single color, or dual color |
| | `body_color`, `number_color` | which slot each part lands in |
| | `die_size` | largest dimension in mm, as you would measure it; 0 keeps the standard size |
| Numbers | `face_1` … `face_20` | free text, one or two characters |
| Style | `font_family`, `font_style`, `font_custom` | three families x four weights |
| | `text_scale`, `text_depth`, `rounding`, `mark_6_and_9`, `smoothness` | |
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

**Font.** Chosen with two dropdowns, `font_family` (Liberation Sans, Serif or
Mono) and `font_style` (Bold, Regular, Italic, Bold Italic). All twelve
combinations are tested. Those three families ship with OpenSCAD, so they render
anywhere; Arial and other system fonts are not guaranteed to exist on
MakerWorld's renderer, and a missing font falls back silently. `font_custom`
takes a full spec such as `DejaVu Sans:style=Bold` to override both.

Family and weight are deliberately *separate* dropdowns rather than one list of
full font specs. A full spec contains a colon, and the Customizer reads a colon
inside a dropdown as the separator between a value and its display label — so a
`Liberation Sans:style=Bold` entry would quietly set the font to
`Liberation Sans` and drop the weight, rendering every die in Regular.

**Two-color prints.** Set `colors` to dual and the model comes out as two
colored bodies in one file — no generating it twice and reassembling. The die
body and the numbers are exact complements in the same coordinate frame, so the
number plugs fill the recesses flush, with no gap and no overlap. Verified for
every side count: the two together come to exactly the volume of the solid die.

`body_color` and `number_color` decide which filament slot each part lands in.
They are a preview — the real color is whatever filament you load.

On single color the numbers are simply left as recesses, so the die reads by
shadow. That means the single and dual models differ in volume by exactly the
volume of the numbers, which is correct rather than a discrepancy.

**Flat on the build plate.** Every die is rotated so one face lies on the plate
and dropped to z = 0, which is the orientation you want to print in anyway.
`die_size` is measured in that final pose, so it matches what you would put
calipers across.

## Not yet verified on MakerWorld

Everything here was tested against OpenSCAD 2025.09 locally — every side count,
the part selector, size override, percentile labels, letters and over-long input
all render watertight. **It has not been run through MakerWorld's own
Parametric Model Maker**, so their Customizer parsing and OpenSCAD version could
still hold surprises. Worth one test upload before publishing it there.
