/*------------------------------------------------------------------------------
Parametric Easy-Print D20
Version 1.0

Copyright 2017 HalfwitTomfoolery
https://www.youmagine.com/halfwittomfoolery/designs

Licensed as Creative Commons Attribution version 4.0 or later.
https://creativecommons.org/licenses/by/4.0/
------------------------------------------------------------------------------*/

// Full diameter of die from corner to corner.
diameter = 152.4;

// Amount to round corners and edges.
rounding = 2;

// Name (and, optionally, style) of font to use.
// For information on font styles, see:
// https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Text
font = "Arial";

// Depth of lettering, scaled by font size.
letteringdepth = 0.08;

// Font size, in fairly arbitrary units.  Just play with it until you get what you want.
fontsize = 0.4;

// Distance to inset numbers into faces of the die (arbitrary units).
insetamount = 0.08;

// More negative == narrower text.  More positive == bolder text.
boldness = 0;

// Smoothness.  Higher produces a better quality model.
$fn = 32;

// Number of steps to add in the text bevelling process.
// More == better quality, but it takes vastly more time to render.
textbevelsteps = 30;

/*------------------------------------------------------------------------------
Number text
--------------------------------------------------------------------------------
The text of each number is configurable.  This allows you to use (depending on
the font) roman numerals, Braille, symbols, etc.  It also allows you to tune the
balance of numbers as you wish to try to better balance the fairness of the die.

Two examples are given here - an unshuffled version and a shuffled version.
------------------------------------------------------------------------------*/

// Unshuffled:
/*numbers = [
        "1",
        "2",
        "3",
        "4",
        "5",
        "6.",
        "7",
        "8",
        "9.",
        "10",
        "11",
        "12",
        "13",
        "14",
        "15",
        "16",
        "17",
        "18",
        "19",
        "20"
    ];*/
/* Pairwise shuffled using the following crude Python program:
n = [
    "1",
    "2",
    "3",
    "4",
    "5",
    "6.",
    "7",
    "8",
    "9.",
    "10",
    "11",
    "12",
    "13",
    "14",
    "15",
    "16",
    "17",
    "18",
    "19",
    "20"
  ];

for i in range(50):
  r = random.randrange(1,18);
  t = n[r];
  n[r] = n[19 - r];
  n[19 - r] = t;

print(n);

The idea behind doing this pairwise is that if there are any balance issues introduced due to the slicer, at least each pair should be roughly evenly balanced, which I would think would help reduce the possibility of bias toward the low or high end of the [1..20] range.
*/
numbers = [
    "7",
    "5",
    "12",
    "5",
    "12",
    "6",
    "13",
    "3",
    "3",
    "10",
    "10",
    "12",
    "11",
    "3",
    "11",
    "12",
    "2",
    "6",
    "9",
    "9",
];



/*==============================================================================
END TUNABLE PARAMETERS

From here on, it's mostly just functional code.  Play at your own risk.
==============================================================================*/

// We're using the orthogonal golden rectangles method of constructing a regular icosohedron, so we need to calculate the corners.
goldenratio = 2 / (1 + sqrt(5));
scalingfactor = diameter / (sqrt(goldenratio * goldenratio + 1) + rounding);
corners=[
        [1, 0, goldenratio],
        [-1, 0, goldenratio],
        [1, 0, -goldenratio],
        [-1, 0, -goldenratio],
        [goldenratio, 1, 0],
        [goldenratio, -1, 0],
        [-goldenratio, 1, 0],
        [-goldenratio, -1, 0],
        [0, goldenratio, 1],
        [0, goldenratio, -1],
        [0, -goldenratio, 1],
        [0, -goldenratio, -1]
    ];

// Amount to rotate the icosohedron so we have a flat top and bottom:
rotationamount = atan((1-goldenratio)/1);

// Z of the top flat surface, for the purposes of adding text.
// This could be properly calculated, but this is close enough.
flatsurfaceheightunscaled = 0.97 + (-boldness * 0.03);

// Axis to rotate numbers around one of the lower corners.
rotationaxisunrotated = [0, 1, goldenratio];
rotationaxis = [0, cos(135) * rotationaxisunrotated[1] - sin(135) * rotationaxisunrotated[1], cos(135) * rotationaxisunrotated[2] + sin(135) * rotationaxisunrotated[1]];

// This module generates bevelled text using progressive stepped insetting/outsetting.
module bevelledtext(t, font, fontsize, insetamount, depthamount)
{
    union()
    {
        insetdistance = insetamount * fontsize;
        depth = depthamount * fontsize;
        
        for(s = [0:textbevelsteps])
        {
            translate([0, 0, (-(s + 0.5) / textbevelsteps + 0.5) * depth])
            {
                linear_extrude(depth / textbevelsteps + 0.01)
                {
                    offset(r = -((s * 2 - textbevelsteps) / textbevelsteps) * insetdistance)
                    {
                        text(text = t, font = font, size = fontsize, halign = "center", valign = "center");
                    }
                }
            }
        }
    }
}

// Calculate the difference of the icosohedron and all of the text.
difference()
{
    // Icosohedron
    // Generated by adding spheres at vertices, then taking the hull.
    rotate([0, rotationamount, -90])
    {
        hull()
        {
            for(p = corners)
            {
                translate(p * scalingfactor) { sphere(r = rounding); }
            }
        }
    }
    
    // Add the text
    scale([scalingfactor, scalingfactor, scalingfactor])
    {
        union()
        {
            // Angles of rotation to place text at.
            // Order is:
            // [0] = Amount to rotate text to consistently place the bottom on a flat (makes it easier to tell "6" and "9" apart, aside from the trailing period).
            // [1] = Amount to rotate the text toward the centerline.
            // [2] = Amount to rotate around the precalculated axis from above to place numbers on faces closer to the centerline.
            // [3] = Amount to rotate around Z to place the text on a different side.
            angles = [
                    [0, 0, 0, 0],
                    [60, rotationamount * 2, 0, 0],
                    [60, rotationamount * 2, 0, 120],
                    [60, rotationamount * 2, 0, -120],
                    [60, rotationamount * 2, 72, 0],
                    [60, rotationamount * 2, -72, 0],
                    [60, rotationamount * 2, 72, 120],
                    [60, rotationamount * 2, -72, 120],
                    [60, rotationamount * 2, 72, -120],
                    [60, rotationamount * 2, -72, -120]
                ];
            for(i = [0 : 9])
            {
                // Rotate around Z to place numbers all the way around horizontally.
                rotate([0, 0, angles[i][3]])
                {
                    // Rotate around corner axis to place numbers on center faces.
                    rotate(a=angles[i][2], v=rotationaxis)
                    {
                        // Rotate to face closer to centerline.
                        rotate([angles[i][1], 0, 0])
                        {
                            // Rotate around Z for consistent flat placement.
                            rotate([0, 0, angles[i][0]])
                            {
                                // Add the top number.
                                translate([0, 0, flatsurfaceheightunscaled])
                                {
                                    bevelledtext(numbers[19 - i], font, fontsize, insetamount, letteringdepth);
                                }
                                
                                // Add the bottom number.
                                rotate([180, 0, 0])
                                {
                                    translate([0, 0, flatsurfaceheightunscaled])
                                    {
                                        bevelledtext(numbers[i], font, fontsize, insetamount, letteringdepth);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
