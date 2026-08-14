/*------------------------------------------------------------------------------
Parametric polyhedral dice generator
--------------------------------------------------------------------------------
Generates d4 / d6 / d8 / d10 / d12 / d20 with arbitrary text on every face.

Everything is driven by die(type, labels), so this file is meant to be pulled in
with `use <dice.scad>;` from a small wrapper that supplies the face labels.
The demo call at the bottom of this file is ignored by `use`.

    use <dice.scad>;
    die("d20", ["1","1","1","1","1","1","1","1","1","1",
                "1","1","1","1","1","1","1","1","1","20"]);

Face count / label count per type:
    d4  : 4      d6  : 6      d8  : 8
    d10 : 10     d12 : 12     d20 : 20

Labels are plain strings, so "00".."90" percentile dice, roman numerals, or
symbols all work as long as the font has the glyphs.
------------------------------------------------------------------------------*/

// ---------------------------------------------------------------- tunables --

// Smoothness of the rounded corners. Higher = prettier, slower.
// Deliberately NOT $fn: special variables are dynamically scoped, so a $fn set
// here would be overridden by whatever the calling .scad has (i.e. nothing),
// silently giving 5-segment corner spheres. It is passed explicitly instead.
smoothness = 48;

// Corner/edge rounding radius, mm. The body is the hull of spheres at each
// vertex, so this also fattens the die slightly - see size_mm() below.
rounding = 1.2;

// Name (and optional style) of the font used for the numbers.
font = "Arial:style=Bold";

// How deep the numbers are cut into the faces, mm.
text_depth = 0.9;

// Global multiplier on the auto-computed text size. 1.0 fits the number well
// inside the inscribed circle of the face, which reads a little timid on a
// printed die; 1.25 fills the faces without crowding the rounded edges, even
// for two-digit labels. Push much past that and numbers start running into the
// rounding, where the engraving gets shallow and the inlay gets thin.
text_scale = 1.25;

// Put a trailing period on 6 and 9 so they can be told apart.
mark_6_and_9 = true;

// --- d4 only -----------------------------------------------------------------
// The d4 is numbered at its corners rather than its face centers (see die()).
// How far each number sits from the face center toward its corner, as a
// fraction of that distance. Larger = tighter into the corners.
d4_corner_offset = 0.48;

// Multiplier on the corner numbers, which have to share a face three ways.
d4_text_scale = 0.80;

// ------------------------------------------------------------ size presets --

// Corner-to-corner diameter (circumscribed sphere) in mm, per die type.
// These give dice that sit at roughly standard tabletop sizes.
function size_mm(type) =
      type == "d4"  ? 24
    : type == "d6"  ? 27.7
    : type == "d8"  ? 22
    : type == "d10" ? 21
    : type == "d12" ? 25
    : type == "d20" ? 24
    : 24;

// -------------------------------------------------------------- geometry ----

phi = (1 + sqrt(5)) / 2;
iphi = 1 / phi;

// Pentagonal trapezohedron (the d10 shape).
// Two apexes on the Z axis plus two staggered rings of five vertices. The ratio
// between the apex height and the ring height is fixed by the requirement that
// each kite face be planar; see notes in README.md.
d10_h = 1.0;                     // apex height
d10_c = d10_h / 9.472136;        // ring height (+/-)

function vertices(type) =
      type == "d4" ? [[1,1,1], [1,-1,-1], [-1,1,-1], [-1,-1,1]]
    : type == "d6" ? [for (x = [1,-1], y = [1,-1], z = [1,-1]) [x,y,z]]
    : type == "d8" ? [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]
    : type == "d12" ? concat(
          [for (x = [1,-1], y = [1,-1], z = [1,-1]) [x,y,z]],
          [for (y = [iphi,-iphi], z = [phi,-phi]) [0,y,z]],
          [for (x = [iphi,-iphi], y = [phi,-phi]) [x,y,0]],
          [for (z = [iphi,-iphi], x = [phi,-phi]) [x,0,z]])
    : type == "d20" ? concat(
          [for (y = [1,-1], z = [phi,-phi]) [0,y,z]],
          [for (x = [1,-1], y = [phi,-phi]) [x,y,0]],
          [for (z = [1,-1], x = [phi,-phi]) [x,0,z]])
    : type == "d10" ? concat(
          [[0,0,d10_h], [0,0,-d10_h]],
          [for (i = [0:4]) [cos(i*72),      sin(i*72),      d10_c]],
          [for (i = [0:4]) [cos(i*72 + 36), sin(i*72 + 36), -d10_c]])
    : undef;

