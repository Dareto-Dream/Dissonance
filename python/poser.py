#!/usr/bin/env python3
"""
pose_editor.py

Pygame-based pose editor for Dissonance characters.

- Parses Sparrow XML atlas
- Loads PNG atlas
- Lets you assemble poses from frames
- Saves poses into assets/data/characters/<char>/poses.json

Usage:
    python pose_editor.py <character_id> <pose_name>

Example:
    python pose_editor.py tiffany neutral
"""

import sys
import os
import json
import xml.etree.ElementTree as ET
from pathlib import Path

import pygame


# --------------------------------------------------------------------
# Path resolution
# --------------------------------------------------------------------

def find_project_root():
    """Try current dir first, then parent, to locate 'assets' folder."""
    here = Path(__file__).resolve().parent
    if (here / "assets").exists():
        return here
    if (here.parent / "assets").exists():
        return here.parent
    # Fallback: assume current working directory is project root
    cwd = Path(os.getcwd())
    if (cwd / "assets").exists():
        return cwd
    return here


PROJECT_ROOT = find_project_root()
ASSETS_DIR = PROJECT_ROOT / "assets"
IMAGES_DIR = ASSETS_DIR / "images" / "characters"
DATA_DIR = ASSETS_DIR / "data" / "characters"


# --------------------------------------------------------------------
# Atlas loading
# --------------------------------------------------------------------

class Atlas:
    def __init__(self, image_surface, frames):
        self.image = image_surface
        self.frames = frames  # name -> (x, y, w, h, rotated)

    @classmethod
    def from_xml(cls, character_id: str):
        char_dir = IMAGES_DIR / character_id
        xml_path = char_dir / f"{character_id}.xml"
        if not xml_path.exists():
            raise FileNotFoundError(f"XML not found: {xml_path}")

        tree = ET.parse(str(xml_path))
        root = tree.getroot()

        image_path = root.attrib.get("imagePath", f"{character_id}.png")
        png_path = char_dir / image_path
        if not png_path.exists():
            raise FileNotFoundError(f"PNG atlas not found: {png_path}")

        image_surface = pygame.image.load(str(png_path)).convert_alpha()

        frames = {}
        for sub in root.findall("SubTexture"):
            name = sub.attrib["name"]
            x = int(sub.attrib["x"])
            y = int(sub.attrib["y"])
            w = int(sub.attrib["width"])
            h = int(sub.attrib["height"])
            rotated = sub.attrib.get("rotated", "false").lower() == "true"
            frames[name] = (x, y, w, h, rotated)

        return cls(image_surface, frames)

    def list_frame_names(self):
        return sorted(self.frames.keys())

    def get_surface(self, name):
        x, y, w, h, rotated = self.frames[name]
        rect = pygame.Rect(x, y, w, h)
        sub = self.image.subsurface(rect).copy()
        if rotated:
            # Sparrow's rotated="true" usually means 90-degree rotation
            sub = pygame.transform.rotate(sub, -90)
        return sub


# --------------------------------------------------------------------
# Pose data handling
# --------------------------------------------------------------------

def load_poses(character_id: str):
    """Load poses.json for this character, or create a default structure."""
    char_data_dir = DATA_DIR / character_id
    char_data_dir.mkdir(parents=True, exist_ok=True)
    poses_path = char_data_dir / "poses.json"

    if not poses_path.exists():
        return {
            "character": character_id,
            "config": {
                "scale": 1.0,
                "base_offset": {"x": 0, "y": 0}
            },
            "poses": {}
        }

    with poses_path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_poses(character_id: str, data: dict):
    char_data_dir = DATA_DIR / character_id
    char_data_dir.mkdir(parents=True, exist_ok=True)
    poses_path = char_data_dir / "poses.json"
    with poses_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


# --------------------------------------------------------------------
# Pygame pose editor
# --------------------------------------------------------------------

