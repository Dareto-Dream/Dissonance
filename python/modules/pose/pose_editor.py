"""Pose Editor Module - Interactive character pose composer."""
from __future__ import annotations

import json
from typing import Dict, List, Optional

import pygame
import pygame.freetype

from modules.utils.data_loader import ensure_export_dir, load_pose_catalog


class PoseEditorModule:
    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = project_root
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)

        self.catalog = load_pose_catalog(project_root)
        self.character_id = self.catalog.get("character", "unknown")
        self.poses: Dict[str, Dict] = self.catalog.get("poses", {})
        self.pose_names = sorted(self.poses.keys())
        self.selected_pose: Optional[str] = self.pose_names[0] if self.pose_names else None
        self.selected_layer_index: Optional[int] = 0 if self.selected_pose else None
        self.status_message = ""
        self.status_timer = 0.0
        self.layer_colors = {}

    def handle_event(self, event):
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self._handle_pose_click(event.pos):
                return
            self._handle_layer_click(event.pos)
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_s and pygame.key.get_mods() & pygame.KMOD_CTRL:
                self._save_catalog()
            elif event.key in (pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT):
                self._nudge_layer(event.key)

    def _handle_pose_click(self, pos) -> bool:
        sidebar_rect = pygame.Rect(20, 120, 220, self.rect.height - 160)
        if not sidebar_rect.collidepoint(pos):
            return False
        if not self.pose_names:
            return False

        item_height = 34
        relative_y = pos[1] - sidebar_rect.y
        index = relative_y // item_height
        if 0 <= index < len(self.pose_names):
            self.selected_pose = self.pose_names[index]
            self.selected_layer_index = 0
        return True

    def _handle_layer_click(self, pos):
        if not self.selected_pose:
            return
        layer_rect = self._layer_panel_rect()
        if not layer_rect.collidepoint(pos):
            return
        layers = self._current_layers()
        row_height = 32
        relative_y = pos[1] - (layer_rect.y + 40)
        index = relative_y // row_height
        if 0 <= index < len(layers):
            self.selected_layer_index = index

    def _nudge_layer(self, key):
        layers = self._current_layers()
        if not layers or self.selected_layer_index is None:
            return
        idx = self.selected_layer_index
        if idx >= len(layers):
            return
        layer = layers[idx]
        step = 5 if pygame.key.get_mods() & pygame.KMOD_SHIFT else 1
        if key == pygame.K_LEFT:
            layer["x"] = layer.get("x", 0) - step
        elif key == pygame.K_RIGHT:
            layer["x"] = layer.get("x", 0) + step
        elif key == pygame.K_UP:
            layer["y"] = layer.get("y", 0) - step
        elif key == pygame.K_DOWN:
            layer["y"] = layer.get("y", 0) + step

    def _save_catalog(self):
        export_dir = ensure_export_dir(self.project_root, "poses")
        filename = f"{self.character_id}_poses.json"
        path = export_dir / filename
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(
                {
                    "character": self.character_id,
                    "config": self.catalog.get("config", {}),
                    "poses": self.poses,
                },
                handle,
                indent=2,
            )
        self.status_message = f"Saved poses to {path.relative_to(self.project_root)}"
        self.status_timer = 3.0

    def update(self, dt):
        if self.status_timer > 0:
            self.status_timer -= dt
        else:
            self.status_message = ""

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        title_surf, _ = self.title_font.render("Pose Editor", self.theme.text_primary)
        surface.blit(title_surf, (20, 20))

        subtitle = f"Character: {self.character_id}" if self.character_id else "No pose data loaded"
        subtitle_surf, _ = self.font.render(subtitle, self.theme.text_secondary)
        surface.blit(subtitle_surf, (20, 60))

        self._draw_pose_list(surface)
        self._draw_preview(surface)
        self._draw_layers(surface)
        self._draw_status(surface)

    def _draw_pose_list(self, surface):
        sidebar_rect = pygame.Rect(20, 120, 220, self.rect.height - 160)
        pygame.draw.rect(surface, self.theme.bg_medium, sidebar_rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, sidebar_rect, 1, border_radius=6)

        title_surf, _ = self.font.render("Poses", self.theme.text_primary)
        surface.blit(title_surf, (sidebar_rect.x + 10, sidebar_rect.y + 10))

        y = sidebar_rect.y + 40
        for pose in self.pose_names:
            rect = pygame.Rect(sidebar_rect.x + 10, y, sidebar_rect.width - 20, 26)
            is_active = pose == self.selected_pose
            color = self.theme.accent_blue if is_active else self.theme.bg_light
            pygame.draw.rect(surface, color, rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)
            label_surf, _ = self.small_font.render(pose, self.theme.text_primary)
            surface.blit(label_surf, (rect.x + 8, rect.y + 5))
            y += 32

    def _draw_preview(self, surface):
        preview_rect = pygame.Rect(260, 120, self.rect.width - 300, 260)
        pygame.draw.rect(surface, self.theme.bg_medium, preview_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, preview_rect, 2, border_radius=8)

        if not self.selected_pose:
            empty_surf, _ = self.font.render("Select a pose to preview", self.theme.text_secondary)
            surface.blit(empty_surf, (preview_rect.x + 20, preview_rect.y + 20))
            return

        center = preview_rect.center
        pygame.draw.circle(surface, self.theme.grid_line, center, 4)
        pygame.draw.line(surface, self.theme.grid_line, (center[0] - 120, center[1]), (center[0] + 120, center[1]), 1)
        pygame.draw.line(surface, self.theme.grid_line, (center[0], center[1] - 120), (center[0], center[1] + 120), 1)

        layers = self._current_layers()
        scale = 2
        for idx, layer in enumerate(layers):
            color = self._layer_color(layer.get("frame", "layer"))
            width = 120
            height = 40
            offset_x = center[0] + layer.get("x", 0) * scale - width // 2
            offset_y = center[1] + layer.get("y", 0) * scale - height // 2
            rect = pygame.Rect(offset_x, offset_y, width, height)
            pygame.draw.rect(surface, color, rect, border_radius=6)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=6)
            label = f"{idx + 1}: {layer.get('frame', 'frame')}"
            label_surf, _ = self.small_font.render(label, self.theme.text_primary)
            surface.blit(label_surf, (rect.x + 6, rect.y + 10))

    def _draw_layers(self, surface):
        panel_rect = self._layer_panel_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, panel_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel_rect, 1, border_radius=8)

        header_surf, _ = self.font.render("Layers", self.theme.text_primary)
        surface.blit(header_surf, (panel_rect.x + 10, panel_rect.y + 10))

        instructions = "Arrow keys adjust offsets (Shift = x5). Ctrl+S to export."
        inst_surf, _ = self.small_font.render(instructions, self.theme.text_secondary)
        surface.blit(inst_surf, (panel_rect.x + 10, panel_rect.y + 30))

        if not self.selected_pose:
            return

        layers = self._current_layers()
        y = panel_rect.y + 60
        for idx, layer in enumerate(layers):
            row_rect = pygame.Rect(panel_rect.x + 10, y, panel_rect.width - 20, 26)
            is_active = idx == self.selected_layer_index
            bg = self.theme.accent_blue if is_active else self.theme.bg_light
            pygame.draw.rect(surface, bg, row_rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, row_rect, 1, border_radius=4)

            frame = layer.get("frame", "frame")
            coords = f"x={layer.get('x',0):+d} y={layer.get('y',0):+d}"
            frame_surf, _ = self.small_font.render(frame, self.theme.text_primary)
            coord_surf, _ = self.small_font.render(coords, self.theme.text_secondary)
            surface.blit(frame_surf, (row_rect.x + 8, row_rect.y + 4))
            surface.blit(coord_surf, (row_rect.right - coord_surf.get_width() - 8, row_rect.y + 4))
            y += 32

    def _draw_status(self, surface):
        if not self.status_message:
            return
        status_surf, _ = self.font.render(self.status_message, self.theme.accent_green)
        surface.blit(status_surf, (260, self.rect.height - 40))

    def _layer_panel_rect(self):
        return pygame.Rect(260, 400, self.rect.width - 300, 240)

    def _current_layers(self) -> List[Dict]:
        if not self.selected_pose:
            return []
        pose = self.poses.get(self.selected_pose, {})
        return pose.get("layers", [])

    def _layer_color(self, frame_name: str):
        if frame_name not in self.layer_colors:
            seed = abs(hash(frame_name)) % 255
            self.layer_colors[frame_name] = (120 + seed % 120, 80 + seed % 100, 140)
        return self.layer_colors[frame_name]

    def cleanup(self):
        pass