// Faces as lists of indices into vertices(type), wound counter-clockwise when
// seen from outside. Only the vertex positions matter for the body (it is a
// hull), but the numbering needs one entry per face and a correct plane.
function faces(type) =
      type == "d4" ? [[0,1,2],[0,3,1],[0,2,3],[1,3,2]]
    : type == "d6" ? [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
    : type == "d8" ? [[0,2,4],[2,1,4],[1,3,4],[3,0,4],
                      [2,0,5],[1,2,5],[3,1,5],[0,3,5]]
    // d10: index 0 = top apex, 1 = bottom apex, 2..6 = upper ring, 7..11 = lower
    : type == "d10" ? concat(
          [for (i = [0:4]) [0, 2 + i, 7 + i, 2 + (i+1)%5]],
          [for (i = [0:4]) [1, 7 + (i+1)%5, 2 + (i+1)%5, 7 + i]])
    : type == "d12" ? dodeca_faces()
    : type == "d20" ? icosa_faces()
    : undef;

// The d12 and d20 face lists are tedious to write out by hand and easy to get
// wrong, so they are derived from the geometry instead: every set of coplanar
// vertices at the face-plane distance is a face.
function dodeca_faces() = hull_faces("d12", 5);
function icosa_faces()  = hull_faces("d20", 3);

// Collect the vertices lying on each face plane. For a face-transitive solid
// centered on the origin, every face plane sits at the same distance `inr` from
// the center, and each face normal points at a distinct direction; we recover
// them from the vertex combinations rather than enumerating faces manually.
function hull_faces(type, n) =
    let (v = vertices(type),
         norms = face_normals(type),
         inr = plane_dist(type))
    [for (nv = norms)
        order_face([for (i = [0:len(v)-1]) if (abs(v[i] * nv - inr) < 1e-6) i],
                   v, nv)];

// All cyclic permutations of [a,b,c], over every sign combination of the
// non-zero entries. Generates the normal families below.
function cyclic(a, b, c) =
    [for (s = sign_combos([a,b,c]), k = [0:2]) [s[k % 3], s[(k+1) % 3], s[(k+2) % 3]]];

function sign_combos(p) =
    [for (x = p[0] == 0 ? [0] : [p[0], -p[0]],
          y = p[1] == 0 ? [0] : [p[1], -p[1]],
          z = p[2] == 0 ? [0] : [p[2], -p[2]]) [x,y,z]];

// Face normals. These are the vertex directions of the dual solid, but the dual
// has the opposite chirality to the vertex lists above, so they are spelled out
// rather than reusing vertices(): a dodecahedron face points along [0,phi,1],
// an icosahedron face along [1,1,1] or [1/phi,0,phi].
function face_normals(type) =
      type == "d12" ? [for (p = cyclic(0, phi, 1)) unit(p)]
    : type == "d20" ? concat(
          [for (p = sign_combos([1,1,1])) unit(p)],
          [for (p = cyclic(iphi, 0, phi)) unit(p)])
    : undef;

// Distance from the center to any face plane, for the solids built by
// hull_faces(). Derived from one known face plane and one vertex on it.
function plane_dist(type) =
      type == "d12" ? unit([0,phi,1]) * [1,1,1]
    : type == "d20" ? unit([1,1,1]) * [0,1,phi]
    : undef;

// Sort a face's vertex indices into a consistent winding around its normal, so
// that polyhedron() would accept them and centroids come out right.
function order_face(idx, v, nv) =
    let (c = vsum([for (i = idx) v[i]]) / len(idx),
         u = unit(v[idx[0]] - c),
         w = cross(nv, u))
    [for (p = sortkey([for (i = idx) [atan2((v[i]-c) * w, (v[i]-c) * u), i]])) p[1]];

// ------------------------------------------------------------- vector math --

function vsum(l, i = 0) = i >= len(l) ? [0,0,0] : l[i] + vsum(l, i + 1);
function unit(v) = v / norm(v);

// Insertion sort on the first element of each [key, value] pair.
function sortkey(l) =
    len(l) <= 1 ? l
    : let (pivot = l[0], rest = [for (i = [1:len(l)-1]) l[i]])
      concat(sortkey([for (e = rest) if (e[0] <  pivot[0]) e]),
             [pivot],
             sortkey([for (e = rest) if (e[0] >= pivot[0]) e]));

// Rotation matrix taking +Z onto `n`, with `up` pulled onto the face's +Y.
function orient(n, up) =
    let (z = unit(n),
         y = unit(up - z * (up * z)),
         x = cross(y, z))
    [[x[0], y[0], z[0], 0],
     [x[1], y[1], z[1], 0],
     [x[2], y[2], z[2], 0],
     [0, 0, 0, 1]];

// Which way is "up" when reading a face: world +Z, unless the face points that
// way already, in which case fall back to +Y.
function up_for(n) = abs(unit(n) * [0,0,1]) > 0.99 ? [0,1,0] : [0,0,1];

// Outward unit normal of a face, from the cross product of two of its edges.
// Note this is NOT the direction of the face centroid: on the d10 the kite
// faces are not centered on their own normal, so that shortcut puts the numbers
// on a tilted plane buried inside the solid.
function face_normal(v, f) =
    let (n = unit(cross(v[f[1]] - v[f[0]], v[f[2]] - v[f[0]])),
         c = vsum([for (i = f) v[i]]) / len(f))
    n * c < 0 ? -n : n;

// Radius of the largest circle that fits inside a face, in model units.
// Measured as the shortest distance from the centroid to an edge.
function face_inradius(v, f) =
    let (c = vsum([for (i = f) v[i]]) / len(f))
    min([for (j = [0:len(f)-1])
            let (a = v[f[j]], b = v[f[(j+1) % len(f)]])
            norm(cross(b - a, c - a)) / norm(b - a)]);

// ------------------------------------------------------------------ model ---

// Trailing period on 6 and 9 so a rolled die is not ambiguous.
function marked(label) =
    mark_6_and_9 && (label == "6" || label == "9") ? str(label, ".") : label;

// Text is sized to the inscribed circle of the face, then backed off for
// multi-character labels so wide numbers still fit.
function auto_font_size(label, fi) =
    fi * text_scale * (len(label) <= 1 ? 0.95 : 0.72);

// The d4 is read at the corner that points up, not at a face, so its numbers
// belong to vertices rather than faces: each of the four values is written three
// times, once on each face meeting its vertex. The three faces visible on a
// resting d4 therefore all show the same number at the apex.
function corner_numbered(type) = type == "d4";

// One number, cut into the face plane. `where` is a point on the unrounded face
// plane, `n` the face normal, `up` the in-plane direction the text reads toward.
module engrave(label, where, n, up, size) {
    // The hull pushes the real surface out by `rounding` past the face plane,
    // so follow the normal out to meet it.
    translate(where + n * rounding)
        multmatrix(orient(n, up))
            translate([0, 0, -text_depth])
                linear_extrude(text_depth * 2)
                    text(label, font = font, size = size,
                         halign = "center", valign = "center");
}

/*
`part` selects what gets rendered, so one definition serves both the
single-color print and a two-material AMS print:

    "all"     the finished die, numbers recessed into it (default)
    "body"    same thing - the half an AMS print does in the body color
    "numbers" just the plugs that fill those recesses, in the number color

"body" and "numbers" are exact complements in the same coordinate frame, so
loading them as two parts of one object lines them up with no repositioning.
*/
module die(type, labels, part = "all") {
    v = vertices(type);
    f = faces(type);
    assert(!is_undef(v), str("unknown die type: ", type));
    slots = corner_numbered(type) ? len(v) : len(f);
    assert(len(labels) == slots,
           str(type, " needs ", slots, " labels but got ", len(labels),
               corner_numbered(type) ? " (one per corner)" : " (one per face)"));
    assert(part == "all" || part == "body" || part == "numbers",
           str("unknown part: ", part));

    // Scale so the corner-to-corner size matches the preset, rounding included.
    circum = max([for (p = v) norm(p)]);
    scale_f = (size_mm(type) / 2 - rounding) / circum;
    sv = [for (p = v) p * scale_f];

    // Body: hull of a sphere at every corner. Rounds corners and edges in one
    // step and keeps the faces perfectly flat in between.
    module body() {
        hull() for (p = sv) translate(p) sphere(r = rounding, $fn = smoothness);
    }

    // The raw number solids. They stick out past the surface, so they are always
    // either cut from the body or clipped back to it - never used on their own.
    module numbers() {
        for (i = [0:len(f)-1]) {
            n = face_normal(sv, f[i]);
            c = vsum([for (j = f[i]) sv[j]]) / len(f[i]);
            fi = face_inradius(sv, f[i]);

            if (corner_numbered(type)) {
                // Three numbers per face, one pushed out toward each corner and
                // rotated to read from the middle of the face outward - so the
                // number stands upright when its corner is the top of the die.
                for (j = f[i]) {
                    label = marked(labels[j]);
                    engrave(label, c + (sv[j] - c) * d4_corner_offset, n,
                            sv[j] - c,
                            auto_font_size(label, fi) * d4_text_scale);
                }
            } else {
                label = marked(labels[i]);
                engrave(label, c, n, up_for(n), auto_font_size(label, fi));
            }
        }
    }

    if (part == "numbers") {
        // Clipped to the body, so each plug stops flush with the face.
        intersection() { body(); numbers(); }
    } else {
        difference() { body(); numbers(); }
    }
}

// Demo render. `use <dice.scad>` ignores everything below.
die("d20", [for (i = [1:20]) str(i)]);
