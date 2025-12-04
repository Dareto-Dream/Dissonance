#!/usr/bin/env python3
"""
Optimized Dissonance Packer:
- max-rect packing with rotation
- no forced square atlas
- dynamically grows width AND height
- preserves input transparency
- outputs pretty-printed XML
"""

import os
import argparse
from PIL import Image
import xml.etree.ElementTree as ET
from xml.dom import minidom

# ---------------------------------------------------
# Max-Rect Bin
# ---------------------------------------------------

class MaxRectBin:
    def __init__(self, width, height):
        self.bin_width = width
        self.bin_height = height
        self.free_rects = [(0, 0, width, height)]

    def find_position(self, w, h):
        """Find the best-fit location for w,h or rotated h,w."""
        best = None
        best_score = 1e15

        for rx, ry, rw, rh in self.free_rects:
            # Try normal
            if w <= rw and h <= rh:
                score = rw * rh - w * h
                if score < best_score:
                    best_score = score
                    best = (rx, ry, False)

            # Try rotated
            if h <= rw and w <= rh:
                score = rw * rh - h * w
                if score < best_score:
                    best_score = score
                    best = (rx, ry, True)

        return best

    def split_free_rects(self, px, py, pw, ph):
        """Cut free rectangles around placed rect."""
        new_free = []

        for rx, ry, rw, rh in self.free_rects:
            if px >= rx + rw or px + pw <= rx or py >= ry + rh or py + ph <= ry:
                new_free.append((rx, ry, rw, rh))
                continue

            # Left
            if px > rx:
                new_free.append((rx, ry, px - rx, rh))

            # Right
            if px + pw < rx + rw:
                new_free.append((px + pw, ry, (rx + rw) - (px + pw), rh))

            # Top
            if py > ry:
                new_free.append((max(rx, px), ry, min(rw, pw), py - ry))

            # Bottom
            if py + ph < ry + rh:
                new_free.append((max(rx, px), py + ph, min(rw, pw), (ry + rh) - (py + ph)))

        self.free_rects = new_free

    def insert(self, w, h):
        pos = self.find_position(w, h)
        if pos is None:
            return None
        x, y, rotated = pos
        rw, rh = (h, w) if rotated else (w, h)
        self.split_free_rects(x, y, rw, rh)
        return x, y, rotated


# ---------------------------------------------------
# Basic Category Detection (face/body only for now)
# ---------------------------------------------------

def detect_category(fn):
    name = os.path.splitext(fn)[0]
    if name[0].isdigit():
        return "body"
    return "face"


def collect_sprites(folder):
    out = []
    for f in sorted(os.listdir(folder)):
        if f.lower().endswith(".png"):
            out.append((os.path.join(folder, f), detect_category(f)))
    return out


# ---------------------------------------------------
# Packing
# ---------------------------------------------------

def pack_sprites(sprites, start_w=512, start_h=512, padding=2):
    # Load images
    imgs = [(path, cat, Image.open(path).convert("RGBA")) for path, cat in sprites]

    width = start_w
    height = start_h

    while True:
        bin_pack = MaxRectBin(width, height)
        placements = []
        failed = False

        for path, cat, img in imgs:
            w, h = img.size
            pos = bin_pack.insert(w + padding, h + padding)
            if pos is None:
                failed = True
                break

            x, y, rot = pos
            placements.append((path, cat, x, y, rot, img))

        if not failed:
            break

        # Expand width first, then height
        if width <= height:
            width *= 2
        else:
            height *= 2

        if width > 16384 or height > 16384:
            raise RuntimeError("Sprite too large to pack into reasonable atlas.")

    # Compute minimal needed height
    atlas_h = max(
        y + (img.size[0] if rot else img.size[1])
        for (_, _, x, y, rot, img) in placements
    ) + padding

    # Compute minimal needed width
    atlas_w = max(
        x + (img.size[1] if rot else img.size[0])
        for (_, _, x, y, rot, img) in placements
    ) + padding

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))

    final = []
    for path, cat, x, y, rot, img in placements:
        dr = img.rotate(90, expand=True) if rot else img
        atlas.paste(dr, (x, y), dr)
        final.append((path, cat, x, y, rot, img))

    return atlas, final


# ---------------------------------------------------
# Pretty XML
# ---------------------------------------------------

def write_xml(placements, xml_path):
    root = ET.Element("TextureAtlas")
    root.set("imagePath", "atlas.png")

    counters = {"body": 1, "face": 1}

    for path, cat, x, y, rot, img in placements:
        w, h = img.size
        if rot:
            w, h = h, w

        name = f"{cat}{counters[cat]:04d}"
        counters[cat] += 1

        st = ET.SubElement(root, "SubTexture")
        st.set("name", name)
        st.set("x", str(x))
        st.set("y", str(y))
        st.set("width", str(w))
        st.set("height", str(h))
        if rot:
            st.set("rotated", "true")

    # Pretty print
    xml_str = minidom.parseString(ET.tostring(root)).toprettyxml(indent="    ")
    with open(xml_path, "w", encoding="utf-8") as f:
        f.write(xml_str)


# ---------------------------------------------------
# Main
# ---------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", default="atlas.png")
    ap.add_argument("--xml", default="atlas.xml")
    args = ap.parse_args()

    sprites = collect_sprites(args.input)
    atlas, placements = pack_sprites(sprites)
    atlas.save(args.output)
    write_xml(placements, args.xml)

    print("Done.")
    print("Output:", args.output)
    print("XML:", args.xml)


if __name__ == "__main__":
    main()
