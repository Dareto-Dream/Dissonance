"""XML Viewer Module - Browse and preview atlas textures."""
from __future__ import annotations

import json
from pathlib import Path
from typing import List
import xml.etree.ElementTree as ET

import pygame
import pygame.freetype

from modules.utils.data_loader import load_pose_catalog


class XMLViewer:
    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = Path(project_root)
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)

        self.files = self._scan_files()
        self.selected_index = 0 if self.files else None
        self.preview_frames: List[dict] = []
        self.status_message = ""

        if self.selected_index is not None:
            self._load_preview(self.files[self.selected_index]["path"])

    def _scan_files(self):
        assets_root = self.project_root / "assets"
        files = []
        if assets_root.exists():
            for path in assets_root.rglob("*.xml"):
                files.append({"label": str(path.relative_to(self.project_root)), "path": path})
        # Fallback to bot_context data
        catalog = load_pose_catalog(self.project_root)
        if catalog.get("poses"):
            files.append({"label": "bot_context/poses.json (generated)", "path": Path("bot_context/poses.json")})
        return files

    def handle_event(self, event):
        if event.type == pygame.KEYDOWN and event.key == pygame.K_r:
            self.files = self._scan_files()
            if self.files:
                self.selected_index = 0
                self._load_preview(self.files[0]["path"])
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            self._handle_click(event.pos)

    def _handle_click(self, pos):
        sidebar = pygame.Rect(20, 120, 300, self.rect.height - 160)
        if not sidebar.collidepoint(pos):
            return
        if not self.files:
            return
        item_height = 36
        index = (pos[1] - sidebar.y) // item_height
        if 0 <= index < len(self.files):
            self.selected_index = index
            self._load_preview(self.files[index]["path"])

    def _load_preview(self, path: Path):
        full_path = path if path.is_absolute() else self.project_root / path
        frames = []
        try:
            if full_path.suffix.lower() == ".xml" and full_path.exists():
                tree = ET.parse(full_path)
                root = tree.getroot()
                for node in root.findall(".//SubTexture"):
                    frames.append(
                        {
                            "name": node.get("name", "frame"),
                            "x": int(node.get("x", 0)),
                            "y": int(node.get("y", 0)),
                            "width": int(node.get("width", 0)),
                            "height": int(node.get("height", 0)),
                        }
                    )
            elif full_path.suffix.lower() == ".json" and full_path.exists():
                with open(full_path, "r", encoding="utf-8") as handle:
                    data = json.load(handle)
                frames = []
                for pose_name, pose in data.get("poses", {}).items():
                    for layer in pose.get("layers", []):
                        frames.append(
                            {
                                "name": f"{pose_name}:{layer.get('frame')}",
                                "x": layer.get("x", 0),
                                "y": layer.get("y", 0),
                                "width": 0,
                                "height": 0,
                            }
                        )
            else:
                self.status_message = f"File not found: {full_path}"
        except Exception as exc:  # noqa: BLE001
            self.status_message = f"Failed to parse {full_path.name}: {exc}"
            frames = []
        else:
            self.status_message = f"Loaded {len(frames)} entries from {full_path.name}"
        self.preview_frames = frames

    def update(self, dt):  # pylint: disable=unused-argument
        pass

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        title_surf, _ = self.title_font.render("XML Atlas Viewer", self.theme.text_primary)
        surface.blit(title_surf, (20, 20))

        subtitle = "Click a file to preview frames. Press R to rescan."
        subtitle_surf, _ = self.font.render(subtitle, self.theme.text_secondary)
        surface.blit(subtitle_surf, (20, 60))

        self._draw_sidebar(surface)
        self._draw_preview(surface)

        if self.status_message:
            status_surf, _ = self.small_font.render(self.status_message, self.theme.accent_green)
            surface.blit(status_surf, (20, self.rect.height - 40))

    def _draw_sidebar(self, surface):
        sidebar = pygame.Rect(20, 120, 300, self.rect.height - 160)
        pygame.draw.rect(surface, self.theme.bg_medium, sidebar, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, sidebar, 1, border_radius=8)

        y = sidebar.y + 10
        for idx, entry in enumerate(self.files):
            rect = pygame.Rect(sidebar.x + 10, y, sidebar.width - 20, 30)
            color = self.theme.accent_blue if idx == self.selected_index else self.theme.bg_light
            pygame.draw.rect(surface, color, rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)

            label = entry["label"]
            label_surf, _ = self.small_font.render(label, self.theme.text_primary)
            surface.blit(label_surf, (rect.x + 8, rect.y + 6))
            y += 34

    def _draw_preview(self, surface):
        panel = pygame.Rect(340, 120, self.rect.width - 360, self.rect.height - 160)
        pygame.draw.rect(surface, self.theme.bg_medium, panel, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel, 1, border_radius=8)

        if not self.preview_frames:
            empty_surf, _ = self.font.render("No frames loaded", self.theme.text_secondary)
            surface.blit(empty_surf, (panel.x + 20, panel.y + 20))
            return

        header = f"Frames: {len(self.preview_frames)}"
        header_surf, _ = self.font.render(header, self.theme.text_primary)
        surface.blit(header_surf, (panel.x + 20, panel.y + 20))

        cols = 3
        cell_width = (panel.width - 60) // cols
        cell_height = 90
        x = panel.x + 20
        y = panel.y + 60
        for idx, frame in enumerate(self.preview_frames[:90]):
            rect = pygame.Rect(x, y, cell_width - 10, cell_height - 10)
            pygame.draw.rect(surface, self.theme.bg_light, rect, border_radius=6)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=6)

            name = frame.get("name", "frame")
            meta = f"{frame.get('width', 0)}x{frame.get('height', 0)} @ ({frame.get('x', 0)}, {frame.get('y', 0)})"
            name_surf, _ = self.small_font.render(name, self.theme.text_primary)
            meta_surf, _ = self.small_font.render(meta, self.theme.text_secondary)
            surface.blit(name_surf, (rect.x + 8, rect.y + 6))
            surface.blit(meta_surf, (rect.x + 8, rect.y + 28))

            x += cell_width
            if (idx + 1) % cols == 0:
                x = panel.x + 20
                y += cell_height
