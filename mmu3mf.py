"""Pack aligned meshes into a single multi-material 3MF for Bambu Studio.

A 3MF is a zip of XML, so this needs nothing outside the standard library.

Layout follows what Bambu Studio and OrcaSlicer write themselves, because they
ignore the PrusaSlicer convention (one merged mesh plus triangle-range volumes
in Slic3r_PE_model.config - that loads as a single uncolored part):

  * each part is its own <object> holding a mesh
  * one further <object> joins them with <components>, and that is what the
    build item places, so the parts arrive as one object you move as a unit
  * Metadata/model_settings.config names each part and pins it to a filament

Assemblies are written with the production extension (p:UUID on objects,
components and build items), which is what Bambu emits and expects to read back.
"""

from __future__ import annotations

import struct
import uuid
import zipfile
from pathlib import Path
from xml.sax.saxutils import quoteattr

# Vertices are welded on a grid this fine (mm). OpenSCAD emits float32 STL, so
# anything below ~1e-4 risks leaving coincident corners unmerged.
WELD = 1e-4

# Row-major 4x3 (3MF component/item) and 4x4 (Bambu part metadata) identities.
IDENTITY_4x3 = "1 0 0 0 1 0 0 0 1 0 0 0"
IDENTITY_4x4 = "1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1"

CONTAINER_ID = 1        # the object that groups the parts
FIRST_PART_ID = 2       # part objects are numbered from here


def read_binary_stl(path: Path) -> list[tuple[tuple[float, float, float], ...]]:
    """Triangles from a binary STL, as ((x,y,z), (x,y,z), (x,y,z)) tuples."""
    data = path.read_bytes()
    if data[:5] == b"solid" and b"facet" in data[:512]:
        raise ValueError(f"{path} is ASCII STL; export with --export-format binstl")
    count = struct.unpack("<I", data[80:84])[0]
    expected = 84 + count * 50
    if len(data) < expected:
        raise ValueError(f"{path}: truncated STL ({len(data)} < {expected} bytes)")
    tris = []
    for i in range(count):
        base = 84 + i * 50 + 12          # skip the per-facet normal
        tris.append(tuple(
            struct.unpack("<3f", data[base + j * 12: base + 12 + j * 12])
            for j in range(3)))
    return tris


def weld(triangles: list) -> tuple[list, list]:
    """Merge coincident corners. Returns (vertices, triangles-as-indices)."""
    index: dict[tuple[int, int, int], int] = {}
    vertices: list[tuple[float, float, float]] = []
    faces = []
    for tri in triangles:
        face = []
        for point in tri:
            key = tuple(round(c / WELD) for c in point)
            if key not in index:
                index[key] = len(vertices)
                vertices.append(point)
            face.append(index[key])
        if len(set(face)) == 3:          # drop slivers collapsed by welding
            faces.append(tuple(face))
    return vertices, faces


