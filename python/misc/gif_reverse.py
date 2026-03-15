from PIL import Image, ImageSequence
import os

# =========================
# CONFIG
# =========================

OVERWRITE_INPUT = True  # True = overwrite input/, False = save to output/

INPUT_DIR = "input"
OUTPUT_DIR = "output"

GIF_NAMES = ["Idle.gif", "Left.gif", "Right.gif", "Down.gif", "Up.gif"]

# =========================

def reverse_gif(src_path: str, dst_path: str):
    with Image.open(src_path) as img:
        frames = []
        durations = []

        for frame in ImageSequence.Iterator(img):
            frames.append(frame.copy())
            durations.append(frame.info.get("duration", 100))

        frames.reverse()
        durations.reverse()

        frames[0].save(
            dst_path,
            save_all=True,
            append_images=frames[1:],
            duration=durations,
            loop=img.info.get("loop", 0),
            disposal=2,
        )

        print(f"Reversed: {dst_path}")

def main():
    if not OVERWRITE_INPUT:
        os.makedirs(OUTPUT_DIR, exist_ok=True)

    for name in GIF_NAMES:
        src = os.path.join(INPUT_DIR, name)

        if not os.path.exists(src):
            print(f"Missing file: {src}")
            continue

        dst = src if OVERWRITE_INPUT else os.path.join(OUTPUT_DIR, name)
        reverse_gif(src, dst)

if __name__ == "__main__":
    main()
