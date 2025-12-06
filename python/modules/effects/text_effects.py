"""Text Effects Module - Preview text animations."""
from __future__ import annotations

import math
import random
from typing import Dict, List, Optional

import pygame
import pygame.freetype

from modules.utils.data_loader import list_text_effects, load_scene_demo


class TextEffectPreview:
    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = project_root
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.preview_font = pygame.freetype.SysFont("Arial", 32)

        self.demo_scene = load_scene_demo(project_root)
        self.timeline = self._build_timeline(self.demo_scene)
        self.timeline_hitboxes: List[pygame.Rect] = []

        self.current_index = 0
        self.current_node: Optional[Dict] = None
        self.current_text = ""
        self.active_effect: Optional[Dict[str, Dict]] = None
        self.persistent_effect: Optional[Dict[str, Dict]] = None
        self.effect_elapsed = 0.0
        self.random = random.Random()
        self.available_effects = list_text_effects()

        self._apply_current_node()

    def _build_timeline(self, scene_data: Dict) -> List[Dict]:
        nodes = scene_data.get("nodes", [])
        node_map = {node["id"]: node for node in nodes if "id" in node}
        order: List[Dict] = []
        cursor = scene_data.get("start")
        visited = set()
        while cursor and cursor in node_map and cursor not in visited:
            node = node_map[cursor]
            order.append(node)
            visited.add(cursor)
            cursor = self._resolve_next(node)
        if not order:
            order = nodes
        return order

    def _resolve_next(self, node: Dict) -> Optional[str]:
        node_type = node.get("type")
        if node_type in {"dialogue", "narration", "action", "game", "end"}:
            return node.get("next") or node.get("next_scene")
        if node_type == "choice":
            choices = node.get("choices", [])
            return choices[0].get("target") if choices else None
        if node_type == "if":
            return node.get("trueNode") or node.get("falseNode")
        return None

    def handle_event(self, event):
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_RIGHT, pygame.K_SPACE):
                self._advance(1)
            elif event.key == pygame.K_LEFT:
                self._advance(-1)
            elif event.key == pygame.K_r:
                self.persistent_effect = None
                self._apply_current_node()
            elif event.key == pygame.K_HOME:
                self.current_index = 0
                self._apply_current_node()
            elif event.key == pygame.K_END:
                self.current_index = max(0, len(self.timeline) - 1)
                self._apply_current_node()
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            for rect, idx in self.timeline_hitboxes:
                if rect.collidepoint(event.pos):
                    self.current_index = idx
                    self._apply_current_node()
                    break

    def _advance(self, direction: int):
        if not self.timeline:
            return
        self.current_index = (self.current_index + direction) % len(self.timeline)
        self._apply_current_node()

    def _apply_current_node(self):
        if not self.timeline:
            self.current_node = None
            self.current_text = "No nodes found in demo scene."
            self.active_effect = None
            return

        self.current_node = self.timeline[self.current_index]
        node_type = self.current_node.get("type", "unknown")
        self.effect_elapsed = 0.0

        if node_type in {"dialogue", "narration"}:
            self.current_text = self.current_node.get("text", "")
            inline_effect = self.current_node.get("text_effect")
            params = self._extract_effect_params(self.current_node)
            if inline_effect:
                self.active_effect = {"type": inline_effect, "params": params}
            else:
                self.active_effect = self.persistent_effect
        elif node_type == "action":
            action = self.current_node.get("action", "action")
            if action == "set_text_effect":
                params = self._extract_effect_params(self.current_node)
                effect_name = self.current_node.get("text_effect", "shake")
                self.persistent_effect = {"type": effect_name, "params": params}
                self.active_effect = None
                self.current_text = f"Persistent text effect set to '{effect_name}'."
            elif action == "clear_text_effect":
                self.persistent_effect = None
                self.active_effect = None
                self.current_text = "Persistent text effect cleared."
            else:
                details = action.replace("_", " ")
                self.current_text = f"Action Node: {details.title()}"
                self.active_effect = None
        elif node_type == "choice":
            self.current_text = "Choice node – select a branch in a real scene."
            self.active_effect = None
        elif node_type == "if":
            condition = self.current_node.get("condition", "(condition)")
            self.current_text = f"Condition: {condition}"
            self.active_effect = None
        elif node_type == "end":
            self.current_text = "End node – scene transitions."
            self.active_effect = None
        else:
            self.current_text = f"Unsupported node type '{node_type}'."
            self.active_effect = None

    def _extract_effect_params(self, node: Dict) -> Dict[str, float]:
        params = {}
        for key in ("effect_intensity", "effect_speed", "effect_amplitude"):
            if key in node:
                params[key] = node[key]
        return params

    def update(self, dt):
        if self.current_node is None:
            return
        self.effect_elapsed += dt

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        self.timeline_hitboxes = []

        self._draw_header(surface)
        self._draw_preview(surface)
        self._draw_timeline(surface)
        self._draw_reference(surface)

    def _draw_header(self, surface):
        title_surf, title_rect = self.title_font.render("Text Effects Preview", self.theme.text_primary)
        title_rect.topleft = (30, 20)
        surface.blit(title_surf, title_rect)

        info = "Space/Right: Next  |  Left: Previous  |  R: Clear persistent  |  Home/End: Jump"
        info_surf, _ = self.font.render(info, self.theme.text_secondary)
        surface.blit(info_surf, (30, 60))

        if self.current_node:
            node_info = f"Node {self.current_node.get('id')}  •  {self.current_node.get('type').title()}"
            node_surf, _ = self.font.render(node_info, self.theme.text_primary)
            surface.blit(node_surf, (30, 90))

            if self.current_node.get("type") in {"dialogue", "narration"}:
                speaker = self.current_node.get("speaker") or "Narration"
                speaker_surf, _ = self.font.render(f"Speaker: {speaker}", self.theme.text_secondary)
                surface.blit(speaker_surf, (30, 110))

    def _draw_preview(self, surface):
        preview_rect = pygame.Rect(40, 140, self.rect.width - 80, 280)
        pygame.draw.rect(surface, self.theme.bg_medium, preview_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, preview_rect, 2, border_radius=8)

        effect = self.active_effect
        text = self.current_text
        display_text = text
        effect_label = effect.get("type") if effect else "None"

        if effect and effect.get("type") == "typewriter":
            speed = effect.get("params", {}).get("effect_speed", 30.0)
            visible = max(0, min(len(text), int(self.effect_elapsed * max(speed, 1.0) * 0.05)))
            display_text = text[:visible]

        if not display_text:
            self._draw_effect_label(surface, effect_label)
            return

        bounds = self.preview_font.get_rect(display_text)
        base_x = preview_rect.centerx - bounds.width // 2
        base_y = preview_rect.centery - bounds.height // 2

        if not effect:
            text_surf, text_rect = self.preview_font.render(display_text, self.theme.text_primary)
            text_rect.topleft = (base_x, base_y)
            surface.blit(text_surf, text_rect)
            self._draw_effect_label(surface, "None")
            return

        effect_type = effect.get("type")
        params = effect.get("params", {})
        self._draw_effect_label(surface, effect_type)

        if effect_type == "shake":
            offset_x = self.random.uniform(-1, 1) * params.get("effect_intensity", 2.0) * 3
            offset_y = self.random.uniform(-1, 1) * params.get("effect_intensity", 2.0) * 3
            text_surf, text_rect = self.preview_font.render(display_text, self.theme.text_primary)
            text_rect.topleft = (base_x + offset_x, base_y + offset_y)
            surface.blit(text_surf, text_rect)
        elif effect_type == "glitch":
            for pass_idx in range(3):
                color_shift = (
                    min(255, 200 + pass_idx * 20),
                    min(255, 120 + pass_idx * 40),
                    min(255, 120 + pass_idx * 50),
                )
                offset_x = self.random.uniform(-5, 5) * params.get("effect_intensity", 4.0) * 0.2
                offset_y = self.random.uniform(-4, 4) * 0.5
                surf, rect = self.preview_font.render(display_text, color_shift)
                rect.topleft = (base_x + offset_x, base_y + offset_y)
                surface.blit(surf, rect, special_flags=pygame.BLEND_RGB_ADD)
        elif effect_type == "wave":
            speed = params.get("effect_speed", 3.0)
            amp = params.get("effect_amplitude", 5.0)
            self._draw_per_character(surface, display_text, base_x, base_y, wave=True, wave_speed=speed, wave_amp=amp)
        elif effect_type == "rainbow":
            speed = params.get("effect_speed", 2.0)
            self._draw_per_character(surface, display_text, base_x, base_y, rainbow=True, rainbow_speed=speed)
        elif effect_type == "fade":
            speed = params.get("effect_speed", 2.0)
            alpha = (math.sin(self.effect_elapsed * speed * 2 * math.pi) + 1) / 2
            color = tuple(int(c * alpha + 20) for c in self.theme.text_primary)
            surf, rect = self.preview_font.render(display_text, color)
            rect.topleft = (base_x, base_y)
            surface.blit(surf, rect)
        elif effect_type == "typewriter":
            surf, rect = self.preview_font.render(display_text, self.theme.text_primary)
            rect.topleft = (base_x, base_y)
            surface.blit(surf, rect)
        else:
            surf, rect = self.preview_font.render(display_text, self.theme.text_primary)
            rect.topleft = (base_x, base_y)
            surface.blit(surf, rect)

    def _draw_per_character(self, surface, text, base_x, base_y, wave=False, wave_speed=0.0, wave_amp=0.0, rainbow=False, rainbow_speed=0.0):
        cursor_x = base_x
        for idx, char in enumerate(text):
            if char == " ":
                glyph, rect = self.preview_font.render(char, self.theme.text_primary)
                cursor_x += rect.width
                continue
            offset_y = 0
            color = self.theme.text_primary
            if wave:
                offset_y = math.sin(self.effect_elapsed * wave_speed + idx * 0.3) * wave_amp * 3
            if rainbow:
                hue = (self.effect_elapsed * rainbow_speed + idx * 0.1) % 1.0
                color = self._hsl_to_rgb(hue)
            glyph, rect = self.preview_font.render(char, color)
            target_pos = (cursor_x, base_y + offset_y)
            surface.blit(glyph, target_pos)
            cursor_x += rect.width

    def _hsl_to_rgb(self, h):
        r = int((math.sin(2 * math.pi * h) * 0.5 + 0.5) * 255)
        g = int((math.sin(2 * math.pi * (h + 1 / 3)) * 0.5 + 0.5) * 255)
        b = int((math.sin(2 * math.pi * (h + 2 / 3)) * 0.5 + 0.5) * 255)
        return (r, g, b)

    def _draw_effect_label(self, surface, label: str):
        text = f"Active Effect: {label}"
        surf, _ = self.font.render(text, self.theme.text_primary)
        surface.blit(surf, (50, 430))

        if self.persistent_effect:
            persistent_text = f"Persistent: {self.persistent_effect['type']}"
            psurf, _ = self.font.render(persistent_text, self.theme.text_secondary)
            surface.blit(psurf, (50, 450))

    def _draw_timeline(self, surface):
        if not self.timeline:
            return

        timeline_rect = pygame.Rect(40, self.rect.height - 200, self.rect.width - 80, 140)
        pygame.draw.rect(surface, self.theme.bg_medium, timeline_rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, timeline_rect, 2, border_radius=6)

        padding = 10
        available_width = timeline_rect.width - padding * 2
        node_count = len(self.timeline)
        button_width = max(70, available_width // max(1, node_count))
        button_width = min(button_width, 160)
        x = timeline_rect.x + padding
        y = timeline_rect.y + 20

        self.timeline_hitboxes = []
        for idx, node in enumerate(self.timeline):
            rect = pygame.Rect(x, y, button_width - 6, 80)
            is_active = idx == self.current_index
            color = self.theme.accent_blue if is_active else self.theme.bg_light
            pygame.draw.rect(surface, color, rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)

            label = f"{node.get('id', '?')}\n{node.get('type', '').title()}"
            lines = label.split("\n")
            line_y = rect.y + 8
            for line in lines:
                ls, _ = self.font.render(line, self.theme.text_primary if is_active else self.theme.text_secondary)
                surface.blit(ls, (rect.x + 8, line_y))
                line_y += 18

            self.timeline_hitboxes.append((rect, idx))
            x += button_width
            if x + button_width > timeline_rect.right:
                break

    def _draw_reference(self, surface):
        panel_rect = pygame.Rect(self.rect.width - 360, 140, 320, self.rect.height - 360)
        pygame.draw.rect(surface, self.theme.bg_medium, panel_rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, panel_rect, 1, border_radius=6)

        title_surf, _ = self.font.render("Effect Reference", self.theme.text_primary)
        surface.blit(title_surf, (panel_rect.x + 10, panel_rect.y + 10))

        y = panel_rect.y + 35
        for effect in self.available_effects:
            name_surf, _ = self.font.render(effect["name"].title(), self.theme.text_secondary)
            surface.blit(name_surf, (panel_rect.x + 10, y))
            y += 18
            desc_surf, _ = self.font.render(effect["description"], self.theme.text_disabled)
            surface.blit(desc_surf, (panel_rect.x + 10, y))
            y += 30

    def cleanup(self):
        pass
