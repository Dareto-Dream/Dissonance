#!/usr/bin/env python3
"""
Dissonance Visual Novel Editor - Main Entry Point

A comprehensive modular editor for creating visual novel content.
Features:
- Story editor with node graph visualization
- Pose editor for character composition
- XML atlas viewer and creator
- Text effect previewer
- Condition builder
- Scene placement tool
"""

import sys
import os
from pathlib import Path

import pygame
import pygame.freetype

# Add modules directory to path
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))

from modules.ui.sidebar import Sidebar
from modules.ui.theme import Theme
from modules.story.story_editor import StoryEditor
from modules.pose.pose_editor import PoseEditorModule
from modules.xml.xml_viewer import XMLViewer
from modules.xml.xml_creator import XMLCreator
from modules.effects.text_effects import TextEffectPreview
from modules.placement.scene_placement import ScenePlacement
from modules.conditions.condition_editor import ConditionEditor


class DissonanceEditor:
    """Main editor application with module switching."""
    
    def __init__(self):
        pygame.init()
        pygame.freetype.init()
        
        # Window setup
        self.screen_width = 1600
        self.screen_height = 900
        self.screen = pygame.display.set_mode((self.screen_width, self.screen_height))
        pygame.display.set_caption("Dissonance VN Editor")
        
        self.clock = pygame.time.Clock()
        self.running = True
        
        # Fullscreen state + windowed size restore cache
        self.fullscreen = False
        self.windowed_size = (self.screen_width, self.screen_height)
        
        # Initialize theme
        self.theme = Theme()
        
        # Sidebar setup
        self.sidebar = Sidebar(self.theme)
        self.windowed_size = (self.screen_width, self.screen_height)
        self.sidebar_width = 200
        self.help_visible = False
        self.help_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.help_small_font = pygame.freetype.SysFont("Arial", 16)
        self.help_scroll = 0
        self.help_content_height = 0
        self.help_view_height = 0
        
        # Available modules
        self.modules = {
            "Story Editor": None,
            "Pose Editor": None,
            "XML Viewer": None,
            "XML Creator": None,
            "Text Effects": None,
            "Scene Placement": None,
            "Condition Editor": None
        }
        
        self.current_module = None
        self.active_module_name = None
        
        # Project root detection
        self.project_root = self.find_project_root()
        
    def find_project_root(self):
        """Try to find the project root with assets folder."""
        here = Path(os.getcwd())
        if (here / "assets").exists():
            return here
        if (here.parent / "assets").exists():
            return here.parent
        if (here.parent.parent / "assets").exists():
            return here.parent.parent
        return here
    
    def switch_module(self, module_name: str):
        """Switch to a different editor module."""
        if module_name == self.active_module_name:
            return
        
        # Clean up current module
        if self.current_module:
            if hasattr(self.current_module, 'cleanup'):
                self.current_module.cleanup()
        
        # Create workspace rect (excluding sidebar)
        workspace_rect = pygame.Rect(
            self.sidebar_width,
            0,
            self.screen_width - self.sidebar_width,
            self.screen_height
        )
        
        # Initialize new module
        if module_name == "Story Editor":
            self.current_module = StoryEditor(
                workspace_rect,
                self.theme,
                self.project_root
            )
        elif module_name == "Pose Editor":
            self.current_module = PoseEditorModule(
                workspace_rect,
                self.theme,
                self.project_root
            )
        elif module_name == "XML Viewer":
            self.current_module = XMLViewer(
                workspace_rect,
                self.theme,
                self.project_root
            )
        elif module_name == "XML Creator":
            self.current_module = XMLCreator(
                workspace_rect,
                self.theme,
                self.project_root
            )
        elif module_name == "Text Effects":
            self.current_module = TextEffectPreview(
                workspace_rect,
                self.theme,
                self.project_root
            )
        elif module_name == "Scene Placement":
            self.current_module = ScenePlacement(
                workspace_rect,
                self.theme,
                self.project_root
            )
        elif module_name == "Condition Editor":
            self.current_module = ConditionEditor(
                workspace_rect,
                self.theme,
                self.project_root
            )
        
        self.active_module_name = module_name
        print(f"Switched to: {module_name}")
    
    def handle_events(self):
        """Handle global events."""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
                return
            
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_h and (event.mod & pygame.KMOD_CTRL):
                    self.help_visible = not self.help_visible
                    if self.help_visible:
                        self.help_scroll = 0
                    continue
                if event.key == pygame.K_ESCAPE and self.help_visible:
                    self.help_visible = False
                    self.help_scroll = 0
                    continue
                if event.key == pygame.K_f and (event.mod & pygame.KMOD_CTRL):
                    self.toggle_fullscreen()
                    continue

                if event.key == pygame.K_F11:
                    self.toggle_fullscreen()
                    continue
            
            if self.help_visible:
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_PAGEUP:
                        self._scroll_help(-self.help_view_height // 2 if self.help_view_height else -120)
                        continue
                    if event.key == pygame.K_PAGEDOWN:
                        self._scroll_help(self.help_view_height // 2 if self.help_view_height else 120)
                        continue
                    # Allow help toggle keys only while visible
                    continue
                if event.type == pygame.MOUSEWHEEL:
                    self._scroll_help(-event.y * 30)
                    continue
                continue
            
            sidebar_consumed = False
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                if hasattr(event, "pos") and event.pos[0] < self.sidebar_width:
                    module_name = self.sidebar.handle_click(event.pos, list(self.modules.keys()))
                    if module_name:
                        self.switch_module(module_name)
                    sidebar_consumed = True
            if sidebar_consumed:
                continue
            
            workspace_event = self._translate_event_for_workspace(event)
            if workspace_event is None:
                continue
            
            if self.current_module:
                self.current_module.handle_event(workspace_event)
    
    def update(self, dt):
        """Update active module."""
        if self.current_module:
            self.current_module.update(dt)

    def toggle_fullscreen(self):
        self.fullscreen = not self.fullscreen

        if self.fullscreen:
            # Store current windowed size before switching
            self.windowed_size = (self.screen_width, self.screen_height)

            self.screen = pygame.display.set_mode(
                (0, 0),
                pygame.FULLSCREEN | pygame.HWSURFACE | pygame.DOUBLEBUF
            )
        else:
            # Restore the previous windowed size
            self.screen = pygame.display.set_mode(
                self.windowed_size
            )

        # Update width/height so modules get correct sizing
        self.screen_width, self.screen_height = self.screen.get_size()

        # Notify module of resize if needed
        if self.current_module and hasattr(self.current_module, "on_resize"):
            self.current_module.on_resize(
                pygame.Rect(
                    self.sidebar_width,
                    0,
                    self.screen_width - self.sidebar_width,
                    self.screen_height
                )
            )

    
    def draw(self):
        """Render sidebar and active module."""
        self.screen.fill(self.theme.bg_dark)
        
        # Draw sidebar
        sidebar_rect = pygame.Rect(0, 0, self.sidebar_width, self.screen_height)
        self.sidebar.draw(
            self.screen,
            sidebar_rect,
            list(self.modules.keys()),
            self.active_module_name
        )
        
        # Draw vertical separator
        pygame.draw.line(
            self.screen,
            self.theme.border,
            (self.sidebar_width, 0),
            (self.sidebar_width, self.screen_height),
            2
        )
        
        # Draw active module
        if self.current_module:
            workspace_surface = self.screen.subsurface(
                self.sidebar_width,
                0,
                self.screen_width - self.sidebar_width,
                self.screen_height
            )
            self.current_module.draw(workspace_surface)
        else:
            # Welcome screen
            self.draw_welcome()
        
        if self.help_visible:
            self.draw_help_overlay()
        
        pygame.display.flip()
    
    def draw_welcome(self):
        """Draw welcome screen when no module is active."""
        font = pygame.freetype.SysFont("Arial", 36)
        small_font = pygame.freetype.SysFont("Arial", 18)
        
        center_x = self.sidebar_width + (self.screen_width - self.sidebar_width) // 2
        center_y = self.screen_height // 2
        
        # Title
        title_surf, title_rect = font.render(
            "Dissonance Visual Novel Editor",
            self.theme.text_primary
        )
        title_rect.center = (center_x, center_y - 60)
        self.screen.blit(title_surf, title_rect)
        
        # Instructions
        instructions = [
            "Select a module from the sidebar to begin",
            "",
            "Available modules:",
            "- Story Editor - Create and edit scene graphs",
            "- Pose Editor - Compose character poses",
            "- XML Viewer - Browse atlas textures",
            "- XML Creator - Generate texture atlases",
            "- Text Effects - Preview text animations",
            "- Scene Placement - Position characters and backgrounds",
            "- Condition Editor - Build conditional logic"
        ]
        
        y = center_y - 10
        for line in instructions:
            if line:
                text_surf, text_rect = small_font.render(line, self.theme.text_secondary)
                text_rect.center = (center_x, y)
                self.screen.blit(text_surf, text_rect)
            y += 25
    
    def _translate_event_for_workspace(self, event):
        """Shift mouse events so workspace modules receive coordinates relative to their surface."""
        if hasattr(event, "pos"):
            x, y = event.pos
            if x < self.sidebar_width:
                return None
            event_data = getattr(event, "dict", {}).copy()
            event_data["pos"] = (x - self.sidebar_width, y)
            return pygame.event.Event(event.type, event_data)
        return event
    
    def draw_help_overlay(self):
        """Draw translucent help overlay."""
        overlay = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
        overlay.fill(self.theme.overlay_dark)
        self.screen.blit(overlay, (0, 0))
        
        panel_width = self.screen_width - 240
        panel_height = self.screen_height - 200
        panel_x = 120
        panel_y = 100
        
        panel_rect = pygame.Rect(panel_x, panel_y, panel_width, panel_height)
        pygame.draw.rect(self.screen, self.theme.bg_medium, panel_rect, border_radius=12)
        pygame.draw.rect(self.screen, self.theme.border, panel_rect, 2, border_radius=12)
        
        title = "Dissonance Editor Help"
        if self.active_module_name:
            title = f"{title} – {self.active_module_name}"
        title_surf, title_rect = self.help_font.render(title, self.theme.text_primary)
        title_rect.midtop = (self.screen_width // 2, panel_y + 20)
        self.screen.blit(title_surf, title_rect)
        
        info_text = "Press Ctrl + H to close this help. ESC also closes."
        info_surf, _ = self.help_small_font.render(info_text, self.theme.text_secondary)
        self.screen.blit(info_surf, (panel_x + 20, panel_y + 70))
        
        # Always show global controls first
        sections = [
            (
                "Global Controls",
                [
                    "Ctrl+H - Toggle help",
                    "Esc - Close help",
                    "Sidebar click - Switch modules",
                    "Ctrl+S - Module-specific save/export",
                ],
            )
        ]

        # Then use ONLY the current module’s help
        if self.current_module and hasattr(self.current_module, "get_help_entries"):
            module_sections = self.current_module.get_help_entries()
            if module_sections:
                sections.extend(module_sections)
            else:
                # If module has no help, show fallback
                sections.append((
                    "Module Help",
                    ["This module does not provide additional help information."]
                ))
        else:
            # If nothing loaded
            sections.append((
                "Module Help",
                ["No module is currently active."]
            ))
        
        content_width = panel_width - 60
        content_height = 0
        for heading, bullets in sections:
            content_height += 28
            content_height += len(bullets) * 24
            content_height += 16
        content_height = max(content_height, 10)
        content_surface = pygame.Surface((content_width, content_height), pygame.SRCALPHA)
        
        y = 0
        for heading, bullets in sections:
            heading_surf, _ = self.help_small_font.render(heading, self.theme.accent_blue)
            content_surface.blit(heading_surf, (0, y))
            y += 28
            for bullet in bullets:
                bullet_text = f"- {bullet}"
                bullet_surf, _ = self.help_small_font.render(bullet_text, self.theme.text_primary)
                content_surface.blit(bullet_surf, (20, y))
                y += 24
            y += 16
        
        content_top = panel_y + 110
        view_height = panel_height - 150
        view_height = max(60, view_height)
        self.help_content_height = content_height
        self.help_view_height = view_height
        self._scroll_help(0)  # clamp to bounds
        viewport = pygame.Rect(0, self.help_scroll, content_width, min(view_height, content_height))
        self.screen.blit(content_surface, (panel_x + 30, content_top), area=viewport)
        
        if content_height > view_height:
            max_scroll = content_height - view_height
            bar_height = max(20, int(view_height * (view_height / content_height)))
            bar_y = content_top + int((self.help_scroll / max_scroll) * (view_height - bar_height))
            scrollbar_rect = pygame.Rect(panel_x + panel_width - 20, bar_y, 8, bar_height)
            pygame.draw.rect(self.screen, self.theme.accent_blue, scrollbar_rect, border_radius=4)

    def _scroll_help(self, delta):
        max_scroll = max(0, self.help_content_height - self.help_view_height)
        self.help_scroll = max(0, min(self.help_scroll + delta, max_scroll))
    
    def run(self):
        """Main application loop."""
        print("=" * 60)
        print("Dissonance Visual Novel Editor")
        print("=" * 60)
        print(f"Project root: {self.project_root}")
        print()
        
        while self.running:
            dt = self.clock.tick(60) / 1000.0
            
            self.handle_events()
            self.update(dt)
            self.draw()
        
        # Cleanup
        if self.current_module and hasattr(self.current_module, 'cleanup'):
            self.current_module.cleanup()
        
        pygame.quit()
        print("\nEditor closed.")


def main():
    try:
        editor = DissonanceEditor()
        editor.run()
    except Exception as e:
        print(f"\nFatal error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
