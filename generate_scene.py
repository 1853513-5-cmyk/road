"""Generate a flat top-down scene: green grass with very little stud-like
texture and a wide dark gray road running through the middle.

Outputs:
  - scene/grass_road_topdown.png : rendered top-down image of the scene
  - scene/grass_road.glb         : matching flat 3D plane textured with it
"""

import io
import json
import random
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

random.seed(42)
np.random.seed(42)

W = 1024                 # texture width  (world: 20 m)
H = 512                  # texture height (world: 10 m)
ROAD_HALF = 96           # road half-width in pixels -> wide road (~37% of height)
STUD_SPACING = 84        # sparse studs on the grass ("very little" texture)
STUD_RADIUS = 6

SCENE_DIR = Path(__file__).parent / "scene"
SCENE_DIR.mkdir(exist_ok=True)


def make_grass(size):
    """Flat green base with only subtle noise."""
    w, h = size
    base = np.zeros((h, w, 3), dtype=np.float32)
    base[:, :, 0] = 74.0
    base[:, :, 1] = 154.0
    base[:, :, 2] = 58.0
    base += np.random.normal(0, 5, (h, w, 1))
    return np.clip(base, 0, 255).astype(np.uint8)


def draw_road(draw, size):
    """Wide dark gray road horizontally across the middle."""
    w, h = size
    cy = h // 2
    y0, y1 = cy - ROAD_HALF, cy + ROAD_HALF
    draw.rectangle([0, y0, w, y1], fill=(58, 58, 62))            # dark gray asphalt
    for _ in range(int(w * (y1 - y0) * 0.0015)):                 # subtle speckle
        sx = random.randint(0, w - 1)
        sy = random.randint(y0 + 2, y1 - 3)
        s = random.randint(48, 74)
        draw.point((sx, sy), fill=(s, s, s + 3))
    draw.line([(0, y0 + 1), (w, y0 + 1)], fill=(88, 88, 92), width=3)     # curb edges
    draw.line([(0, y1 - 2), (w, y1 - 2)], fill=(88, 88, 92), width=3)
    x = 10
    while x < w:                                                  # dashed center line
        draw.line([(x, cy), (min(x + 46, w), cy)], fill=(228, 202, 62), width=5)
        x += 46 + 34
    return y0, y1


def draw_studs(draw, size, road_bounds):
    """Very little stud-like texture: small circular bumps on grass only."""
    w, h = size
    ry0, ry1 = road_bounds
    offset = True
    for gy in range(STUD_SPACING // 2, h, STUD_SPACING):
        xs = range(0, w, STUD_SPACING) if offset else \
             range(STUD_SPACING // 2, w, STUD_SPACING)
        offset = not offset
        for gx in xs:
            if ry0 - 8 <= gy <= ry1 + 8:       # keep studs off the road
                continue
            r = STUD_RADIUS
            draw.ellipse([gx - r + 1, gy - r + 2, gx + r + 1, gy + r + 2],
                         fill=(48, 105, 38))   # soft shadow
            draw.ellipse([gx - r, gy - r, gx + r, gy + r],
                         fill=(98, 182, 78))   # stud body
            hr = max(2, r // 2)
            draw.ellipse([gx - hr - 1, gy - hr - 1, gx + hr - 1, gy + hr - 1],
                         fill=(136, 212, 110))  # highlight


def render_texture():
    img = Image.fromarray(make_grass((W, H)))
    draw = ImageDraw.Draw(img)
    road_bounds = draw_road(draw, (W, H))
    draw_studs(draw, (W, H), road_bounds)
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    out = SCENE_DIR / "grass_road_topdown.png"
    img.save(out)
    print("Saved", out)
    return img


# ---------------------------------------------------------------------------
# Minimal GLB writer: one flat quad (XY plane) textured with the PNG above.
# ---------------------------------------------------------------------------
def write_glb(path, png_bytes, sx=20.0, sy=10.0):
    positions = np.array([
        [-sx / 2, -sy / 2, 0.0],
        [ sx / 2, -sy / 2, 0.0],
        [ sx / 2,  sy / 2, 0.0],
        [-sx / 2,  sy / 2, 0.0],
    ], dtype="<f4")
    uvs = np.array([
        [0.0, 1.0], [1.0, 1.0], [1.0, 0.0], [0.0, 0.0],
    ], dtype="<f4")  # flip V so image top maps to +Y
    indices = np.array([0, 1, 2, 0, 2, 3], dtype="<u2")

    pos_bytes = positions.tobytes()
    uv_bytes = uvs.tobytes()
    idx_bytes = indices.tobytes()
    idx_pad = (4 - len(idx_bytes) % 4) % 4
    geo_len = len(idx_bytes) + idx_pad + len(pos_bytes) + len(uv_bytes)
    bin_chunk = idx_bytes + b"\x00" * idx_pad + pos_bytes + uv_bytes

    minv = [float(positions[:, i].min()) for i in range(3)]
    maxv = [float(positions[:, i].max()) for i in range(3)]

    gltf = {
        "asset": {"version": "2.0", "generator": "generate_scene.py"},
        "scene": 0,
        "scenes": [{"nodes": [0], "name": "GrassRoadScene"}],
        "nodes": [{"mesh": 0, "name": "GrassRoadPlane"}],
        "meshes": [{
            "primitives": [{
                "attributes": {"POSITION": 0, "TEXCOORD_0": 1},
                "indices": 2,
                "material": 0,
            }],
        }],
        "materials": [{
            "name": "GrassRoadMaterial",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 0, "texCoord": 0},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.9,
            },
        }],
        "textures": [{"sampler": 0, "source": 0}],
        "images": [{"bufferView": 3, "mimeType": "image/png"}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987}],
        "accessors": [
            {"bufferView": 1, "componentType": 5126, "count": 4,
             "type": "VEC3", "min": minv, "max": maxv},
            {"bufferView": 2, "componentType": 5126, "count": 4,
             "type": "VEC2"},
            {"bufferView": 0, "componentType": 5123, "count": 6,
             "type": "SCALAR"},
        ],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(idx_bytes),
             "target": 34963},
            {"buffer": 0, "byteOffset": len(idx_bytes) + idx_pad,
             "byteLength": len(pos_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": len(idx_bytes) + idx_pad + len(pos_bytes),
             "byteLength": len(uv_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": geo_len,
             "byteLength": len(png_bytes)},
        ],
        "buffers": [{"byteLength": geo_len + len(png_bytes)}],
    }

    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    bin_chunk += png_bytes
    bin_chunk += b"\x00" * ((4 - len(bin_chunk) % 4) % 4)

    total = 12 + (8 + len(json_bytes)) + (8 + len(bin_chunk))
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        f.write(json_bytes)
        f.write(struct.pack("<II", len(bin_chunk), 0x004E4942))
        f.write(bin_chunk)
    print("Saved", path)


if __name__ == "__main__":
    img = render_texture()
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    write_glb(SCENE_DIR / "grass_road.glb", buf.getvalue())
