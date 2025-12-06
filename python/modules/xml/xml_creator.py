"""XML Creator Module - Generate texture atlases."""
from __future__ import annotations

import xml.etree.ElementTree as ET

import pygame
import pygame.freetype

from modules.ui.widgets import TextInput
from modules.utils.data_loader import ensure_export_dir


class XMLCreator:
    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = project_root
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)

        self.inputs = {
            "atlas": TextInput(pygame.Rect(0, 0, 200, 30), self.font, placeholder="Atlas name", text="new_atlas"),
            "image": TextInput(pygame.Rect(0, 0, 240, 30), self.font, placeholder="image path", text="textures/atlas.png"),
            "frame": TextInput(pygame.Rect(0, 0, 200, 30), self.font, placeholder="frame name"),
            "x": TextInput(pygame.Rect(0, 0, 80, 30), self.font, placeholder="x", text="0"),
            "y": TextInput(pygame.Rect(0, 0, 80, 30), self.font, placeholder="y", text="0"),
            "w": TextInput(pygame.Rect(0, 0, 80, 30), self.font, placeholder="width", text="64"),
            "h": TextInput(pygame.Rect(0, 0, 80, 30), self.font, placeholder="height", text="64"),
        }
        self.frames = []
        self.status_message = ""
        self.status_timer = 0.0
        self._add_button = pygame.Rect(0, 0, 0, 0)
        self._export_button = pygame.Rect(0, 0, 0, 0)

    def handle_event(self, event):
        for input_field in self.inputs.values():
            input_field.handle_event(event)

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            pos = event.pos
            if self._add_button.collidepoint(pos):
                self._add_frame()
            elif self._export_button.collidepoint(pos):
                self._export_xml()
            else:
                for idx, rect in enumerate(self._frame_rows()):
                    delete_rect = pygame.Rect(rect.right - 24, rect.y + 6, 18, 18)
                    if delete_rect.collidepoint(pos):
                        self.frames.pop(idx)
                        break

    def update(self, dt):
        for input_field in self.inputs.values():
            input_field.update(dt)
        if self.status_timer > 0:
            self.status_timer -= dt
        else:
            self.status_message = ""

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        title_surf, _ = self.title_font.render("XML Creator", self.theme.text_primary)
        surface.blit(title_surf, (20, 20))

        instructions = "Fill the inputs, add frames, then export to XML."
        inst_surf, _ = self.font.render(instructions, self.theme.text_secondary)
        surface.blit(inst_surf, (20, 60))

        self._draw_inputs(surface)
        self._draw_frame_list(surface)
        self._draw_status(surface)

    def _draw_inputs(self, surface):
        panel = pygame.Rect(20, 120, self.rect.width - 40, 180)
        pygame.draw.rect(surface, self.theme.bg_medium, panel, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel, 1, border_radius=8)

        atlas_rect = pygame.Rect(panel.x + 20, panel.y + 30, 220, 32)
        image_rect = pygame.Rect(panel.x + 260, panel.y + 30, 260, 32)
        frame_rect = pygame.Rect(panel.x + 20, panel.y + 90, 220, 32)
        x_rect = pygame.Rect(panel.x + 260, panel.y + 90, 80, 32)
        y_rect = pygame.Rect(panel.x + 350, panel.y + 90, 80, 32)
        w_rect = pygame.Rect(panel.x + 440, panel.y + 90, 80, 32)
        h_rect = pygame.Rect(panel.x + 530, panel.y + 90, 80, 32)

        self.inputs["atlas"].rect = atlas_rect
        self.inputs["image"].rect = image_rect
        self.inputs["frame"].rect = frame_rect
        self.inputs["x"].rect = x_rect
        self.inputs["y"].rect = y_rect
        self.inputs["w"].rect = w_rect
        self.inputs["h"].rect = h_rect

        for field in self.inputs.values():
            field.draw(surface, self.theme)

        self._add_button = pygame.Rect(panel.right - 420, panel.y + 140, 180, 36)
        pygame.draw.rect(surface, self.theme.accent_blue, self._add_button, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, self._add_button, 1, border_radius=6)
        add_surf, _ = self.font.render("Add frame", self.theme.text_primary)
        surface.blit(add_surf, (self._add_button.x + 12, self._add_button.y + 8))

        self._export_button = pygame.Rect(panel.right - 220, panel.y + 140, 180, 36)
        pygame.draw.rect(surface, self.theme.accent_green, self._export_button, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, self._export_button, 1, border_radius=6)
        export_surf, _ = self.font.render("Export XML", self.theme.text_primary)
        surface.blit(export_surf, (self._export_button.x + 16, self._export_button.y + 8))

    def _draw_frame_list(self, surface):
        panel = pygame.Rect(20, 320, self.rect.width - 40, self.rect.height - 360)
        pygame.draw.rect(surface, self.theme.bg_medium, panel, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel, 1, border_radius=8)

        header = "Frames"
        header_surf, _ = self.font.render(header, self.theme.text_primary)
        surface.blit(header_surf, (panel.x + 16, panel.y + 16))

        y = panel.y + 50
        for idx, frame in enumerate(self.frames):
            row = pygame.Rect(panel.x + 16, y, panel.width - 32, 40)
            pygame.draw.rect(surface, self.theme.bg_light, row, border_radius=6)
            pygame.draw.rect(surface, self.theme.border, row, 1, border_radius=6)

            label = f"{idx + 1}. {frame['name']}  ({frame['x']}, {frame['y']}, {frame['width']}x{frame['height']})"
            label_surf, _ = self.small_font.render(label, self.theme.text_primary)
            surface.blit(label_surf, (row.x + 10, row.y + 10))

            delete_rect = pygame.Rect(row.right - 30, row.y + 6, 20, 20)
            pygame.draw.rect(surface, self.theme.bg_dark, delete_rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.accent_yellow, delete_rect, 1, border_radius=4)
            delete_surf, _ = self.small_font.render("×", self.theme.accent_yellow)
            surface.blit(delete_surf, (delete_rect.x + 5, delete_rect.y + 2))

            y += 48

    def _draw_status(self, surface):
        if not self.status_message:
            return
        surf, _ = self.font.render(self.status_message, self.theme.accent_green)
        surface.blit(surf, (20, self.rect.height - 30))

    def _add_frame(self):
        name = self.inputs["frame"].get_value()
        if not name:
            self._set_status("Frame name required", error=True)
            return
        try:
            x = int(float(self.inputs["x"].get_value() or 0))
            y = int(float(self.inputs["y"].get_value() or 0))
            w = int(float(self.inputs["w"].get_value() or 0))
            h = int(float(self.inputs["h"].get_value() or 0))
        except ValueError:
            self._set_status("Numeric values required for x,y,width,height", error=True)
            return
        self.frames.append({"name": name, "x": x, "y": y, "width": w, "height": h})
        self.inputs["frame"].text = ""
        self._set_status(f"Added frame '{name}'")

    def _export_xml(self):
        if not self.frames:
            self._set_status("Add at least one frame", error=True)
            return
        atlas = self.inputs["atlas"].get_value() or "atlas"
        image_path = self.inputs["image"].get_value() or "atlas.png"
        root = ET.Element("TextureAtlas", attrib={"imagePath": image_path})
        for frame in self.frames:
            ET.SubElement(
                root,
                "SubTexture",
                attrib={
                    "name": frame["name"],
                    "x": str(frame["x"]),
                    "y": str(frame["y"]),
                    "width": str(frame["width"]),
                    "height": str(frame["height"]),
                },
            )
        export_dir = ensure_export_dir(self.project_root, "xml")
        path = export_dir / f"{atlas}.xml"
        tree = ET.ElementTree(root)
        tree.write(path, encoding="utf-8", xml_declaration=True)
        self._set_status(f"Exported {len(self.frames)} frames to {path.relative_to(self.project_root)}")

    def _set_status(self, message, error=False):
        self.status_message = message
        self.status_timer = 3.0
        if error:
            self.status_message = f"WARN: {message}"

    def _frame_rows(self):
        panel = pygame.Rect(20, 320, self.rect.width - 40, self.rect.height - 360)
        rows = []
        y = panel.y + 50
        for _ in self.frames:
            rows.append(pygame.Rect(panel.x + 16, y, panel.width - 32, 40))
            y += 48
        return rows

    def cleanup(self):
        pass
