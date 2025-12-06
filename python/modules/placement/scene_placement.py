"""Scene Placement Module - Position characters and backgrounds."""
from __future__ import annotations

import json
from typing import Dict, List, Optional

import pygame
import pygame.freetype

from modules.utils.data_loader import ensure_export_dir, load_scene_template


class ScenePlacement:
    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = project_root
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)

        self.scene = load_scene_template(project_root)
        self.scene_id = self.scene.get("scene_id", "template_scene")
        self.stage_rect = self._compute_stage_rect()

        self.background_path = self._find_first_background()
        self.characters = self._build_character_slots()
        self.selected_character: Optional[Dict] = None
        self.dragging = False
        self.drag_offset = (0, 0)
        self.status_message = ""
        self.status_timer = 0.0

    def _find_first_background(self) -> str:
        for node in self.scene.get("nodes", []):
            if node.get("type") == "action" and node.get("action") == "set_bg":
                return node.get("background", "")
        return "assets/images/bg/placeholder.png"

    def _build_character_slots(self) -> List[Dict]:
        placements: Dict[str, Dict] = {}
        for node in self.scene.get("nodes", []):
            if node.get("type") == "action" and node.get("action") == "show_character":
                char_id = node.get("character", "unknown")
                pose = node.get("pose", "default")
                slot = node.get("position", "center")
                x, y = self._slot_to_point(slot)
                placements[char_id] = {
                    "character": char_id,
                    "pose": pose,
                    "slot": slot,
                    "x": x,
                    "y": y,
                }
        return list(placements.values())

    def handle_event(self, event):
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            for char in reversed(self.characters):
                rect = self._character_rect(char)
                if rect.collidepoint(event.pos):
                    self.selected_character = char
                    self.dragging = True
                    self.drag_offset = (event.pos[0] - char["x"], event.pos[1] - char["y"])
                    break
        elif event.type == pygame.MOUSEBUTTONUP and event.button == 1:
            if self.dragging and self.selected_character:
                self.selected_character["slot"] = self._slot_from_position(self.selected_character["x"])
            self.dragging = False
        elif event.type == pygame.MOUSEMOTION and self.dragging and self.selected_character:
            self._drag_selected_character(event.pos)
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_s and pygame.key.get_mods() & pygame.KMOD_CTRL:
                self._save_layout()

    def _drag_selected_character(self, pos):
        if not self.selected_character:
            return
        new_x = pos[0] - self.drag_offset[0]
        new_y = pos[1] - self.drag_offset[1]
        padding = 80
        new_x = max(self.stage_rect.x + padding, min(self.stage_rect.right - padding, new_x))
        new_y = max(self.stage_rect.y + padding, min(self.stage_rect.bottom - padding, new_y))
        self.selected_character["x"] = new_x
        self.selected_character["y"] = new_y

    def _slot_to_point(self, slot: str):
        if slot == "left":
            x = self.stage_rect.x + self.stage_rect.width * 0.25
        elif slot == "right":
            x = self.stage_rect.x + self.stage_rect.width * 0.75
        else:
            x = self.stage_rect.centerx
        y = self.stage_rect.bottom - 120
        return x, y

    def _slot_from_position(self, x: float) -> str:
        left_boundary = self.stage_rect.x + self.stage_rect.width * (1 / 3)
        right_boundary = self.stage_rect.x + self.stage_rect.width * (2 / 3)
        if x < left_boundary:
            return "left"
        if x > right_boundary:
            return "right"
        return "center"

    def _character_rect(self, character: Dict) -> pygame.Rect:
        width = 160
        height = 260
        x = character["x"] - width // 2
        y = character["y"] - height
        return pygame.Rect(x, y, width, height)

    def _save_layout(self):
        export_dir = ensure_export_dir(self.project_root, "placements")
        path = export_dir / f"{self.scene_id}_placement.json"
        payload = {
            "scene_id": self.scene_id,
            "background": self.background_path,
            "characters": self.characters,
        }
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
        self.status_message = f"Saved placement to {path.relative_to(self.project_root)}"
        self.status_timer = 3.0

    def update(self, dt):
        if self.status_timer > 0:
            self.status_timer -= dt
        else:
            self.status_message = ""

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        self.stage_rect = self._compute_stage_rect()

        self._draw_header(surface)
        self._draw_stage(surface)
        self._draw_sidebar(surface)
        self._draw_status(surface)

    def _draw_header(self, surface):
        title_surf, _ = self.title_font.render("Scene Placement", self.theme.text_primary)
        surface.blit(title_surf, (20, 20))
        info = f"Scene: {self.scene_id}  |  Ctrl+S to export JSON"
        info_surf, _ = self.font.render(info, self.theme.text_secondary)
        surface.blit(info_surf, (20, 60))

    def _draw_stage(self, surface):
        pygame.draw.rect(surface, self.theme.bg_medium, self.stage_rect, border_radius=12)
        pygame.draw.rect(surface, self.theme.border, self.stage_rect, 2, border_radius=12)

        bg_label = f"Background: {self.background_path}" if self.background_path else "Background not set"
        bg_surf, _ = self.small_font.render(bg_label, self.theme.text_secondary)
        surface.blit(bg_surf, (self.stage_rect.x + 10, self.stage_rect.y + 10))

        # Stage floor
        floor_rect = pygame.Rect(self.stage_rect.x, self.stage_rect.bottom - 60, self.stage_rect.width, 60)
        pygame.draw.rect(surface, (50, 50, 50), floor_rect, border_radius=0)

        for char in self.characters:
            rect = self._character_rect(char)
            color = self._character_color(char["character"])
            pygame.draw.rect(surface, color, rect, border_radius=8)
            pygame.draw.rect(surface, self.theme.border, rect, 2, border_radius=8)

            name = char["character"].title()
            pose = char.get("pose", "pose")
            label = f"{name}\n{pose}"
            y = rect.y + 8
            for line in label.split("\n"):
                surf, _ = self.small_font.render(line, self.theme.text_primary)
                surface.blit(surf, (rect.x + 8, y))
                y += 18

            slot_text = f"Slot: {char.get('slot', 'center')}"
            slot_surf, _ = self.small_font.render(slot_text, self.theme.text_disabled)
            surface.blit(slot_surf, (rect.x + 8, rect.bottom - 24))

        instruction = "Drag characters to reposition. Slots update automatically."
        inst_surf, _ = self.small_font.render(instruction, self.theme.text_secondary)
        surface.blit(inst_surf, (self.stage_rect.x + 10, self.stage_rect.bottom - 80))

    def _draw_sidebar(self, surface):
        panel_rect = pygame.Rect(20, 120, 280, self.rect.height - 160)
        pygame.draw.rect(surface, self.theme.bg_medium, panel_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel_rect, 1, border_radius=8)

        header_surf, _ = self.font.render("Characters", self.theme.text_primary)
        surface.blit(header_surf, (panel_rect.x + 10, panel_rect.y + 10))

        y = panel_rect.y + 40
        for char in self.characters:
            row = pygame.Rect(panel_rect.x + 10, y, panel_rect.width - 20, 60)
            is_active = char is self.selected_character
            color = self.theme.accent_blue if is_active else self.theme.bg_light
            pygame.draw.rect(surface, color, row, border_radius=6)
            pygame.draw.rect(surface, self.theme.border, row, 1, border_radius=6)

            name_surf, _ = self.small_font.render(char["character"].title(), self.theme.text_primary)
            pose_surf, _ = self.small_font.render(f"Pose: {char.get('pose', 'pose')}", self.theme.text_secondary)
            slot_surf, _ = self.small_font.render(f"Slot: {char.get('slot', 'center')}", self.theme.text_secondary)
            surface.blit(name_surf, (row.x + 10, row.y + 8))
            surface.blit(pose_surf, (row.x + 10, row.y + 26))
            surface.blit(slot_surf, (row.x + 10, row.y + 44))
            y += 70

    def _draw_status(self, surface):
        if not self.status_message:
            return
        status_surf, _ = self.font.render(self.status_message, self.theme.accent_green)
        surface.blit(status_surf, (320, self.rect.height - 40))

    def _character_color(self, name: str):
        base = abs(hash(name)) % 200
        return (80 + base % 100, 60 + (base // 2) % 120, 120)

    def _compute_stage_rect(self):
        width = max(400, self.rect.width - 360)
        height = max(260, self.rect.height - 220)
        return pygame.Rect(320, 120, width, height)

    def cleanup(self):
        pass
