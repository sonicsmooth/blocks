#!/usr/bin/env python3
"""Convert 512px supersampled PNGs to multi-resolution .ico files.

Writes ICO files manually (not via PIL's ICO plugin, which generates spurious
duplicate entries via append_images).  Each size is stored as a PNG chunk
inside the ICO container — supported by Windows Vista+ — giving full RGBA
alpha and exact control over which sizes appear.

Source:  icons/png/<name>_src512.png  (512px supersampled composite)
Output:  icons/ico/<name>.ico

ICO sizes: 16, 32, 48, 128, 256 px  (all LANCZOS from 512px source)
"""
import io, os, struct
from PIL import Image

PNG_DIR = os.path.join("..", "icons", "png")
ICO_DIR = os.path.join("..", "icons", "ico")
os.makedirs(ICO_DIR, exist_ok=True)

ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def write_ico(path, imgs_by_size):
    """Write a well-formed .ico with one PNG entry per size.

    imgs_by_size: dict of {int_size: PIL.Image (RGBA)}
    Width/height byte is 0 for 256 (per ICO spec).
    """
    sizes = sorted(imgs_by_size)
    # Encode every image as PNG bytes
    chunks = {}
    for s in sizes:
        buf = io.BytesIO()
        imgs_by_size[s].save(buf, format="PNG")
        chunks[s] = buf.getvalue()

    n = len(sizes)
    # Offsets: 6-byte header + n*16-byte directory entries
    data_start = 6 + n * 16
    offsets = []
    pos = data_start
    for s in sizes:
        offsets.append(pos)
        pos += len(chunks[s])

    with open(path, "wb") as f:
        # ICONDIR header
        f.write(struct.pack("<HHH", 0, 1, n))
        # ICONDIRENTRY × n
        for i, s in enumerate(sizes):
            w = h = 0 if s == 256 else s
            f.write(struct.pack("<BBBBHHII",
                w, h,           # width, height (0 → 256)
                0,              # color count (0 = 32-bit)
                0,              # reserved
                1,              # planes
                32,             # bit depth
                len(chunks[s]), # image data byte size
                offsets[i],     # absolute offset in file
            ))
        # Image data
        for s in sizes:
            f.write(chunks[s])


names = [
    p.replace("_src512.png", "")
    for p in sorted(os.listdir(PNG_DIR))
    if p.endswith("_src512.png")
]

for name in names:
    src = Image.open(os.path.join(PNG_DIR, f"{name}_src512.png")).convert("RGBA")
    imgs = {s: src.resize((s, s), Image.LANCZOS) for s in ICO_SIZES}
    dst = os.path.join(ICO_DIR, f"{name}.ico")
    write_ico(dst, imgs)
    print(f"  {name}.ico  ({', '.join(str(s) for s in ICO_SIZES)} px)")

print(f"\nWrote {len(names)} ICO files to {ICO_DIR}/")
