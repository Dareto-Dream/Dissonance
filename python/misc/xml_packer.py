import os
from PIL import Image, ImageSequence
from rectpack import newPacker

# =========================
# CONFIG
# =========================
INPUT_DIR = "input"
OUTPUT_DIR = "output"
ATLAS_NAME = "hanami"

SCALE = 1.0  # 1.0 = no scaling

ANIM_MAP = {
    "idle": "idle",
    "left": "singLEFT",
    "down": "singDOWN",
    "up": "singUP",
    "right": "singRIGHT",
}

# =========================
# SETUP
# =========================
os.makedirs(OUTPUT_DIR, exist_ok=True)

frames = []  # (name, image)

# =========================
# EXTRACT GIF FRAMES
# =========================
for gif_name, prefix in ANIM_MAP.items():
    gif_path = os.path.join(INPUT_DIR, f"{gif_name}.gif")

    if not os.path.exists(gif_path):
        raise FileNotFoundError(f"Missing GIF: {gif_path}")

    gif = Image.open(gif_path)

    for i, frame in enumerate(ImageSequence.Iterator(gif)):
        frame = frame.convert("RGBA")

        if SCALE != 1.0:
            w, h = frame.size
            frame = frame.resize(
                (int(w * SCALE), int(h * SCALE)),
                Image.NEAREST
            )

        name = f"{prefix}{i:04d}"
        frames.append((name, frame))

print(f"Extracted {len(frames)} frames")

# =========================
# PACK ATLAS (ROBUST)
# =========================
packer = newPacker(rotation=False)

for name, img in frames:
    packer.add_rect(img.width, img.height, rid=name)

# Large bin, allows everything to fit
packer.add_bin(8192, 8192)
packer.pack()

# Collect ALL packed rects
rect_lookup = {}
for abin in packer:
    for rect in abin:
        rect_lookup[rect.rid] = rect

# Validate packing
missing = [name for name, _ in frames if name not in rect_lookup]
if missing:
    raise RuntimeError(f"Unpacked frames detected: {missing}")

# =========================
# BUILD ATLAS IMAGE
# =========================
max_w = max(r.x + r.width for r in rect_lookup.values())
max_h = max(r.y + r.height for r in rect_lookup.values())

atlas = Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))

frame_dict = dict(frames)

for name, rect in rect_lookup.items():
    atlas.paste(frame_dict[name], (rect.x, rect.y))

png_path = os.path.join(OUTPUT_DIR, f"{ATLAS_NAME}.png")
atlas.save(png_path)

# =========================
# WRITE SPARROW XML
# =========================
xml_path = os.path.join(OUTPUT_DIR, f"{ATLAS_NAME}.xml")

with open(xml_path, "w", encoding="utf-8") as f:
    f.write(f'<TextureAtlas imagePath="{ATLAS_NAME}.png">\n')

    # Preserve animation order
    for name, _ in frames:
        r = rect_lookup[name]
        f.write(
            f'    <SubTexture name="{name}" '
            f'x="{r.x}" y="{r.y}" '
            f'width="{r.width}" height="{r.height}"/>\n'
        )

    f.write('</TextureAtlas>\n')

print("Done.")
print(f"Atlas: {png_path}")
print(f"XML:   {xml_path}")
