"""
Character Editor Module

Edit characters.json — the registry of all VN characters and their atlas paths.
Each character entry has VN (visual novel) and rhythm game atlas references.

Layout
------
Left panel  : scrollable list of character IDs  +  "New Character" button
Right panel : editable fields for the selected character
Bottom bar  : Save button + status message
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, Any, Optional, List

import pygame
import pygame.freetype

from modules.ui.theme import Theme
from modules.ui.widgets import TextInput


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

CHARACTERS_JSON_RELPATH = Path("assets") / "data" / "characters" / "characters.json"

FIELD_DEFS: List[Dict[str, str]] = [
    {"key": "vn_png",        "label": "VN Atlas PNG",      "section": "vn",      "sub": "png"},
    {"key": "vn_xml",        "label": "VN Atlas XML",      "section": "vn",      "sub": "xml"},
    {"key": "vn_pose",       "label": "VN Default Pose",   "section": "vn",      "sub": "defaultPose"},
    {"key": "rhythm_png",    "label": "Rhythm Atlas PNG",  "section": "rhythm",  "sub": "png"},
    {"key": "rhythm_xml",    "label": "Rhythm Atlas XML",  "section": "rhythm",  "sub": "xml"},
]


def _char_to_fields(char_data: Dict[str, Any]) -> Dict[str, str]:
    """Extract flat field values from a character dict."""
    vn     = char_data.get("vn", {})
    rhythm = char_data.get("rhythm", {})
    return {
        "vn_png":     vn.get("png", ""),
        "vn_xml":     vn.get("xml", ""),
        "vn_pose":    vn.get("defaultPose", ""),
        "rhythm_png": rhythm.get("png", ""),
        "rhythm_xml": rhythm.get("xml", ""),
    }


def _fields_to_char(char_id: str, fields: Dict[str, str]) -> Dict[str, Any]:
    """Pack flat field values back into a character dict."""
    return {
        "id": char_id,
        "vn": {
            "png":         fields.get("vn_png", ""),
            "xml":         fields.get("vn_xml", ""),
            "defaultPose": fields.get("vn_pose", ""),
        },
        "rhythm": {
            "png": fields.get("rhythm_png", ""),
            "xml": fields.get("rhythm_xml", ""),
        },
    }


# ---------------------------------------------------------------------------
# Main module
# ---------------------------------------------------------------------------

class CharacterEditorModule:
    """Pygame module for editing characters.json."""

    LEFT_W  = 220   # width of character-list panel
    PADDING = 14
    ROW_H   = 34    # height of each list row
    FIELD_H = 32    # height of each text input
    LABEL_W = 150   # width of field labels
    INPUT_H = 28

    def __init__(self, workspace_rect: pygame.Rect, theme: Theme, project_root: Path):
        self.rect         = pygame.Rect(workspace_rect)
        self.theme        = theme
        self.project_root = Path(project_root)
        self.json_path    = self.project_root / CHARACTERS_JSON_RELPATH

        # Fonts
        self.font       = pygame.freetype.SysFont("Arial", 13)
        self.title_font = pygame.freetype.SysFont("Arial", 20, bold=True)
        self.label_font = pygame.freetype.SysFont("Arial", 12)
        self.small_font = pygame.freetype.SysFont("Arial", 11)

        # State
        self.characters: Dict[str, Dict[str, Any]] = {}
        self.char_order:  List[str] = []
        self.selected_id: Optional[str] = None
        self.is_new:      bool = False          # True while adding a brand-new char
        self.new_id_input: Optional[TextInput] = None

        # Field inputs (keyed by FIELD_DEFS[*]["key"])
        self.field_inputs: Dict[str, TextInput] = {}

        # Scroll
        self.list_scroll = 0

        # Status
        self.status_msg   = ""
        self.status_color = theme.text_secondary
        self.status_timer = 0.0

        # Confirm-delete state
        self.confirm_delete = False

        # Computed layout rects (filled in _layout())
        self.list_rect    = pygame.Rect(0, 0, 0, 0)
        self.detail_rect  = pygame.Rect(0, 0, 0, 0)
        self.btn_new_rect = pygame.Rect(0, 0, 0, 0)
        self.btn_del_rect = pygame.Rect(0, 0, 0, 0)
        self.btn_save_rect= pygame.Rect(0, 0, 0, 0)
        self.btn_confirm_rect = pygame.Rect(0, 0, 0, 0)
        self.btn_cancel_rect  = pygame.Rect(0, 0, 0, 0)

        self._layout()
        self._build_field_inputs()
        self._load()

    # ------------------------------------------------------------------
    # Layout
    # ------------------------------------------------------------------

    def _layout(self):
        r = self.rect
        p = self.PADDING

        # Bottom bar: Save + status
        bar_h = 44
        self.bottom_bar = pygame.Rect(r.x, r.bottom - bar_h, r.width, bar_h)

        # Left list panel
        self.list_rect = pygame.Rect(r.x, r.y, self.LEFT_W, r.height - bar_h)

        # New-char button inside list panel (bottom)
        btn_w, btn_h = self.LEFT_W - p * 2, 32
        self.btn_new_rect = pygame.Rect(
            self.list_rect.x + p,
            self.list_rect.bottom - btn_h - p,
            btn_w, btn_h
        )

        # Scrollable list area (above new button)
        self.list_scroll_rect = pygame.Rect(
            self.list_rect.x,
            self.list_rect.y + 50,   # below title
            self.LEFT_W,
            self.list_rect.height - 50 - btn_h - p * 2
        )

        # Right detail panel
        self.detail_rect = pygame.Rect(
            r.x + self.LEFT_W + 2,
            r.y,
            r.width - self.LEFT_W - 2,
            r.height - bar_h
        )

        # Delete button (top-right of detail panel)
        self.btn_del_rect = pygame.Rect(
            self.detail_rect.right - 120 - p,
            self.detail_rect.y + p,
            120, 30
        )

        # Save button
        self.btn_save_rect = pygame.Rect(
            self.bottom_bar.right - 180 - p,
            self.bottom_bar.y + 6,
            180, 32
        )

        # Confirm-delete buttons
        self.btn_confirm_rect = pygame.Rect(
            self.detail_rect.centerx - 110,
            self.detail_rect.centery,
            100, 34
        )
        self.btn_cancel_rect = pygame.Rect(
            self.detail_rect.centerx + 10,
            self.detail_rect.centery,
            100, 34
        )

    def _build_field_inputs(self):
        """Create TextInput widgets for each field."""
        self.field_inputs.clear()
        dx = self.detail_rect.x + self.PADDING
        dy_start = self.detail_rect.y + 60  # below header row
        for i, fd in enumerate(FIELD_DEFS):
            y = dy_start + i * (self.INPUT_H + 10)
            rect = pygame.Rect(
                dx + self.LABEL_W + 8,
                y,
                self.detail_rect.width - self.LABEL_W - 8 - self.PADDING * 2,
                self.INPUT_H
            )
            ti = TextInput(rect, self.font, placeholder=fd["label"])
            self.field_inputs[fd["key"]] = ti

        # New-character ID input (same width as list panel minus padding)
        id_rect = pygame.Rect(
            self.list_rect.x + self.PADDING,
            self.list_rect.y + 50,   # just under list title
            self.LEFT_W - self.PADDING * 2,
            self.INPUT_H
        )
        self.new_id_input = TextInput(id_rect, self.font, placeholder="character_id")

    # ------------------------------------------------------------------
    # Data I/O
    # ------------------------------------------------------------------

    def _load(self):
        """Load characters.json from disk."""
        try:
            with open(self.json_path, "r", encoding="utf-8") as f:
                self.characters = json.load(f)
        except FileNotFoundError:
            self.characters = {}
            self._set_status(f"File not found: {self.json_path}", error=True)
        except json.JSONDecodeError as exc:
            self.characters = {}
            self._set_status(f"JSON error: {exc}", error=True)
        self.char_order = sorted(self.characters.keys())
        self.selected_id = None
        self.is_new = False
        self._clear_fields()

    def _save(self):
        """Write current state to characters.json."""
        # Flush any active field edits into self.characters first
        if self.selected_id:
            self._apply_fields_to_data()

        try:
            self.json_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.json_path, "w", encoding="utf-8") as f:
                json.dump(self.characters, f, indent=2, ensure_ascii=False)
            self._set_status("Saved characters.json", error=False)
        except OSError as exc:
            self._set_status(f"Save failed: {exc}", error=True)

    def _apply_fields_to_data(self):
        """Push field input values into self.characters[self.selected_id]."""
        if not self.selected_id:
            return
        values = {k: ti.get_value() for k, ti in self.field_inputs.items()}
        self.characters[self.selected_id] = _fields_to_char(self.selected_id, values)

    # ------------------------------------------------------------------
    # Selection helpers
    # ------------------------------------------------------------------

    def _select_character(self, char_id: str):
        # Commit any previous edits
        if self.selected_id and not self.is_new:
            self._apply_fields_to_data()

        self.selected_id = char_id
        self.is_new = False
        self.confirm_delete = False

        char_data = self.characters.get(char_id, {})
        values = _char_to_fields(char_data)
        for fd in FIELD_DEFS:
            self.field_inputs[fd["key"]].set_value(values.get(fd["key"], ""))

    def _clear_fields(self):
        for ti in self.field_inputs.values():
            ti.set_value("")
        self.selected_id = None
        self.is_new = False
        self.confirm_delete = False

    # ------------------------------------------------------------------
    # Status
    # ------------------------------------------------------------------

    def _set_status(self, msg: str, error: bool = False):
        self.status_msg   = msg
        self.status_color = self.theme.error_red if error else self.theme.success_green
        self.status_timer = 5.0

    # ------------------------------------------------------------------
    # Event handling
    # ------------------------------------------------------------------

    def handle_event(self, event: pygame.event.Event):
        # Confirm-delete dialog intercepts all clicks
        if self.confirm_delete:
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                if self.btn_confirm_rect.collidepoint(event.pos):
                    self._do_delete()
                elif self.btn_cancel_rect.collidepoint(event.pos):
                    self.confirm_delete = False
            return

        # Pass event to all field inputs
        for ti in self.field_inputs.values():
            ti.handle_event(event)

        # ID input while adding new character
        if self.is_new and self.new_id_input:
            self.new_id_input.handle_event(event)

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            pos = event.pos
            self._handle_click(pos)

        elif event.type == pygame.MOUSEWHEEL:
            if self.list_scroll_rect.collidepoint(pygame.mouse.get_pos()):
                self.list_scroll -= event.y * self.ROW_H
                self._clamp_scroll()

        elif event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                if self.is_new:
                    self._commit_new_character()

    def _handle_click(self, pos):
        # New character button
        if self.btn_new_rect.collidepoint(pos):
            self._start_new_character()
            return

        # Delete button (only when a character is selected and not new)
        if self.selected_id and not self.is_new:
            if self.btn_del_rect.collidepoint(pos):
                self.confirm_delete = True
                return

        # Save button
        if self.btn_save_rect.collidepoint(pos):
            self._save()
            return

        # Character list rows
        if self.list_scroll_rect.collidepoint(pos):
            rel_y = pos[1] - self.list_scroll_rect.y + self.list_scroll
            idx = rel_y // self.ROW_H
            if 0 <= idx < len(self.char_order):
                self._select_character(self.char_order[idx])
            return

    # ------------------------------------------------------------------
    # New character
    # ------------------------------------------------------------------

    def _start_new_character(self):
        # Commit any pending edits first
        if self.selected_id and not self.is_new:
            self._apply_fields_to_data()

        self.is_new = True
        self.selected_id = None
        self.confirm_delete = False
        if self.new_id_input:
            self.new_id_input.set_value("")
            self.new_id_input.active = True
        self._clear_fields()
        self.is_new = True  # _clear_fields resets it

    def _commit_new_character(self):
        if not self.new_id_input:
            return
        new_id = self.new_id_input.get_value().strip().lower().replace(" ", "_")
        if not new_id:
            self._set_status("Character ID cannot be empty.", error=True)
            return
        if new_id in self.characters:
            self._set_status(f'"{new_id}" already exists.', error=True)
            return

        # Build default entry
        base = f"assets/images/characters/{new_id}/{new_id}"
        self.characters[new_id] = {
            "id": new_id,
            "vn": {
                "png":         f"{base}.png",
                "xml":         f"{base}.xml",
                "defaultPose": "neutral",
            },
            "rhythm": {
                "png": f"{base}_rhythm.png",
                "xml": f"{base}_rhythm.xml",
            },
        }
        self.char_order = sorted(self.characters.keys())
        self.is_new = False
        self._select_character(new_id)
        self._set_status(f'Added "{new_id}". Edit fields and Save.', error=False)

    # ------------------------------------------------------------------
    # Delete
    # ------------------------------------------------------------------

    def _do_delete(self):
        if not self.selected_id:
            return
        removed = self.selected_id
        del self.characters[removed]
        self.char_order = sorted(self.characters.keys())
        self._clear_fields()
        self.confirm_delete = False
        self._set_status(f'Deleted "{removed}". Save to persist.', error=False)

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------

    def update(self, dt: float):
        for ti in self.field_inputs.values():
            ti.update(dt)
        if self.is_new and self.new_id_input:
            self.new_id_input.update(dt)

        if self.status_timer > 0:
            self.status_timer -= dt
            if self.status_timer <= 0:
                self.status_msg = ""

    # ------------------------------------------------------------------
    # Draw
    # ------------------------------------------------------------------

    def draw(self, surface: pygame.Surface):
        surface.fill(self.theme.bg_dark)

        self._draw_list_panel(surface)
        self._draw_separator(surface)
        self._draw_detail_panel(surface)
        self._draw_bottom_bar(surface)

        if self.confirm_delete:
            self._draw_confirm_overlay(surface)

    def _draw_list_panel(self, surface: pygame.Surface):
        r = self.list_rect
        pygame.draw.rect(surface, self.theme.bg_medium, r)

        # Title
        title_surf, _ = self.font.render("Characters", self.theme.text_primary)
        surface.blit(title_surf, (r.x + self.PADDING, r.y + 14))

        # Scrollable rows — clip to list_scroll_rect
        clip = surface.get_clip()
        surface.set_clip(self.list_scroll_rect)

        y = self.list_scroll_rect.y - self.list_scroll
        for char_id in self.char_order:
            row_rect = pygame.Rect(
                r.x + 4,
                y,
                r.width - 8,
                self.ROW_H - 2
            )
            if self.list_scroll_rect.colliderect(row_rect):
                is_selected = (char_id == self.selected_id)
                bg = self.theme.bg_active if is_selected else self.theme.bg_light
                pygame.draw.rect(surface, bg, row_rect, border_radius=4)
                if is_selected:
                    ind = pygame.Rect(r.x + 4, y + 4, 3, self.ROW_H - 10)
                    pygame.draw.rect(surface, self.theme.accent_blue, ind)
                text_color = self.theme.text_primary if is_selected else self.theme.text_secondary
                ts, _ = self.font.render(char_id, text_color)
                surface.blit(ts, (row_rect.x + 10, row_rect.y + (self.ROW_H - 2 - ts.get_height()) // 2))
            y += self.ROW_H

        surface.set_clip(clip)

        # New Character button
        btn_color = self.theme.accent_green
        pygame.draw.rect(surface, btn_color, self.btn_new_rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, self.btn_new_rect, 1, border_radius=6)
        btn_surf, _ = self.font.render("+ New Character", self.theme.bg_dark)
        bx = self.btn_new_rect.x + (self.btn_new_rect.width - btn_surf.get_width()) // 2
        by = self.btn_new_rect.y + (self.btn_new_rect.height - btn_surf.get_height()) // 2
        surface.blit(btn_surf, (bx, by))

    def _draw_separator(self, surface: pygame.Surface):
        x = self.rect.x + self.LEFT_W
        pygame.draw.line(
            surface,
            self.theme.border,
            (x, self.rect.y),
            (x, self.rect.bottom),
            2
        )

    def _draw_detail_panel(self, surface: pygame.Surface):
        dr = self.detail_rect
        pygame.draw.rect(surface, self.theme.bg_dark, dr)

        if self.is_new:
            self._draw_new_char_form(surface)
            return

        if not self.selected_id:
            msg_surf, _ = self.font.render(
                "Select a character or click '+ New Character'",
                self.theme.text_disabled
            )
            surface.blit(msg_surf, (
                dr.x + (dr.width - msg_surf.get_width()) // 2,
                dr.y + (dr.height - msg_surf.get_height()) // 2
            ))
            return

        # Header: character ID
        id_surf, _ = self.title_font.render(self.selected_id, self.theme.text_primary)
        surface.blit(id_surf, (dr.x + self.PADDING, dr.y + self.PADDING))

        # Delete button
        pygame.draw.rect(surface, self.theme.bg_light, self.btn_del_rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.accent_red, self.btn_del_rect, 1, border_radius=6)
        del_surf, _ = self.font.render("Delete Character", self.theme.accent_red)
        dx = self.btn_del_rect.x + (self.btn_del_rect.width - del_surf.get_width()) // 2
        dy = self.btn_del_rect.y + (self.btn_del_rect.height - del_surf.get_height()) // 2
        surface.blit(del_surf, (dx, dy))

        # Section separators + fields
        dy_start = dr.y + 60
        current_section = None
        for i, fd in enumerate(FIELD_DEFS):
            y = dy_start + i * (self.INPUT_H + 10)
            section = fd["section"]

            # Draw section header
            if section != current_section:
                current_section = section
                sec_label = "VN Atlas" if section == "vn" else "Rhythm Atlas"
                pygame.draw.line(
                    surface,
                    self.theme.border,
                    (dr.x + self.PADDING, y - 4),
                    (dr.right - self.PADDING, y - 4),
                    1
                )
                sec_surf, _ = self.small_font.render(sec_label.upper(), self.theme.text_disabled)
                surface.blit(sec_surf, (dr.x + self.PADDING, y - 4 - sec_surf.get_height() - 2))

            # Label
            lbl_surf, _ = self.label_font.render(fd["label"] + ":", self.theme.text_secondary)
            lbl_y = y + (self.INPUT_H - lbl_surf.get_height()) // 2
            surface.blit(lbl_surf, (dr.x + self.PADDING, lbl_y))

            # TextInput
            self.field_inputs[fd["key"]].draw(surface, self.theme)

    def _draw_new_char_form(self, surface: pygame.Surface):
        dr = self.detail_rect
        title_surf, _ = self.title_font.render("New Character", self.theme.accent_green)
        surface.blit(title_surf, (dr.x + self.PADDING, dr.y + self.PADDING))

        instr_surf, _ = self.font.render(
            "Enter a unique ID (lowercase, underscores) and press Enter to create.",
            self.theme.text_secondary
        )
        surface.blit(instr_surf, (dr.x + self.PADDING, dr.y + 44))

        lbl_surf, _ = self.label_font.render("Character ID:", self.theme.text_secondary)
        surface.blit(lbl_surf, (dr.x + self.PADDING, dr.y + 76))

        if self.new_id_input:
            # Reposition ID input inside detail panel
            self.new_id_input.rect = pygame.Rect(
                dr.x + self.PADDING,
                dr.y + 94,
                min(300, dr.width - self.PADDING * 2),
                self.INPUT_H
            )
            self.new_id_input.draw(surface, self.theme)

        hint_surf, _ = self.small_font.render("Press Enter to confirm.", self.theme.text_disabled)
        surface.blit(hint_surf, (dr.x + self.PADDING, dr.y + 94 + self.INPUT_H + 6))

    def _draw_bottom_bar(self, surface: pygame.Surface):
        bb = self.bottom_bar
        pygame.draw.rect(surface, self.theme.bg_medium, bb)
        pygame.draw.line(
            surface,
            self.theme.border,
            (bb.x, bb.y),
            (bb.right, bb.y),
            1
        )

        # Save button
        pygame.draw.rect(surface, self.theme.accent_blue, self.btn_save_rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, self.btn_save_rect, 1, border_radius=6)
        save_surf, _ = self.font.render("Save characters.json", self.theme.bg_dark)
        sx = self.btn_save_rect.x + (self.btn_save_rect.width - save_surf.get_width()) // 2
        sy = self.btn_save_rect.y + (self.btn_save_rect.height - save_surf.get_height()) // 2
        surface.blit(save_surf, (sx, sy))

        # Status message
        if self.status_msg:
            st_surf, _ = self.font.render(self.status_msg, self.status_color)
            surface.blit(st_surf, (bb.x + self.PADDING, bb.y + (bb.height - st_surf.get_height()) // 2))

    def _draw_confirm_overlay(self, surface: pygame.Surface):
        overlay = pygame.Surface((self.rect.width, self.rect.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        surface.blit(overlay, (self.rect.x, self.rect.y))

        dr = self.detail_rect
        box_w, box_h = 360, 140
        box_rect = pygame.Rect(
            dr.x + (dr.width - box_w) // 2,
            dr.y + (dr.height - box_h) // 2,
            box_w, box_h
        )
        pygame.draw.rect(surface, self.theme.bg_medium, box_rect, border_radius=10)
        pygame.draw.rect(surface, self.theme.accent_red, box_rect, 2, border_radius=10)

        q_surf, _ = self.font.render(
            f'Delete "{self.selected_id}"?',
            self.theme.text_primary
        )
        surface.blit(q_surf, (
            box_rect.x + (box_rect.width - q_surf.get_width()) // 2,
            box_rect.y + 18
        ))
        sub_surf, _ = self.small_font.render(
            "This will remove the entry. Save to persist.",
            self.theme.text_secondary
        )
        surface.blit(sub_surf, (
            box_rect.x + (box_rect.width - sub_surf.get_width()) // 2,
            box_rect.y + 44
        ))

        # Reposition confirm / cancel buttons relative to box
        self.btn_confirm_rect = pygame.Rect(box_rect.x + 30, box_rect.y + 82, 130, 34)
        self.btn_cancel_rect  = pygame.Rect(box_rect.right - 160, box_rect.y + 82, 130, 34)

        pygame.draw.rect(surface, self.theme.accent_red, self.btn_confirm_rect, border_radius=6)
        c_surf, _ = self.font.render("Yes, Delete", self.theme.bg_dark)
        surface.blit(c_surf, (
            self.btn_confirm_rect.x + (self.btn_confirm_rect.width - c_surf.get_width()) // 2,
            self.btn_confirm_rect.y + (self.btn_confirm_rect.height - c_surf.get_height()) // 2
        ))

        pygame.draw.rect(surface, self.theme.bg_light, self.btn_cancel_rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, self.btn_cancel_rect, 1, border_radius=6)
        can_surf, _ = self.font.render("Cancel", self.theme.text_primary)
        surface.blit(can_surf, (
            self.btn_cancel_rect.x + (self.btn_cancel_rect.width - can_surf.get_width()) // 2,
            self.btn_cancel_rect.y + (self.btn_cancel_rect.height - can_surf.get_height()) // 2
        ))

    # ------------------------------------------------------------------
    # Scroll helpers
    # ------------------------------------------------------------------

    def _clamp_scroll(self):
        max_scroll = max(0, len(self.char_order) * self.ROW_H - self.list_scroll_rect.height)
        self.list_scroll = max(0, min(self.list_scroll, max_scroll))

    # ------------------------------------------------------------------
    # Resize / cleanup
    # ------------------------------------------------------------------

    def on_resize(self, workspace_rect: pygame.Rect):
        self.rect = pygame.Rect(workspace_rect)
        self._layout()
        self._build_field_inputs()
        # Re-populate field values if a character is selected
        if self.selected_id:
            self._select_character(self.selected_id)

    def cleanup(self):
        pass

    def get_help_entries(self):
        return [
            (
                "Character Editor",
                [
                    "Click a character in the left list to select it",
                    "Edit atlas paths and default pose in the right panel",
                    "+ New Character — enter ID and press Enter to create",
                    "Delete Character — removes entry (requires confirmation)",
                    "Save characters.json — writes all changes to disk",
                    "Mouse wheel — scroll character list",
                ]
            )
        ]
