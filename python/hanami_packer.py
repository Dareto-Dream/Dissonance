#!/usr/bin/env python3
"""
Hanami Character Atlas Packer
Dissonance 2025

Takes a folder of frames 1.png - 13.png and packs them into:
    atlas.png
    atlas.xml

All frames are named in XML as:
    full0001
    full0002
    ...

Optimized packing with rotation.
Pretty-printed XML.
"""

import os
import argparse
from PIL import Image
import xml.etree.ElementTree as ET
from xml.dom import minidom

# ---------------------------------------------------
# Max-Rect Bin Packer
# ---------------------------------------------------

class MaxRectBin:
    def __init__(self, width, height):
        self.free = [(0, 0, width, height)]
        self.width = width
        self.height = height

    def find(self, w, h):
        best = None
        best_score = 10**15

        for (rx, ry, rw, rh) in self.free:
            # Normal orientation
            if w <= rw and h <= rh:
                score = rw * rh - w * h
                if score < best_score:
                    best = (rx, ry, False)
                    best_score = score

            # Rotated orientation
            if h <= rw and w <= rh:
                score = rw * rh - h * w
                if score < best_score:
                    best = (rx, ry, True)
                    best_score = score

        return best

    def split(self, px, py, pw, ph):
        new = []
        for (rx, ry, rw, rh) in self.free:
            # No overlap → unchanged region
            if px >= rx + rw or px + pw <= rx or py >= ry + rh or py + ph <= ry:
                new.append((rx, ry, rw, rh))
                continue

            # Left region
            if px > rx:
                new.append((rx, ry, px - rx, rh))

            # Right region
            if px + pw < rx + rw:
                new.append((px + pw, ry, (rx + rw) - (px + pw), rh))

            # Top region
            if py > ry:
                new.append((max(rx, px), ry, min(rw, pw), py - ry))

            # Bottom region
            if py + ph < ry + rh:
                new.append((max(rx, px), py + ph, min(rw, pw), (ry + rh) - (py + ph)))

        self.free = new

    def insert(self, w, h):
        pos = self.find(w, h)
        if pos is None:
            return None

        x, y, rot = pos
        pw, ph = (h, w) if rot else (w, h)
        self.split(x, y, pw, ph)
        return x, y, rot

# ---------------------------------------------------
# Collect Hanami sprites
# ---------------------------------------------------

def collect_sprites(folder):
    sprites = []
    for f in sorted(os.listdir(folder)):
        if not f.lower().endswith(".png"):
            continue
        name = os.path.splitext(f)[0]
        if not name.isdigit():
            continue
        full = os.path.join(folder, f)
        sprites.append((int(name), full))
    sprites.sort(key=lambda x: x[0])
    return sprites

# ---------------------------------------------------
# Pack frames
# ---------------------------------------------------

def pack_sprites(sprites, pad=2, start_w=512, start_h=512):
    imgs = [(i, path, Image.open(path).convert("RGBA")) for (i, path) in sprites]
    w = start_w
    h = start_h

    while True:
        bin = MaxRectBin(w, h)
        placements = []
        fail = False

        for idx, path, img in imgs:
            iw, ih = img.size
            pos = bin.insert(iw + pad, ih + pad)
            if pos is None:
                fail = True
                break
            x, y, rot = pos
            placements.append((idx, path, x, y, rot, img))

        if not fail:
            break

        # expand atlas
        if w <= h:
            w *= 2
        else:
            h *= 2

        if w > 16384 or h > 16384:
            raise RuntimeError("Atlas too large for Hanami frames.")

    # compute final bounds
    atlas_w = max(x + (img.size[1] if rot else img.size[0]) for (_, _, x, y, rot, img) in placements) + pad
    atlas_h = max(y + (img.size[0] if rot else img.size[1]) for (_, _, x, y, rot, img) in placements) + pad

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))

    final = []
    for idx, path, x, y, rot, img in placements:
        dib = img.rotate(90, expand=True) if rot else img
        atlas.paste(dib, (x, y), dib)
        final.append((idx, x, y, rot, img))

    return atlas, final

# ---------------------------------------------------
# Write XML
# ---------------------------------------------------

def write_xml(placements, out_path):
    root = ET.Element("TextureAtlas")
    root.set("imagePath", "atlas.png")

    counter = 1

    for idx, x, y, rot, img in placements:
        w, h = img.size
        if rot:
            w, h = h, w

        name = f"full{counter:04d}"
        counter += 1

        st = ET.SubElement(root, "SubTexture")
        st.set("name", name)
        st.set("x", str(x))
        st.set("y", str(y))
        st.set("width", str(w))
        st.set("height", str(h))
        if rot:
            st.set("rotated", "true")

    pretty = minidom.parseString(ET.tostring(root)).toprettyxml(indent="    ")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(pretty)

# ---------------------------------------------------
# Main
# ---------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Hanami Atlas Packer")
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", default="atlas.png")
    ap.add_argument("--xml", default="atlas.xml")
    args = ap.parse_args()

    sprites = collect_sprites(args.input)
    atlas, placements = pack_sprites(sprites)
    atlas.save(args.output)
    write_xml(placements, args.xml)

    print("Hanami packed successfully.")
    print("Atlas:", args.output)
    print("XML:", args.xml)


if __name__ == "__main__":
    main()
