import os
import xml.etree.ElementTree as ET
from PIL import Image

# -------- CONFIG --------
XML_PATH = "atlas.xml"
PNG_PATH = "atlas.png"
OUTPUT_DIR = "output"
# ------------------------

os.makedirs(OUTPUT_DIR, exist_ok=True)

tree = ET.parse(XML_PATH)
root = tree.getroot()

atlas_image = Image.open(PNG_PATH).convert("RGBA")

for sub in root.findall("SubTexture"):
    name = sub.attrib["name"]

    x = int(sub.attrib["x"])
    y = int(sub.attrib["y"])
    w = int(sub.attrib["width"])
    h = int(sub.attrib["height"])

    # Crop the sprite from atlas
    sprite = atlas_image.crop((x, y, x + w, y + h))

    # Handle trimmed sprites if data exists
    if all(k in sub.attrib for k in ("frameX", "frameY", "frameWidth", "frameHeight")):
        frame_w = int(sub.attrib["frameWidth"])
        frame_h = int(sub.attrib["frameHeight"])
        frame_x = int(sub.attrib["frameX"])
        frame_y = int(sub.attrib["frameY"])

        full_image = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
        full_image.paste(sprite, (-frame_x, -frame_y))
        sprite = full_image

    output_path = os.path.join(OUTPUT_DIR, name)
    if not output_path.lower().endswith(".png"):
        output_path += ".png"

    sprite.save(output_path)

print("Atlas split complete.")
