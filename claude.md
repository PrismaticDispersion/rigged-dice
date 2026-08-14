# Custom dice using openscad

`claude --resume b565ee3b-8810-4f10-a3b9-f5c8e7276384`

need custom randomized dice for my campaign
- 6xd6
- 6xd4
- 6xd8
- 6xd10 0-9
- 6xd10 times 10 (for percentile dice) 00-90
- 6xd12
- 6xd20

I would like the following dice to be made for each set:

1) all 1's except 1 side with highest value possible
2) all highest value except 1 side with lowest
3) all random in top 1/3
4) all random in bottom 1/3
5) all random in middle 1/3
6) all a single random value from the middle 1/3 with one high value

1/3 can be inclusive of values on the edge

steps:
1. make open scad model of the geometry with variables for the text on each side
2. make a python script that can replace the values and execute the openscad -> stl gen
3. put each type of dice in their own folder with correspondingly named stls

openscad exe: ~/3DObjects/OpenSCAD.AppImage

later additions:
- dual-color for bambu ams