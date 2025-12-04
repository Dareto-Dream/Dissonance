#!/usr/bin/env python3
"""
Dissonance Character Atlas Packer (Tiffany + Cassian Modular)
2025

Supports:
- Tiffany categories (bodyL, bodyR, head, headL, headR, mouth, overlay, full, why)
- Cassian Modular:
    base####,
    eyes####,
    brow####,
    mouthM####,
    nose####,
    pose#### (Poses/1.png, 2b.png etc)
- Full composites ("chxxxx")
- Special file: whathaveidone.png -> why####
- Max-rect packing with rotation
- Pretty-printed XML
- No forced square atlas
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
        self.free = [(0, 0, width, height)]
        self.width = width
        self.height = height

    def find(self, w, h):
        best = None
        best_score = 999999999

        for (rx, ry, rw, rh) in self.free:
            # Normal
            if w <= rw and h <= rh:
                score = rw * rh - w * h
                if score < best_score:
                    best = (rx, ry, False)
                    best_score = score
            # Rotated
            if h <= rw and w <= rh:
                score = rw * rh - h * w
                if score < best_score:
                    best = (rx, ry, True)
                    best_score = score

        return best

    def split(self, px, py, pw, ph):
        new = []
        for (rx, ry, rw, rh) in self.free:
            if px >= rx + rw or px + pw <= rx or py >= ry + rh or py + ph <= ry:
                new.append((rx, ry, rw, rh))
                continue

            # LEFT
            if px > rx:
                new.append((rx, ry, px - rx, rh))
            # RIGHT
            if px + pw < rx + rw:
                new.append((px + pw, ry, (rx + rw) - (px + pw), rh))
            # TOP
            if py > ry:
                new.append((max(rx, px), ry, min(rw, pw), py - ry))
            # BOTTOM
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
# CATEGORY DETECTION
# ---------------------------------------------------

def detect_category(path):
    """
    Handles Tiffany + Cassian modular.
    """

    lower = path.replace("\\", "/").lower()
    name = os.path.splitext(os.path.basename(path))[0].lower()

    # --------------------
    # SPECIAL
    # --------------------
    if name == "whathaveidone":
        return "why"

    # --------------------
    # FULL COMPOSITE (ch*)
    # --------------------
    if name.startswith("ch"):
        return "full"

    # --------------------
    # CASSIAN MODULAR
    # --------------------
    if "expressions/eyes/" in lower:
        return "eyes"

    if "expressions/eyebrows/" in lower or "expressions/brows/" in lower:
        return "brow"

    if "expressions/mouth/" in lower:
        return "mouthM"

    if "expressions/nose/" in lower:
        return "nose"

    if "poses/" in lower:
        return "pose"

    if name == "base":
        return "base"

    # --------------------
    # TIFFANY BODY
    # --------------------
    if len(name) >= 2 and name[0].isdigit():
        # Ending l/r means directional body
        if name.endswith("l"):
            return "bodyL"
        if name.endswith("r"):
            return "bodyR"
        return "pose"  # fallback for numeric poses

    # --------------------
    # TIFFANY HEADS
    # --------------------
    if name == "head":
        return "head"
    if name.startswith("head") and name.endswith("l"):
        return "headL"
    if name.startswith("head") and name.endswith("r"):
        return "headR"

    # --------------------
    # TIFFANY MOUTH LETTERS
    # (single letter a–o)
    # --------------------
    if len(name) == 1 and name in "abcdefghijklmno":
        return "mouth"

    # --------------------
    # OVERLAYS
    # --------------------
    if name in ["blush", "tears"]:
        return "overlay"

    # fallback
    return "overlay"


# ---------------------------------------------------
# COLLECT FILES
# ---------------------------------------------------

def collect_sprites(folder):
    out = []
    for root, _, files in os.walk(folder):
        for f in sorted(files):
            if f.lower().endswith(".png"):
                full = os.path.join(root, f)
                out.append((full, detect_category(full)))
    return out


# ---------------------------------------------------
# PACKING
# ---------------------------------------------------

def pack_sprites(sprites, start_w=512, start_h=512, pad=2):
    imgs = [(p, c, Image.open(p).convert("RGBA")) for (p, c) in sprites]
    w = start_w
    h = start_h

    while True:
        pack = MaxRectBin(w, h)
        placements = []
        fail = False

        for path, cat, img in imgs:
            iw, ih = img.size
            pos = pack.insert(iw + pad, ih + pad)
            if pos is None:
                fail = True
                break

            x, y, rot = pos
            placements.append((path, cat, x, y, rot, img))

        if not fail:
            break

        # expand width or height
        if w <= h:
            w *= 2
        else:
            h *= 2

        if w > 16384 or h > 16384:
            raise RuntimeError("Atlas too large.")

    # Compute tight atlas bounds
    atlas_w = max(x + (img.size[1] if rot else img.size[0])
                  for (_, _, x, y, rot, img) in placements) + pad

    atlas_h = max(y + (img.size[0] if rot else img.size[1])
                  for (_, _, x, y, rot, img) in placements) + pad

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))

    final = []
    for path, cat, x, y, rot, img in placements:
        dib = img.rotate(90, expand=True) if rot else img
        atlas.paste(dib, (x, y), dib)
        final.append((path, cat, x, y, rot, img))

    return atlas, final


# ---------------------------------------------------
# XML OUTPUT
# ---------------------------------------------------

def write_xml(placements, out_path):
    root = ET.Element("TextureAtlas")
    root.set("imagePath", "atlas.png")

    counters = {}

    for path, cat, x, y, rot, img in placements:
        counters.setdefault(cat, 1)

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

    with open(out_path, "w", encoding="utf-8") as f:
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
