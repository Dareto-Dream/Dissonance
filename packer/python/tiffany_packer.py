#!/usr/bin/env python3
"""
Dissonance Character Packer — Tiffany Edition (2025)
- Detects Tiffany sprite categories:
    bodyL####, bodyR####,
    head####, headL####, headR####,
    mouth####,
    overlay####,
    full####,
    why#### (special file)
- Max-rect packing with rotation
- Dynamic atlas width/height
- Pretty-printed XML
"""

import os
import argparse
from PIL import Image
import xml.etree.ElementTree as ET
from xml.dom import minidom

# ---------------------------------------------------
# Max-Rect Bin Packing
# ---------------------------------------------------

class MaxRectBin:
    def __init__(self, width, height):
        self.bin_width = width
        self.bin_height = height
        self.free = [(0, 0, width, height)]

    def find_pos(self, w, h):
        best = None
        best_score = 999999999

        for (rx, ry, rw, rh) in self.free:
            # normal
            if w <= rw and h <= rh:
                score = rw * rh - w * h
                if score < best_score:
                    best_score = score
                    best = (rx, ry, False)

            # rotated
            if h <= rw and w <= rh:
                score = rw * rh - h * w
                if score < best_score:
                    best_score = score
                    best = (rx, ry, True)

        return best

    def split(self, px, py, pw, ph):
        new = []

        for (rx, ry, rw, rh) in self.free:
            if px >= rx + rw or px + pw <= rx or py >= ry + rh or py + ph <= ry:
                new.append((rx, ry, rw, rh))
                continue

            # left
            if px > rx:
                new.append((rx, ry, px - rx, rh))

            # right
            if px + pw < rx + rw:
                new.append((px + pw, ry, (rx + rw) - (px + pw), rh))

            # top
            if py > ry:
                new.append((max(px, rx), ry, min(pw, rw), py - ry))

            # bottom
            if py + ph < ry + rh:
                new.append((max(px, rx), py + ph, min(pw, rw), (ry + rh) - (py + ph)))

        self.free = new

    def insert(self, w, h):
        pos = self.find_pos(w, h)
        if pos is None:
            return None
        x, y, rot = pos
        sw, sh = (h, w) if rot else (w, h)
        self.split(x, y, sw, sh)
        return x, y, rot


# ---------------------------------------------------
# CATEGORY DETECTION
# ---------------------------------------------------

def detect_category(filename):
    name = os.path.splitext(filename)[0].lower()

    # SPECIAL (requested)
    if name == "whathaveidone":
        return "why"

    # FULL composites
    if name.startswith("ch"):
        return "full"

    # HEADS
    if name == "head":
        return "head"
    if name.startswith("head") and name.endswith("l"):
        return "headL"
    if name.startswith("head") and name.endswith("r"):
        return "headR"

    # BODY poses
    # format: digit + 'l' or 'r'
    if len(name) >= 2 and name[0].isdigit():
        if name.endswith("l"):
            return "bodyL"
        if name.endswith("r"):
            return "bodyR"

    # MOUTH expressions (single letter a–o)
    if len(name) == 1 and name.isalpha() and name in "abcdefghijklmno":
        return "mouth"

    # OVERLAYS
    if name in ["blush", "tears"]:
        return "overlay"

    # fallback
    return "overlay"


# ---------------------------------------------------
# LOAD SPRITES
# ---------------------------------------------------

def collect_sprites(folder):
    sprites = []
    for f in sorted(os.listdir(folder)):
        if f.lower().endswith(".png"):
            full = os.path.join(folder, f)
            sprites.append((full, detect_category(f)))
    return sprites


# ---------------------------------------------------
# PACKING
# ---------------------------------------------------

def pack_sprites(sprites, start_w=512, start_h=512, padding=2):
    imgs = [(p, c, Image.open(p).convert("RGBA")) for (p, c) in sprites]

    width = start_w
    height = start_h

    while True:
        binpack = MaxRectBin(width, height)
        placements = []
        fail = False

        for path, cat, img in imgs:
            w, h = img.size
            pos = binpack.insert(w + padding, h + padding)
            if pos is None:
                fail = True
                break

            x, y, rot = pos
            placements.append((path, cat, x, y, rot, img))

        if not fail:
            break

        # expand width or height
        if width <= height:
            width *= 2
        else:
            height *= 2

        if width > 16384 or height > 16384:
            raise RuntimeError("Atlas grew too large to pack!")

    # shrink atlas to tight bounds
    atlas_w = max(
        x + (img.size[1] if rot else img.size[0])
        for (_, _, x, y, rot, img) in placements
    ) + padding

    atlas_h = max(
        y + (img.size[0] if rot else img.size[1])
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
# PRETTY XML OUTPUT
# ---------------------------------------------------

def write_xml(placements, xml_path):
    root = ET.Element("TextureAtlas")
    root.set("imagePath", "atlas.png")

    counters = {}

    for path, cat, x, y, rot, img in placements:
        counters.setdefault(cat, 1)

        # rotated width/height
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

    pretty = minidom.parseString(ET.tostring(root)).toprettyxml(indent="    ")

    with open(xml_path, "w", encoding="utf-8") as f:
        f.write(pretty)


# ---------------------------------------------------
# MAIN
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

    print("Packed:", args.output)
    print("XML:", args.xml)


if __name__ == "__main__":
    main()