def mesh_volume(vertices: list, faces: list) -> float:
    """Signed volume via the divergence theorem; used to sanity-check parts."""
    total = 0.0
    for i, j, k in faces:
        a, b, c = vertices[i], vertices[j], vertices[k]
        total += (a[0] * (b[1] * c[2] - b[2] * c[1])
                  - a[1] * (b[0] * c[2] - b[2] * c[0])
                  + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
    return abs(total)


def is_closed(faces: list) -> bool:
    """True if every edge is shared by exactly two triangles (watertight)."""
    edges: dict[tuple[int, int], int] = {}
    for tri in faces:
        for a, b in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
            key = (min(a, b), max(a, b))
            edges[key] = edges.get(key, 0) + 1
    return all(n == 2 for n in edges.values())


CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
 <Default Extension="config" ContentType="application/xml"/>
 <Default Extension="png" ContentType="image/png"/>
</Types>
"""

RELS = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rel-1" Target="/3D/3dmodel.model" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
</Relationships>
"""


def build_model(parts: list[dict], name: str) -> str:
    """The 3MF core model: a mesh object per part, grouped by a components object."""
    out = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<model unit="millimeter" xml:lang="en-US"'
        ' xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"'
        ' xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06">',
        ' <metadata name="Application">dice generate.py</metadata>',
        f' <metadata name="Title">{name}</metadata>',
        ' <resources>',
    ]
    for part in parts:
        out += [f'  <object id="{part["id"]}" p:UUID="{part["uuid"]}" type="model"'
                f' name={quoteattr(part["name"])}>',
                '   <mesh>', '    <vertices>']
        out += [f'     <vertex x="{x:.6f}" y="{y:.6f}" z="{z:.6f}"/>'
                for x, y, z in part["vertices"]]
        out += ['    </vertices>', '    <triangles>']
        out += [f'     <triangle v1="{i}" v2="{j}" v3="{k}"/>'
                for i, j, k in part["faces"]]
        out += ['    </triangles>', '   </mesh>', '  </object>']

    container = str(uuid.uuid4())
    out += [f'  <object id="{CONTAINER_ID}" p:UUID="{container}" type="model"'
            f' name={quoteattr(name)}>', '   <components>']
    for part in parts:
        out.append(f'    <component objectid="{part["id"]}"'
                   f' p:UUID="{uuid.uuid4()}" transform="{IDENTITY_4x3}"/>')
    out += ['   </components>', '  </object>', ' </resources>',
            f' <build p:UUID="{uuid.uuid4()}">',
            f'  <item objectid="{CONTAINER_ID}" p:UUID="{uuid.uuid4()}"'
            f' transform="{IDENTITY_4x3}" printable="1"/>',
            ' </build>', '</model>', '']
    return "\n".join(out)


def build_settings(parts: list[dict], name: str) -> str:
    """Bambu/Orca sidecar: names each part and assigns it a filament slot."""
    out = ['<?xml version="1.0" encoding="UTF-8"?>', '<config>',
           f'  <object id="{CONTAINER_ID}">',
           f'    <metadata key="name" value={quoteattr(name)}/>',
           '    <metadata key="extruder" value="1"/>']
    for part in parts:
        out += [f'    <part id="{part["id"]}" subtype="normal_part">',
                f'      <metadata key="name" value={quoteattr(part["name"])}/>',
                f'      <metadata key="matrix" value="{IDENTITY_4x4}"/>',
                f'      <metadata key="extruder" value="{part["extruder"]}"/>',
                '      <mesh_stat edges_fixed="0" degenerate_facets="0"'
                ' facets_removed="0" facets_reversed="0" backwards_edges="0"/>',
                '    </part>']
    out += ['  </object>', '</config>', '']
    return "\n".join(out)


def pack(out_path: Path, sources: list[tuple[str, Path, str]], name: str) -> dict:
    """Write `sources` as one multi-material 3MF.

    `sources` is [(part name, binary STL path, "#RRGGBBAA"), ...] in filament
    order: the first gets extruder 1, the second extruder 2, and so on.
    Returns per-part stats so the caller can report or verify them.
    """
    parts = []
    for slot, (part_name, stl, color) in enumerate(sources):
        vertices, faces = weld(read_binary_stl(stl))
        parts.append({
            "id": FIRST_PART_ID + slot, "uuid": str(uuid.uuid4()),
            "name": part_name, "color": color, "extruder": slot + 1,
            "vertices": vertices, "faces": faces, "triangles": len(faces),
            "closed": is_closed(faces), "volume": mesh_volume(vertices, faces),
        })

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", CONTENT_TYPES)
        zf.writestr("_rels/.rels", RELS)
        zf.writestr("3D/3dmodel.model", build_model(parts, name))
        zf.writestr("Metadata/model_settings.config", build_settings(parts, name))
    return {"parts": parts,
            "vertices": sum(len(p["vertices"]) for p in parts),
            "triangles": sum(p["triangles"] for p in parts)}
