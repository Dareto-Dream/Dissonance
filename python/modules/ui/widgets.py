"""Shared lightweight UI widgets for pygame modules."""
from __future__ import annotations

import pygame
import pygame.freetype


class TextInput:
    """Simple rectangular text input field."""

    def __init__(self, rect, font: pygame.freetype.Font, placeholder: str = "", text: str = ""):
        self.rect = pygame.Rect(rect)
        self.font = font
        self.placeholder = placeholder
        self.text = text
        self.active = False
        self.cursor_visible = True
        self.cursor_timer = 0.0
        self.on_deactivate = None  # Optional callback when focus is lost

    def handle_event(self, event):
        handled = False
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            was_active = self.active
            self.active = self.rect.collidepoint(event.pos)
            if self.active and not was_active:
                self.cursor_visible = True
                self.cursor_timer = 0.0
            if was_active and not self.active and self.on_deactivate:
                self.on_deactivate(self)
            handled = self.rect.collidepoint(event.pos) or was_active
        elif event.type == pygame.KEYDOWN and self.active:
            if event.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                self.active = False
                if self.on_deactivate:
                    self.on_deactivate(self)
            elif event.key == pygame.K_BACKSPACE:
                self.text = self.text[:-1]
            elif event.key == pygame.K_ESCAPE:
                self.active = False
                if self.on_deactivate:
                    self.on_deactivate(self)
            elif event.key == pygame.K_TAB:
                pass
            else:
                if event.unicode and event.unicode.isprintable():
                    self.text += event.unicode
            handled = True
        return handled

    def update(self, dt):
        if self.active:
            self.cursor_timer += dt
            if self.cursor_timer >= 0.5:
                self.cursor_timer = 0.0
                self.cursor_visible = not self.cursor_visible
        else:
            self.cursor_visible = False

    def draw(self, surface, theme):
        pygame.draw.rect(
            surface,
            theme.bg_light if self.active else theme.bg_medium,
            self.rect,
            border_radius=4,
        )
        pygame.draw.rect(surface, theme.border, self.rect, 1, border_radius=4)

        display_text = self.text if self.text else self.placeholder
        color = theme.text_primary if self.text else theme.text_disabled
        text_surf, _ = self.font.render(display_text, color)
        surface.blit(text_surf, (self.rect.x + 6, self.rect.y + (self.rect.height - text_surf.get_height()) // 2))

        if self.active and self.cursor_visible:
            cursor_x = self.rect.x + 6 + text_surf.get_width() + 2
            cursor_rect = pygame.Rect(cursor_x, self.rect.y + 6, 2, self.rect.height - 12)
            pygame.draw.rect(surface, theme.text_primary, cursor_rect)

    def get_value(self) -> str:
        return self.text.strip()

    def set_value(self, value: str):
        self.text = value or ""


class Dropdown:
    """Basic dropdown/select widget."""

    def __init__(self, rect, font: pygame.freetype.Font, options, value=None, placeholder: str = "Select"):
        self.rect = pygame.Rect(rect)
        self.font = font
        self.options = options or []
        self.placeholder = placeholder
        self.selected = value if value in self.options else (self.options[0] if self.options else "")
        self.open = False
        self.option_rects = []

    def set_rect(self, rect):
        self.rect = pygame.Rect(rect)

    def set_options(self, options):
        self.options = options or []
        if self.selected not in self.options:
            self.selected = self.options[0] if self.options else ""

    def set_value(self, value):
        if value in self.options:
            self.selected = value

    def get_value(self):
        return self.selected or ""

    def handle_event(self, event):
        handled = False
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.rect.collidepoint(event.pos):
                self.open = not self.open
                handled = True
            elif self.open:
                for idx, opt_rect in enumerate(self.option_rects):
                    if opt_rect.collidepoint(event.pos):
                        if idx < len(self.options):
                            self.selected = self.options[idx]
                        self.open = False
                        handled = True
                        break
                else:
                    if self.option_rects:
                        handled = True
                    self.open = False
        elif event.type == pygame.KEYDOWN and self.open:
            if event.key == pygame.K_ESCAPE:
                self.open = False
                handled = True
        return handled

    def draw(self, surface, theme):
        pygame.draw.rect(surface, theme.bg_medium, self.rect, border_radius=4)
        pygame.draw.rect(surface, theme.border, self.rect, 1, border_radius=4)
        text = self.selected or self.placeholder
        color = theme.text_primary if self.selected else theme.text_disabled
        text_surf, _ = self.font.render(text, color)
        surface.blit(text_surf, (self.rect.x + 8, self.rect.y + (self.rect.height - text_surf.get_height()) // 2))

        arrow_x = self.rect.right - 16
        arrow_y = self.rect.y + self.rect.height // 2
        pygame.draw.polygon(
            surface,
            theme.text_secondary,
            [
                (arrow_x - 5, arrow_y - 3),
                (arrow_x + 5, arrow_y - 3),
                (arrow_x, arrow_y + 4),
            ],
        )

    def draw_popup(self, surface, theme):
        self.option_rects = []
        if not (self.open and self.options):
            return
        option_height = self.rect.height
        total_height = option_height * len(self.options)
        list_rect = pygame.Rect(self.rect.x, self.rect.bottom, self.rect.width, total_height)
        pygame.draw.rect(surface, theme.bg_light, list_rect, border_radius=4)
        pygame.draw.rect(surface, theme.border, list_rect, 1, border_radius=4)
        for idx, option in enumerate(self.options):
            opt_rect = pygame.Rect(self.rect.x, self.rect.bottom + idx * option_height, self.rect.width, option_height)
            self.option_rects.append(opt_rect)
            bg_color = theme.accent_blue if option == self.selected else theme.bg_light
            pygame.draw.rect(surface, bg_color, opt_rect)
            text_surf, _ = self.font.render(option, theme.text_primary)
            surface.blit(text_surf, (opt_rect.x + 8, opt_rect.y + (option_height - text_surf.get_height()) // 2))
