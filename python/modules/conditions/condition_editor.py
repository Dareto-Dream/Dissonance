"""Condition Editor Module - Build conditional logic expressions."""
from __future__ import annotations

from typing import List

import pygame
import pygame.freetype

from modules.ui.widgets import TextInput

AVAILABLE_STATS = [
    # Character influence stats (numeric, 0-10 range)
    "tiffany_rot",
    "cassian_rot",
    "hanami_rot",
    "harumi_rot",
    "tiffany_trust",
    "cassian_trust",
    "hanami_trust",
    "harumi_trust",
    # Story flags (boolean)
    "flags.asked_tiffany",
    "flags.asked_cassian",
    "flags.met_hanami",
    "flags.met_harumi",
    "flags.first_rhythm_complete",
    "flags.act1_complete",
    "flags.act2_complete",
    "flags.act3_complete",
    # Player state flags
    "player.flags.puppet_mode",
    "player.flags.aware",
]

OPERATORS = ["==", "!=", "<", "<=", ">", ">="]
CONNECTORS = ["and", "or"]


class ConditionEditor:
    def __init__(self, workspace_rect, theme, project_root):
        del project_root  # Unused for now, kept for API symmetry
        self.rect = workspace_rect
        self.theme = theme
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)

        self.builder_rect = pygame.Rect(20, 120, self.rect.width - 40, 280)
        self.rows: List[dict] = []
        self._add_condition()

        self.sample_state = {
            "tiffany_rot": 1,
            "cassian_rot": 4,
            "hanami_rot": 3,
            "harumi_rot": 2,
            "tiffany_trust": 5,
            "cassian_trust": 3,
            "hanami_trust": 7,
            "harumi_trust": 4,
            "flags": {
                "asked_tiffany": True,
                "asked_cassian": False,
                "met_hanami": True,
                "met_harumi": False,
                "first_rhythm_complete": False,
                "act1_complete": False,
                "act2_complete": False,
                "act3_complete": False,
            },
            "player": {
                "flags": {
                    "puppet_mode": False,
                    "aware": False,
                }
            }
        }

    def _add_condition(self):
        input_field = TextInput(pygame.Rect(0, 0, 140, 28), self.font, placeholder="value", text="0")
        self.rows.append(
            {
                "stat_index": 0,
                "operator_index": 3,  # <=
                "connector_index": 0,
                "input": input_field,
            }
        )

    def handle_event(self, event):
        for row in self.rows:
            row["input"].handle_event(event)

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            pos = event.pos
            for idx, row in enumerate(self.rows):
                if self._stat_rect(idx).collidepoint(pos):
                    row["stat_index"] = (row["stat_index"] + 1) % len(AVAILABLE_STATS)
                elif self._operator_rect(idx).collidepoint(pos):
                    row["operator_index"] = (row["operator_index"] + 1) % len(OPERATORS)
                elif idx < len(self.rows) - 1 and self._connector_rect(idx).collidepoint(pos):
                    row["connector_index"] = (row["connector_index"] + 1) % len(CONNECTORS)
                elif len(self.rows) > 1 and self._delete_rect(idx).collidepoint(pos):
                    self.rows.pop(idx)
                    break

            if self._add_button_rect().collidepoint(pos):
                self._add_condition()

    def update(self, dt):
        for row in self.rows:
            row["input"].update(dt)

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        title_surf, _ = self.title_font.render("Condition Editor", self.theme.text_primary)
        surface.blit(title_surf, (20, 20))

        subtitle = "Click stats/operators to cycle options."
        subtitle_surf, _ = self.font.render(subtitle, self.theme.text_secondary)
        surface.blit(subtitle_surf, (20, 60))

        self._draw_builder(surface)
        self._draw_preview(surface)

    def _draw_builder(self, surface):
        pygame.draw.rect(surface, self.theme.bg_medium, self.builder_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, self.builder_rect, 1, border_radius=8)

        headers = ["Stat", "Operator", "Value", "Connector"]
        column_positions = [self._stat_rect(0).x, self._operator_rect(0).x, self._value_rect(0).x, self._connector_rect(0).x]
        for header, x in zip(headers, column_positions):
            surf, _ = self.small_font.render(header, self.theme.text_disabled)
            surface.blit(surf, (x, self.builder_rect.y + 10))

        for idx, row in enumerate(self.rows):
            stat_rect = self._stat_rect(idx)
            op_rect = self._operator_rect(idx)
            val_rect = self._value_rect(idx)
            conn_rect = self._connector_rect(idx)
            del_rect = self._delete_rect(idx)

            self._draw_toggle_cell(surface, stat_rect, AVAILABLE_STATS[row["stat_index"]])
            self._draw_toggle_cell(surface, op_rect, OPERATORS[row["operator_index"]])

            row["input"].rect = val_rect
            row["input"].draw(surface, self.theme)

            if idx < len(self.rows) - 1:
                connector = CONNECTORS[row["connector_index"]]
                self._draw_toggle_cell(surface, conn_rect, connector.upper())
            else:
                self._draw_toggle_cell(surface, conn_rect, "--", disabled=True)

            if len(self.rows) > 1:
                self._draw_delete(surface, del_rect)

        add_button = self._add_button_rect()
        pygame.draw.rect(surface, self.theme.accent_green, add_button, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, add_button, 1, border_radius=6)
        add_surf, _ = self.font.render("Add condition", self.theme.text_primary)
        surface.blit(add_surf, (add_button.x + 12, add_button.y + 8))

    def _draw_preview(self, surface):
        preview_rect = pygame.Rect(20, self.builder_rect.bottom + 20, self.rect.width - 40, self.rect.height - self.builder_rect.bottom - 40)
        pygame.draw.rect(surface, self.theme.bg_medium, preview_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, preview_rect, 1, border_radius=8)

        expression = self._build_expression()
        expr_surf, _ = self.font.render(f"Expression: {expression}", self.theme.text_primary)
        surface.blit(expr_surf, (preview_rect.x + 16, preview_rect.y + 16))

        result = self._evaluate_expression()
        result_text = f"Sample evaluation: {'TRUE' if result else 'FALSE'}"
        color = self.theme.accent_green if result else self.theme.accent_yellow
        result_surf, _ = self.font.render(result_text, color)
        surface.blit(result_surf, (preview_rect.x + 16, preview_rect.y + 46))

        sample_title, _ = self.small_font.render("Sample State", self.theme.text_secondary)
        surface.blit(sample_title, (preview_rect.x + 16, preview_rect.y + 80))

        y = preview_rect.y + 100
        for key, value in self.sample_state.items():
            if isinstance(value, dict):
                surf, _ = self.small_font.render(f"{key}: {value}", self.theme.text_disabled)
            else:
                surf, _ = self.small_font.render(f"{key} = {value}", self.theme.text_secondary)
            surface.blit(surf, (preview_rect.x + 16, y))
            y += 20

    def _draw_toggle_cell(self, surface, rect, label, disabled=False):
        color = self.theme.bg_light if not disabled else self.theme.bg_dark
        pygame.draw.rect(surface, color, rect, border_radius=4)
        pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)
        surf, _ = self.font.render(label, self.theme.text_primary if not disabled else self.theme.text_disabled)
        surface.blit(surf, (rect.x + 8, rect.y + 6))

    def _draw_delete(self, surface, rect):
        pygame.draw.rect(surface, self.theme.bg_light, rect, border_radius=4)
        pygame.draw.rect(surface, self.theme.accent_yellow, rect, 1, border_radius=4)
        surf, _ = self.font.render("×", self.theme.accent_yellow)
        surface.blit(surf, (rect.x + 8, rect.y + 4))

    def _build_expression(self) -> str:
        parts = []
        for idx, row in enumerate(self.rows):
            stat = AVAILABLE_STATS[row["stat_index"]]
            operator = OPERATORS[row["operator_index"]]
            value = row["input"].get_value() or "0"
            parts.append(f"{stat} {operator} {value}")
            if idx < len(self.rows) - 1:
                parts.append(CONNECTORS[row["connector_index"]])
        return " ".join(parts)

    def _evaluate_expression(self) -> bool:
        result = None
        for idx, row in enumerate(self.rows):
            stat = AVAILABLE_STATS[row["stat_index"]]
            operator = OPERATORS[row["operator_index"]]
            raw_value = row["input"].get_value() or "0"
            comparison = self._compare(stat, operator, raw_value)
            if result is None:
                result = comparison
            else:
                connector = CONNECTORS[self.rows[idx - 1]["connector_index"]]
                if connector == "and":
                    result = result and comparison
                else:
                    result = result or comparison
        return bool(result)

    def _compare(self, stat: str, operator: str, raw_value: str) -> bool:
        left = self._resolve_stat(stat)
        right = self._parse_value(raw_value)
        if operator == "==":
            return left == right
        if operator == "!=":
            return left != right
        if operator == "<":
            return left < right
        if operator == "<=":
            return left <= right
        if operator == ">":
            return left > right
        if operator == ">=":
            return left >= right
        return False

    def _resolve_stat(self, stat: str):
        parts = stat.split(".")
        current = self.sample_state
        for part in parts:
            if isinstance(current, dict) and part in current:
                current = current[part]
            else:
                return 0
        return current

    def _parse_value(self, raw: str):
        text = raw.strip()
        if text.lower() in {"true", "false"}:
            return text.lower() == "true"
        try:
            if "." in text:
                return float(text)
            return int(text)
        except ValueError:
            return text.strip('"')

    def _stat_rect(self, idx):
        y = self.builder_rect.y + 50 + idx * 40
        return pygame.Rect(self.builder_rect.x + 10, y, 200, 30)

    def _operator_rect(self, idx):
        y = self.builder_rect.y + 50 + idx * 40
        return pygame.Rect(self.builder_rect.x + 220, y, 100, 30)

    def _value_rect(self, idx):
        y = self.builder_rect.y + 50 + idx * 40
        return pygame.Rect(self.builder_rect.x + 330, y, 150, 30)

    def _connector_rect(self, idx):
        y = self.builder_rect.y + 50 + idx * 40
        return pygame.Rect(self.builder_rect.x + 490, y, 110, 30)

    def _delete_rect(self, idx):
        y = self.builder_rect.y + 50 + idx * 40
        return pygame.Rect(self.builder_rect.right - 50, y, 30, 30)

    def _add_button_rect(self):
        return pygame.Rect(self.builder_rect.right - 200, self.builder_rect.bottom - 50, 180, 36)

    def cleanup(self):
        pass