class PoseEditor:
    def __init__(self, character_id: str, pose_name: str):
        self.character_id = character_id
        self.pose_name = pose_name

        pygame.init()
        pygame.display.set_caption(f"Pose Editor - {character_id} / {pose_name}")

        self.screen_width = 1600
        self.screen_height = 900
        self.screen = pygame.display.set_mode((self.screen_width, self.screen_height))

        self.font = pygame.font.SysFont("consolas", 16)
        self.small_font = pygame.font.SysFont("consolas", 14)

        self.atlas = Atlas.from_xml(character_id)
        self.frame_names = self.atlas.list_frame_names()

        self.frame_index = 0          # current selected frame in list
        self.frame_scroll = 0         # top of visible list

        self.layers = []              # list of dicts: {frame, x, y}
        self.layer_index = -1         # current selected layer

        self.poses_data = load_poses(character_id)
        self.load_existing_pose_if_any()

        # preview area center
        self.preview_cx = 1100
        self.preview_cy = 450

    # -----------------------------
    # Data loading / saving
    # -----------------------------

    def load_existing_pose_if_any(self):
        pose = self.poses_data.get("poses", {}).get(self.pose_name)
        if pose is None:
            self.layers = []
            self.layer_index = -1
        else:
            self.layers = []
            for layer in pose.get("layers", []):
                self.layers.append({
                    "frame": layer["frame"],
                    "x": int(layer["x"]),
                    "y": int(layer["y"])
                })
            self.layer_index = 0 if self.layers else -1

    def save_pose(self):
        pose_entry = {
            "layers": [
                {"frame": l["frame"], "x": int(l["x"]), "y": int(l["y"])}
                for l in self.layers
            ]
        }
        if "poses" not in self.poses_data:
            self.poses_data["poses"] = {}
        self.poses_data["poses"][self.pose_name] = pose_entry
        save_poses(self.character_id, self.poses_data)
        print(f"Saved pose '{self.pose_name}' for '{self.character_id}'")

    # -----------------------------
    # Event handling
    # -----------------------------

    def run(self):
        clock = pygame.time.Clock()
        running = True

        while running:
            dt = clock.tick(60)

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False
                elif event.type == pygame.KEYDOWN:
                    running = self.handle_keydown(event.key, pygame.key.get_mods())

            self.draw()
            pygame.display.flip()

        pygame.quit()

    def handle_keydown(self, key, mods):
        mod_shift = mods & pygame.KMOD_SHIFT

        if key == pygame.K_ESCAPE:
            return False

        # frame list navigation
        if key == pygame.K_UP:
            if self.frame_index > 0:
                self.frame_index -= 1
                self.ensure_frame_visible(-1)
        elif key == pygame.K_DOWN:
            if self.frame_index < len(self.frame_names) - 1:
                self.frame_index += 1
                self.ensure_frame_visible(1)
        elif key == pygame.K_PAGEUP:
            self.frame_index = max(0, self.frame_index - 10)
            self.ensure_frame_visible(-10)
        elif key == pygame.K_PAGEDOWN:
            self.frame_index = min(len(self.frame_names) - 1, self.frame_index + 10)
            self.ensure_frame_visible(10)

        # add layer from current frame
        elif key in (pygame.K_RETURN, pygame.K_SPACE):
            self.add_layer_from_current_frame()

        # layer selection
        elif key == pygame.K_TAB:
            self.cycle_layer()

        # movement of current layer
        elif key in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP, pygame.K_DOWN):
            self.move_current_layer(key, mod_shift)

        # delete current layer
        elif key in (pygame.K_DELETE, pygame.K_BACKSPACE):
            self.delete_current_layer()

        # save
        elif key == pygame.K_s:
            self.save_pose()

        # reload from poses.json
        elif key == pygame.K_l:
            self.load_existing_pose_if_any()

        # clear
        elif key == pygame.K_n:
            self.layers = []
            self.layer_index = -1

        return True

    def ensure_frame_visible(self, direction):
        visible_rows = self.screen_height // 20
        if self.frame_index < self.frame_scroll:
            self.frame_scroll = self.frame_index
        elif self.frame_index >= self.frame_scroll + visible_rows:
            self.frame_scroll = self.frame_index - visible_rows + 1

    def add_layer_from_current_frame(self):
        if not self.frame_names:
            return
        frame_name = self.frame_names[self.frame_index]
        new_layer = {"frame": frame_name, "x": 0, "y": 0}
        self.layers.append(new_layer)
        self.layer_index = len(self.layers) - 1

    def cycle_layer(self):
        if not self.layers:
            self.layer_index = -1
            return
        self.layer_index = (self.layer_index + 1) % len(self.layers)

    def move_current_layer(self, key, mod_shift):
        if self.layer_index < 0 or self.layer_index >= len(self.layers):
            return
        step = 10 if mod_shift else 1
        layer = self.layers[self.layer_index]
        if key == pygame.K_LEFT:
            layer["x"] -= step
        elif key == pygame.K_RIGHT:
            layer["x"] += step
        elif key == pygame.K_UP:
            layer["y"] -= step
        elif key == pygame.K_DOWN:
            layer["y"] += step

    def delete_current_layer(self):
        if self.layer_index < 0 or self.layer_index >= len(self.layers):
            return
        del self.layers[self.layer_index]
        if not self.layers:
            self.layer_index = -1
        else:
            self.layer_index = min(self.layer_index, len(self.layers) - 1)

    # -----------------------------
    # Rendering
    # -----------------------------

    def draw(self):
        self.screen.fill((15, 15, 20))

        # frame list panel
        self.draw_frame_list()

        # preview panel
        self.draw_preview()

        # footer help
        self.draw_footer()

    def draw_frame_list(self):
        panel_width = 350
        pygame.draw.rect(self.screen, (30, 30, 40), (0, 0, panel_width, self.screen_height))

        title = self.font.render(f"Frames ({self.character_id})", True, (200, 200, 220))
        self.screen.blit(title, (10, 10))

        row_height = 20
        visible_rows = (self.screen_height - 40) // row_height

        for i in range(visible_rows):
            idx = self.frame_scroll + i
            if idx >= len(self.frame_names):
                break
            name = self.frame_names[idx]
            y = 40 + i * row_height

            if idx == self.frame_index:
                pygame.draw.rect(self.screen, (60, 60, 90), (5, y - 2, panel_width - 10, row_height))

            text = self.small_font.render(name, True, (220, 220, 220))
            self.screen.blit(text, (10, y))

    def draw_preview(self):
        # background area
        panel_x = 360
        panel_y = 10
        panel_w = self.screen_width - panel_x - 10
        panel_h = self.screen_height - 60

        pygame.draw.rect(self.screen, (25, 25, 30), (panel_x, panel_y, panel_w, panel_h))

        # center crosshair
        cx, cy = self.preview_cx, self.preview_cy
        pygame.draw.line(self.screen, (80, 80, 90), (cx - 10, cy), (cx + 10, cy))
        pygame.draw.line(self.screen, (80, 80, 90), (cx, cy - 10), (cx, cy + 10))

        # draw each layer
        for idx, layer in enumerate(self.layers):
            try:
                surf = self.atlas.get_surface(layer["frame"])
            except KeyError:
                continue

            x = cx + layer["x"] - surf.get_width() // 2
            y = cy + layer["y"] - surf.get_height() // 2

            self.screen.blit(surf, (x, y))

            if idx == self.layer_index:
                # outline for selected layer
                rect = pygame.Rect(x, y, surf.get_width(), surf.get_height())
                pygame.draw.rect(self.screen, (255, 255, 0), rect, 2)

        # pose label
        label = self.font.render(f"Pose: {self.pose_name}", True, (200, 200, 220))
        self.screen.blit(label, (panel_x + 10, panel_y + 10))

    def draw_footer(self):
        lines = [
            "UP/DOWN: select frame   PgUp/PgDn: scroll   Enter/Space: add layer",
            "TAB: cycle layer   Arrows: move layer   Shift+Arrows: move x10",
            "S: save pose   L: reload pose   N: clear layers   ESC: quit"
        ]
        y = self.screen_height - 55
        for line in lines:
            surf = self.small_font.render(line, True, (200, 200, 210))
            self.screen.blit(surf, (10, y))
            y += 18


# --------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------

def main():
    if len(sys.argv) < 3:
        print("Usage: python pose_editor.py <character_id> <pose_name>")
        sys.exit(1)

    character_id = sys.argv[1]
    pose_name = sys.argv[2]

    editor = PoseEditor(character_id, pose_name)
    editor.run()


if __name__ == "__main__":
    main()
