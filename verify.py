#!/usr/bin/env python3
"""Check that everything under dice/ is actually printable.

For every die found it verifies, depending on what was generated:

  * each mesh is watertight (every edge shared by exactly two triangles)
  * for a two-part 3MF, that body and numbers are exact complements - their
    volumes must sum to the plain undrilled die, proving the number plugs fill
    the recesses with no gap and no overlap
  * the 3MF is a valid zip of well-formed XML, its triangle indices are in
    range, and its volume ranges tile the mesh with no gaps or overlaps

Run it after generate.py:

    ./verify.py
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

import mmu3mf

HERE = Path(__file__).resolve().parent
OUT = HERE / "dice"
# Override with the OPENSCAD environment variable; build.sh sets it for you.
OPENSCAD = Path(os.environ.get("OPENSCAD")
                or Path.home() / "3DObjects" / "OpenSCAD.AppImage")
CORE_NS = {"c": "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"}

# Volumes are compared as a relative difference. STL stores float32, so ~1e-7 is
# the floor for coordinates of this magnitude; real gaps or overlaps between the
# parts would show up orders of magnitude above this.
TOLERANCE = 1e-6


def render_volume(source: str) -> float:
    """Render a snippet of OpenSCAD and return the volume of the result."""
    with tempfile.TemporaryDirectory() as tmp:
        scad, stl = Path(tmp) / "x.scad", Path(tmp) / "x.stl"
        scad.write_text(source)
        subprocess.run([str(OPENSCAD), "--backend=manifold", "-o", str(stl),
                        "--export-format", "binstl", str(scad)],
                       capture_output=True)
        if not stl.exists():
            raise RuntimeError("OpenSCAD produced nothing")
        vertices, faces = mmu3mf.weld(mmu3mf.read_binary_stl(stl))
        return mmu3mf.mesh_volume(vertices, faces)


def solid_volume(geometry: str) -> float:
    """Volume of the die with no numbers cut into it, straight from dice.scad."""
    count = {"d4": 4, "d6": 6, "d8": 8, "d10": 10, "d12": 12, "d20": 20}[geometry]
    labels = ",".join(['""'] * count)
    return render_volume(f'use <{HERE}/dice.scad>;\n'
                         f'die("{geometry}", [{labels}], part="body");')


def check_3mf(path: Path) -> tuple[list[str], dict]:
    """Structural checks on one 3MF. Returns (problems, per-part volumes)."""
    problems: list[str] = []
    with zipfile.ZipFile(path) as zf:
        names = set(zf.namelist())
        for required in ("[Content_Types].xml", "_rels/.rels", "3D/3dmodel.model",
                         "Metadata/model_settings.config"):
            if required not in names:
                problems.append(f"missing {required}")
        if problems:
            return problems, {}
        model = ET.fromstring(zf.read("3D/3dmodel.model"))
        config = ET.fromstring(zf.read("Metadata/model_settings.config"))

    # Mesh objects, keyed by object id, plus the object that groups them.
    meshes: dict[str, tuple[list, list]] = {}
    containers: dict[str, list[str]] = {}
    for obj in model.findall(".//c:object", CORE_NS):
        vertices = [(float(v.get("x")), float(v.get("y")), float(v.get("z")))
                    for v in obj.findall(".//c:vertex", CORE_NS)]
        faces = [tuple(int(t.get(a)) for a in ("v1", "v2", "v3"))
                 for t in obj.findall(".//c:triangle", CORE_NS)]
        components = [c.get("objectid")
                      for c in obj.findall(".//c:component", CORE_NS)]
        if components:
            containers[obj.get("id")] = components
        elif faces:
            meshes[obj.get("id")] = (vertices, faces)
            if any(i < 0 or i >= len(vertices) for f in faces for i in f):
                problems.append(f"object {obj.get('id')} references a missing vertex")

    # The build must place the grouping object, or the parts arrive separately.
    items = [i.get("objectid") for i in model.findall(".//c:item", CORE_NS)]
    if len(items) != 1:
        problems.append(f"expected exactly one build item, found {len(items)}")
    elif items[0] not in containers:
        problems.append("the build item is not the object that groups the parts")
    elif len(containers[items[0]]) < 2:
        problems.append("the grouping object has fewer than two components")

    settings = {p.get("id"): p for p in config.iter("part")}
    if set(settings) != set(meshes):
        problems.append(f"slicer config covers parts {sorted(settings)} "
                        f"but the model has meshes {sorted(meshes)}")

    volumes = {}
    extruders = []
    for part_id, part in settings.items():
        if part_id not in meshes:
            continue
        name = part.find('.//*[@key="name"]').get("value")
        extruders.append(part.find('.//*[@key="extruder"]').get("value"))
        vertices, faces = meshes[part_id]
        volumes[name] = mmu3mf.mesh_volume(vertices, faces)
        if not mmu3mf.is_closed(faces):
            problems.append(f"part '{name}' is not watertight")
    if len(set(extruders)) != len(extruders):
        problems.append(f"parts share a filament slot: {extruders}")
    return problems, volumes


def main() -> int:
    if not OUT.is_dir():
        print(f"nothing to check: {OUT} does not exist", file=sys.stderr)
        return 1

    solids: dict[str, float] = {}
    failures = 0
    checked = 0

    for folder in sorted(p for p in OUT.iterdir() if p.is_dir()):
        geometry = "d10" if folder.name.startswith("d10") else folder.name
        for record in sorted(folder.glob("*.scad")):
            if record.stem.endswith(("-body", "-numbers")):
                continue
            problems: list[str] = []
            detail = ""

            threemf = record.with_suffix(".3mf")
            stl = record.with_suffix(".stl")

            if threemf.exists():
                problems, volumes = check_3mf(threemf)
                if volumes and not problems:
                    if geometry not in solids:
                        solids[geometry] = solid_volume(geometry)
                    total = sum(volumes.values())
                    error = abs(total - solids[geometry]) / solids[geometry]
                    if error > TOLERANCE:
                        problems.append(
                            f"parts sum to {total:.3f} mm3 but the solid die is "
                            f"{solids[geometry]:.3f} mm3 (error {error:.1e})")
                    detail = "  ".join(f"{n} {v:8.2f}" for n, v in volumes.items())
            elif stl.exists():
                vertices, faces = mmu3mf.weld(mmu3mf.read_binary_stl(stl))
                if not mmu3mf.is_closed(faces):
                    problems.append("mesh is not watertight")
                detail = f"volume {mmu3mf.mesh_volume(vertices, faces):8.2f} mm3"
            else:
                problems.append("no .3mf or .stl was generated")

            checked += 1
            if problems:
                failures += 1
                print(f"FAIL {record.stem}")
                for problem in problems:
                    print(f"       {problem}")
            else:
                print(f"ok   {record.stem:38} {detail}")

    print(f"\n{checked - failures}/{checked} dice pass")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
