"""Chart Editor Module - build rhythm charts with lanes, players, and characters."""
from __future__ import annotations

from typing import Dict, List, Tuple

import pygame
import pygame.freetype

from modules.ui.widgets import Dropdown, TextInput


COLOR_OPTIONS = [
    ("Blue", (80, 140, 255)),
    ("Red", (255, 100, 100)),
    ("Green", (100, 220, 140)),
    ("Yellow", (255, 200, 80)),
    ("Purple", (180, 120, 255)),
    ("Teal", (80, 200, 200)),
]


class ChartEditor:
    """Simple chart editor inspired by Psych Engine style charts."""

    def __init__(self, workspace_rect, theme, project_root):
        del project_root  # Reserved for future exporting/loading
        self.rect = workspace_rect
        self.theme = theme
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)

        self.margin = 20
        self.left_panel_width = 320
        self.toolbar_height = 70

        self.song_input = TextInput(pygame.Rect(0, 0, 200, 28), self.font, placeholder="Song name", text="")
        self.bpm_input = TextInput(pygame.Rect(0, 0, 120, 28), self.font, placeholder="BPM", text="120")

        self.characters: List[Dict[str, str]] = [
            {"name": "Boyfriend", "color": "Blue"},
            {"name": "Opponent", "color": "Red"},
        ]
        self.selected_character_index = 0
        self.character_name_input = TextInput(pygame.Rect(0, 0, 140, 28), self.font, placeholder="Character name")
        self.character_color_dropdown = Dropdown(
            pygame.Rect(0, 0, 120, 28),
            self.font,
            [opt[0] for opt in COLOR_OPTIONS],
            value=COLOR_OPTIONS[0][0],
            placeholder="Color",
        )

        self.players: List[Dict[str, str]] = [
            {"name": "Player 1", "lanes": 4, "character": "Boyfriend"},
            {"name": "Player 2", "lanes": 4, "character": "Opponent"},
        ]
        self.selected_player_index = 0
        self.player_name_input = TextInput(pygame.Rect(0, 0, 140, 28), self.font, placeholder="Player name")
        self.player_lanes_input = TextInput(pygame.Rect(0, 0, 60, 28), self.font, placeholder="Lanes")
        self.player_character_dropdown = Dropdown(
            pygame.Rect(0, 0, 140, 28),
            self.font,
            self._character_names(),
            value=self.players[0]["character"],
            placeholder="Assign character",
        )
        self._load_player_inputs()

        self.grid_rows = 32
        self.grid_scroll = 0
        self.row_height = 24
        self.lane_width = 40
        self.header_height = 30
        self.notes = set()

        self.status_message = "Click a lane cell to toggle notes."
        self.status_color = self.theme.text_secondary
        self.status_timer = 0.0

    def _character_names(self) -> List[str]:
        return [char["name"] for char in self.characters]

    def _update_player_character_options(self):
        names = self._character_names()
        self.player_character_dropdown.set_options(names)
        if names and self.player_character_dropdown.get_value() not in names:
            self.player_character_dropdown.set_value(names[0])

    def _load_player_inputs(self):
        if not self.players:
            self.player_name_input.set_value("")
            self.player_lanes_input.set_value("")
            self.player_character_dropdown.set_options([])
            return
        player = self.players[self.selected_player_index]
        self.player_name_input.set_value(player["name"])
        self.player_lanes_input.set_value(str(player["lanes"]))
        self._update_player_character_options()
        self.player_character_dropdown.set_value(player.get("character", ""))

    def _commit_player_inputs(self):
        if not self.players:
            return
        player = self.players[self.selected_player_index]
        name = self.player_name_input.get_value() or player["name"]
        player["name"] = name
        lanes_raw = self.player_lanes_input.get_value()
        try:
            lanes = max(1, int(lanes_raw)) if lanes_raw else player["lanes"]
        except ValueError:
            lanes = player["lanes"]
        player["lanes"] = lanes
        player["character"] = self.player_character_dropdown.get_value()

    def _lane_layout(self) -> List[Tuple[int, int]]:
        layout = []
        for player_index, player in enumerate(self.players):
            for lane_index in range(player["lanes"]):
                layout.append((player_index, lane_index))
        return layout

    def _grid_rect(self) -> pygame.Rect:
        left_panel = self._left_panel_rect()
        return pygame.Rect(
            left_panel.right + self.margin,
            self.rect.y + self.margin + self.toolbar_height,
            self.rect.width - left_panel.width - self.margin * 3,
            self.rect.height - self.margin * 2 - self.toolbar_height,
        )

    def _left_panel_rect(self) -> pygame.Rect:
        return pygame.Rect(
            self.rect.x + self.margin,
            self.rect.y + self.margin,
            self.left_panel_width,
            self.rect.height - self.margin * 2,
        )

    def handle_event(self, event):
        self.song_input.handle_event(event)
        self.bpm_input.handle_event(event)
        self.character_name_input.handle_event(event)
        self.player_name_input.handle_event(event)
        self.player_lanes_input.handle_event(event)

        self.character_color_dropdown.handle_event(event)
        self.player_character_dropdown.handle_event(event)

        if event.type == pygame.MOUSEWHEEL:
            if self._grid_rect().collidepoint(pygame.mouse.get_pos()):
                self._scroll_grid(-event.y * self.row_height)

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            pos = event.pos
            if self._add_character_button().collidepoint(pos):
                self._add_character()
            elif self._remove_character_button().collidepoint(pos):
                self._remove_character()
            elif self._add_player_button().collidepoint(pos):
                self._add_player()
            elif self._remove_player_button().collidepoint(pos):
                self._remove_player()
            elif self._add_rows_button().collidepoint(pos):
                self.grid_rows += 16
            else:
                self._handle_list_click(pos)
                if self._grid_rect().collidepoint(pos):
                    self._toggle_grid_note(pos)

        if event.type == pygame.MOUSEBUTTONUP and event.button == 1:
            self._commit_player_inputs()

    def _scroll_grid(self, delta):
        view_height = max(0, self._grid_rect().height - self.header_height)
        max_scroll = max(0, self.grid_rows * self.row_height - view_height)
        self.grid_scroll = max(0, min(self.grid_scroll + delta, max_scroll))

    def _handle_list_click(self, pos):
        char_list = self._character_list_rects()
        for idx, rect in enumerate(char_list):
            if rect.collidepoint(pos):
                self.selected_character_index = idx
                return

        player_list = self._player_list_rects()
        for idx, rect in enumerate(player_list):
            if rect.collidepoint(pos):
                self.selected_player_index = idx
                self._load_player_inputs()
                return

    def _toggle_grid_note(self, pos):
        grid_rect = self._grid_rect()
        layout = self._lane_layout()
        lane_count = len(layout)
        if lane_count == 0:
            return
        lane_width = self._lane_width(grid_rect, lane_count)
        if pos[1] < grid_rect.y + self.header_height:
            return
        x = pos[0] - grid_rect.x
        y = pos[1] - grid_rect.y - self.header_height + self.grid_scroll
        lane = int(x // lane_width)
        row = int(y // self.row_height)
        if lane < 0 or lane >= lane_count or row < 0 or row >= self.grid_rows:
            return
        key = (row, lane)
        if key in self.notes:
            self.notes.remove(key)
        else:
            self.notes.add(key)

    def _add_character(self):
        name = self.character_name_input.get_value()
        if not name:
            self._set_status("Enter a character name before adding.", self.theme.accent_yellow)
            return
        if name in self._character_names():
            self._set_status("Character name already exists.", self.theme.accent_yellow)
            return
        color = self.character_color_dropdown.get_value()
        self.characters.append({"name": name, "color": color})
        self.character_name_input.set_value("")
        self._update_player_character_options()
        self._set_status(f"Added character '{name}'.", self.theme.accent_green)

    def _remove_character(self):
        if not self.characters:
            return
        removed = self.characters.pop(self.selected_character_index)
        if self.selected_character_index >= len(self.characters):
            self.selected_character_index = max(0, len(self.characters) - 1)
        for player in self.players:
            if player.get("character") == removed["name"]:
                player["character"] = self._character_names()[0] if self.characters else ""
        self._update_player_character_options()
        self._set_status(f"Removed character '{removed['name']}'.", self.theme.accent_yellow)

    def _add_player(self):
        index = len(self.players) + 1
        default_char = self._character_names()[0] if self.characters else ""
        self.players.append({"name": f"Player {index}", "lanes": 4, "character": default_char})
        self.selected_player_index = len(self.players) - 1
        self._load_player_inputs()
        self._set_status("Added a new player lane group.", self.theme.accent_green)

    def _remove_player(self):
        if not self.players:
            return
        removed = self.players.pop(self.selected_player_index)
        if self.selected_player_index >= len(self.players):
            self.selected_player_index = max(0, len(self.players) - 1)
        self._load_player_inputs()
        self._set_status(f"Removed {removed['name']}.", self.theme.accent_yellow)

    def _set_status(self, message, color):
        self.status_message = message
        self.status_color = color
        self.status_timer = 3.0

    def update(self, dt):
        self.song_input.update(dt)
        self.bpm_input.update(dt)
        self.character_name_input.update(dt)
        self.player_name_input.update(dt)
        self.player_lanes_input.update(dt)
        if self.status_timer > 0:
            self.status_timer = max(0.0, self.status_timer - dt)

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        title_surf, _ = self.title_font.render("Chart Editor", self.theme.text_primary)
        surface.blit(title_surf, (self.rect.x + self.margin, self.rect.y + self.margin))
        subtitle = "Psych Engine-style charting with multiple lanes and character assignments."
        subtitle_surf, _ = self.font.render(subtitle, self.theme.text_secondary)
        surface.blit(subtitle_surf, (self.rect.x + self.margin, self.rect.y + self.margin + 34))

        self._draw_left_panel(surface)
        self._draw_grid(surface)
        self._draw_status(surface)

    def _draw_left_panel(self, surface):
        panel = self._left_panel_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, panel, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel, 1, border_radius=8)

        y = panel.y + 16
        y = self._draw_section_header(surface, panel.x + 16, y, "Chart Settings")

        self._draw_label(surface, panel.x + 16, y, "Song")
        self.song_input.rect = pygame.Rect(panel.x + 16, y + 18, panel.width - 32, 28)
        self.song_input.draw(surface, self.theme)
        y += 58

        self._draw_label(surface, panel.x + 16, y, "BPM")
        self.bpm_input.rect = pygame.Rect(panel.x + 16, y + 18, 120, 28)
        self.bpm_input.draw(surface, self.theme)

        add_rows_button = self._add_rows_button()
        self._draw_button(surface, add_rows_button, "Add 16 rows", self.theme.accent_blue)
        y += 70

        y = self._draw_section_header(surface, panel.x + 16, y, "Characters")
        self._draw_label(surface, panel.x + 16, y, "Name")
        self.character_name_input.rect = pygame.Rect(panel.x + 16, y + 18, 150, 28)
        self.character_name_input.draw(surface, self.theme)
        self.character_color_dropdown.set_rect(pygame.Rect(panel.x + 176, y + 18, 110, 28))
        self.character_color_dropdown.draw(surface, self.theme)
        y += 58

        self._draw_button(surface, self._add_character_button(), "Add", self.theme.accent_green)
        self._draw_button(surface, self._remove_character_button(), "Remove", self.theme.accent_red)
        y += 44

        y = self._draw_character_list(surface, panel.x + 16, y, panel.width - 32)

        y = self._draw_section_header(surface, panel.x + 16, y, "Players")
        self._draw_label(surface, panel.x + 16, y, "Name")
        self.player_name_input.rect = pygame.Rect(panel.x + 16, y + 18, 160, 28)
        self.player_name_input.draw(surface, self.theme)
        self.player_lanes_input.rect = pygame.Rect(panel.x + 190, y + 18, 60, 28)
        self.player_lanes_input.draw(surface, self.theme)
        y += 58

        self._draw_label(surface, panel.x + 16, y, "Character")
        self.player_character_dropdown.set_rect(pygame.Rect(panel.x + 16, y + 18, 200, 28))
        self.player_character_dropdown.draw(surface, self.theme)
        y += 58

        self._draw_button(surface, self._add_player_button(), "Add Player", self.theme.accent_green)
        self._draw_button(surface, self._remove_player_button(), "Remove", self.theme.accent_red)
        y += 44

        self._draw_player_list(surface, panel.x + 16, y, panel.width - 32)

        self.character_color_dropdown.draw_popup(surface, self.theme)
        self.player_character_dropdown.draw_popup(surface, self.theme)

    def _draw_grid(self, surface):
        grid_rect = self._grid_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, grid_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, grid_rect, 1, border_radius=8)

        layout = self._lane_layout()
        lane_count = len(layout)
        if lane_count == 0:
            empty_surf, _ = self.font.render("Add a player to start charting.", self.theme.text_secondary)
            surface.blit(empty_surf, (grid_rect.x + 16, grid_rect.y + 16))
            return
        lane_width = self._lane_width(grid_rect, lane_count)

        header_rect = pygame.Rect(grid_rect.x, grid_rect.y, grid_rect.width, self.header_height)
        pygame.draw.rect(surface, self.theme.bg_light, header_rect, border_radius=8)
        pygame.draw.line(surface, self.theme.border, (grid_rect.x, header_rect.bottom), (grid_rect.right, header_rect.bottom), 1)

        for lane_idx, (player_idx, lane_offset) in enumerate(layout):
            x = grid_rect.x + lane_idx * lane_width
            label = f"P{player_idx + 1}-{lane_offset + 1}"
            label_surf, _ = self.small_font.render(label, self.theme.text_secondary)
            surface.blit(label_surf, (x + 6, grid_rect.y + 8))
            pygame.draw.line(surface, self.theme.border, (x, grid_rect.y), (x, grid_rect.bottom), 1)

        scroll_y = self.grid_scroll
        visible_rows = int((grid_rect.height - self.header_height) // self.row_height) + 2
        start_row = int(scroll_y // self.row_height)
        end_row = min(self.grid_rows, start_row + visible_rows)

        for row in range(start_row, end_row):
            y = grid_rect.y + (row * self.row_height - scroll_y) + self.header_height
            row_rect = pygame.Rect(grid_rect.x, y, grid_rect.width, self.row_height)
            if row % 4 == 0:
                pygame.draw.rect(surface, self.theme.bg_light, row_rect)
            pygame.draw.line(surface, self.theme.grid_line, (grid_rect.x, y), (grid_rect.right, y), 1)

            beat_label = f"{row + 1}" if row % 4 == 0 else ""
            if beat_label:
                label_surf, _ = self.small_font.render(beat_label, self.theme.text_disabled)
                surface.blit(label_surf, (grid_rect.x + 4, y + 6))

            for lane in range(lane_count):
                cell_rect = pygame.Rect(
                    grid_rect.x + lane * lane_width,
                    y,
                    lane_width,
                    self.row_height,
                )
                if (row, lane) in self.notes:
                    pygame.draw.rect(surface, self.theme.accent_blue, cell_rect.inflate(-6, -6), border_radius=4)

        pygame.draw.line(surface, self.theme.border, (grid_rect.x, grid_rect.y + self.header_height), (grid_rect.right, grid_rect.y + self.header_height), 1)

    def _draw_status(self, surface):
        if not self.status_message:
            return
        color = self.status_color if self.status_timer > 0 else self.theme.text_secondary
        status_surf, _ = self.font.render(self.status_message, color)
        surface.blit(status_surf, (self.rect.x + self.margin, self.rect.bottom - self.margin - 24))

    def _draw_section_header(self, surface, x, y, text):
        header_surf, _ = self.font.render(text, self.theme.text_primary)
        surface.blit(header_surf, (x, y))
        return y + 24

    def _draw_label(self, surface, x, y, text):
        label_surf, _ = self.small_font.render(text, self.theme.text_disabled)
        surface.blit(label_surf, (x, y))

    def _draw_button(self, surface, rect, text, color):
        pygame.draw.rect(surface, color, rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=6)
        label_surf, _ = self.font.render(text, self.theme.text_primary)
        surface.blit(label_surf, (rect.x + 10, rect.y + 6))

    def _draw_character_list(self, surface, x, y, width):
        if not self.characters:
            empty_surf, _ = self.small_font.render("No characters defined.", self.theme.text_secondary)
            surface.blit(empty_surf, (x, y))
            return y + 24
        for idx, character in enumerate(self.characters):
            rect = pygame.Rect(x, y, width, 26)
            bg = self.theme.bg_light if idx == self.selected_character_index else self.theme.bg_medium
            pygame.draw.rect(surface, bg, rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)
            color = self._color_for_name(character["color"])
            pygame.draw.rect(surface, color, pygame.Rect(rect.x + 6, rect.y + 6, 12, 12), border_radius=3)
            label, _ = self.small_font.render(character["name"], self.theme.text_primary)
            surface.blit(label, (rect.x + 24, rect.y + 5))
            y += 30
        return y

    def _draw_player_list(self, surface, x, y, width):
        if not self.players:
            empty_surf, _ = self.small_font.render("No players defined.", self.theme.text_secondary)
            surface.blit(empty_surf, (x, y))
            return
        for idx, player in enumerate(self.players):
            rect = pygame.Rect(x, y, width, 26)
            bg = self.theme.bg_light if idx == self.selected_player_index else self.theme.bg_medium
            pygame.draw.rect(surface, bg, rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)
            label_text = f"{player['name']} ({player['lanes']} lanes)"
            label, _ = self.small_font.render(label_text, self.theme.text_primary)
            surface.blit(label, (rect.x + 8, rect.y + 5))
            char_label = player.get("character", "")
            if char_label:
                char_surf, _ = self.small_font.render(char_label, self.theme.text_secondary)
                surface.blit(char_surf, (rect.right - char_surf.get_width() - 8, rect.y + 5))
            y += 30

    def _character_list_rects(self):
        panel = self._left_panel_rect()
        start_y = panel.y + 16
        start_y += 24 + 58 + 70
        start_y += 24 + 58 + 44
        rects = []
        y = start_y
        for _ in self.characters:
            rects.append(pygame.Rect(panel.x + 16, y, panel.width - 32, 26))
            y += 30
        return rects

    def _player_list_rects(self):
        panel = self._left_panel_rect()
        start_y = panel.y + 16
        start_y += 24 + 58 + 70
        start_y += 24 + 58 + 44
        start_y += self._character_list_height()
        start_y += 24 + 58 + 58 + 44
        rects = []
        y = start_y
        for _ in self.players:
            rects.append(pygame.Rect(panel.x + 16, y, panel.width - 32, 26))
            y += 30
        return rects

    def _add_character_button(self):
        panel = self._left_panel_rect()
        y = panel.y + 16
        y += 24 + 58
        return pygame.Rect(panel.x + 16, y, 90, 28)

    def _remove_character_button(self):
        panel = self._left_panel_rect()
        y = panel.y + 16
        y += 24 + 58
        return pygame.Rect(panel.x + 116, y, 90, 28)

    def _add_player_button(self):
        panel = self._left_panel_rect()
        y = self._player_buttons_y()
        return pygame.Rect(panel.x + 16, y, 120, 28)

    def _remove_player_button(self):
        panel = self._left_panel_rect()
        y = self._player_buttons_y()
        return pygame.Rect(panel.x + 146, y, 100, 28)

    def _player_buttons_y(self):
        panel = self._left_panel_rect()
        y = panel.y + 16
        y += 24 + 58 + 70
        y += 24 + 58 + 44
        y += self._character_list_height()
        y += 24 + 58 + 58
        return y

    def _character_list_height(self):
        if not self.characters:
            return 24
        return len(self.characters) * 30

    def _add_rows_button(self):
        panel = self._left_panel_rect()
        y = panel.y + 16 + 24 + 58
        return pygame.Rect(panel.x + 150, y, 120, 28)

    def _color_for_name(self, name):
        for option_name, color in COLOR_OPTIONS:
            if option_name == name:
                return color
        return self.theme.text_secondary

    def _lane_width(self, grid_rect, lane_count):
        if lane_count <= 0:
            return self.lane_width
        return max(24, grid_rect.width // lane_count)
