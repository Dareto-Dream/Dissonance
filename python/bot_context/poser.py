#!/usr/bin/env python3
"""
pose_editor.py - Enhanced Version

Pygame-based pose editor for Dissonance characters with improved UX.

Features:
- Interactive character selection from characters.json
- Mouse and keyboard controls
- Browse and switch between poses
- Copy/paste layers with Ctrl+C/V
- Undo/redo with Ctrl+Z/Ctrl+Y
- Layer reordering with [/]
- Grid overlay toggle with G
- Zoom with +/- or mouse wheel
- Help overlay toggle with H or F1
- Auto-save with visual feedback
- Unsaved changes indicator

Usage:
    python pose_editor.py
"""

import sys
import os
import json
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional, List, Dict, Tuple
from copy import deepcopy

import pygame


# --------------------------------------------------------------------
# Path resolution
# --------------------------------------------------------------------

def find_project_root():
    """Try current dir first, then parent, to locate 'assets' folder."""
    here = Path(__file__).resolve().parent
    if (here / "assets").exists():
        return here
    if (here.parent / "assets").exists():
        return here.parent
    # Fallback: assume current working directory is project root
    cwd = Path(os.getcwd())
    if (cwd / "assets").exists():
        return cwd
    return here


PROJECT_ROOT = find_project_root()
ASSETS_DIR = PROJECT_ROOT / "assets"
IMAGES_DIR = ASSETS_DIR / "images" / "characters"
DATA_DIR = ASSETS_DIR / "data" / "characters"


# --------------------------------------------------------------------
# Atlas loading
# --------------------------------------------------------------------

class Atlas:
    def __init__(self, image_surface, frames):
        self.image = image_surface
        self.frames = frames  # name -> (x, y, w, h, rotated)

    @classmethod
    def from_xml(cls, character_id: str):
        char_dir = IMAGES_DIR / character_id
        xml_path = char_dir / f"{character_id}.xml"
        if not xml_path.exists():
            raise FileNotFoundError(f"XML not found: {xml_path}")

        tree = ET.parse(str(xml_path))
        root = tree.getroot()

        image_path = root.attrib.get("imagePath", f"{character_id}.png")
        png_path = char_dir / image_path
        if not png_path.exists():
            raise FileNotFoundError(f"PNG atlas not found: {png_path}")

        image_surface = pygame.image.load(str(png_path)).convert_alpha()

        frames = {}
        for sub in root.findall("SubTexture"):
            name = sub.attrib["name"]
            x = int(sub.attrib["x"])
            y = int(sub.attrib["y"])
            w = int(sub.attrib["width"])
            h = int(sub.attrib["height"])
            rotated = sub.attrib.get("rotated", "false").lower() == "true"
            frames[name] = (x, y, w, h, rotated)

        return cls(image_surface, frames)

    def list_frame_names(self):
        return sorted(self.frames.keys())

    def get_surface(self, name):
        x, y, w, h, rotated = self.frames[name]
        rect = pygame.Rect(x, y, w, h)
        sub = self.image.subsurface(rect).copy()
        if rotated:
            # Sparrow's rotated="true" usually means 90-degree rotation
            sub = pygame.transform.rotate(sub, -90)
        return sub


# --------------------------------------------------------------------
# Pose data handling
# --------------------------------------------------------------------

def load_poses(character_id: str):
    """Load poses.json for this character, or create a default structure."""
    char_data_dir = DATA_DIR / character_id
    char_data_dir.mkdir(parents=True, exist_ok=True)
    poses_path = char_data_dir / "poses.json"

    if not poses_path.exists():
        return {
            "character": character_id,
            "config": {
                "scale": 1.0,
                "base_offset": {"x": 0, "y": 0}
            },
            "poses": {}
        }

    with poses_path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_poses(character_id: str, data: dict):
    char_data_dir = DATA_DIR / character_id
    char_data_dir.mkdir(parents=True, exist_ok=True)
    poses_path = char_data_dir / "poses.json"
    with poses_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def load_character_list():
    """Load list of available characters from characters.json."""
    chars_path = DATA_DIR / "characters.json"
    
    if not chars_path.exists():
        print(f"Warning: {chars_path} not found")
        return {}
    
    try:
        with chars_path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading characters.json: {e}")
        return {}


# --------------------------------------------------------------------
# Text Input Dialog
# --------------------------------------------------------------------

class TextInputDialog:
    """Simple text input dialog."""
    
    def __init__(self, screen, title: str, initial_text: str = "", prompt: str = ""):
        self.screen = screen
        self.title = title
        self.prompt = prompt
        self.text = initial_text
        self.cursor_pos = len(initial_text)
        self.cursor_visible = True
        self.cursor_timer = 0
        
        self.font = pygame.font.SysFont("consolas", 20)
        self.title_font = pygame.font.SysFont("consolas", 24, bold=True)
        
        self.active = True
        self.result = None
    
    def run(self) -> Optional[str]:
        """Run the dialog and return the entered text, or None if cancelled."""
        clock = pygame.time.Clock()
        
        while self.active:
            dt = clock.tick(60)
            self.cursor_timer += dt
            
            if self.cursor_timer >= 500:
                self.cursor_visible = not self.cursor_visible
                self.cursor_timer = 0
            
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.active = False
                    return None
                elif event.type == pygame.KEYDOWN:
                    self.handle_keydown(event.key, event.unicode, pygame.key.get_mods())
            
            self.draw()
            pygame.display.flip()
        
        return self.result
    
    def handle_keydown(self, key, unicode, mods):
        if key == pygame.K_ESCAPE:
            self.active = False
            self.result = None
        elif key == pygame.K_RETURN:
            self.active = False
            self.result = self.text.strip()
        elif key == pygame.K_BACKSPACE:
            if self.cursor_pos > 0:
                self.text = self.text[:self.cursor_pos-1] + self.text[self.cursor_pos:]
                self.cursor_pos -= 1
        elif key == pygame.K_DELETE:
            if self.cursor_pos < len(self.text):
                self.text = self.text[:self.cursor_pos] + self.text[self.cursor_pos+1:]
        elif key == pygame.K_LEFT:
            self.cursor_pos = max(0, self.cursor_pos - 1)
        elif key == pygame.K_RIGHT:
            self.cursor_pos = min(len(self.text), self.cursor_pos + 1)
        elif key == pygame.K_HOME:
            self.cursor_pos = 0
        elif key == pygame.K_END:
            self.cursor_pos = len(self.text)
        elif unicode and unicode.isprintable() and len(self.text) < 50:
            self.text = self.text[:self.cursor_pos] + unicode + self.text[self.cursor_pos:]
            self.cursor_pos += 1
    
    def draw(self):
        # Darken background
        overlay = pygame.Surface(self.screen.get_size())
        overlay.set_alpha(180)
        overlay.fill((0, 0, 0))
        self.screen.blit(overlay, (0, 0))
        
        # Dialog box
        box_w = 500
        box_h = 200
        box_x = (self.screen.get_width() - box_w) // 2
        box_y = (self.screen.get_height() - box_h) // 2
        
        pygame.draw.rect(self.screen, (40, 40, 50), (box_x, box_y, box_w, box_h), border_radius=8)
        pygame.draw.rect(self.screen, (100, 100, 120), (box_x, box_y, box_w, box_h), 3, border_radius=8)
        
        # Title
        title_surf = self.title_font.render(self.title, True, (220, 220, 255))
        self.screen.blit(title_surf, (box_x + 20, box_y + 20))
        
        # Prompt
        if self.prompt:
            prompt_surf = self.font.render(self.prompt, True, (180, 180, 200))
            self.screen.blit(prompt_surf, (box_x + 20, box_y + 60))
        
        # Input box
        input_y = box_y + 95 if self.prompt else box_y + 70
        input_box = pygame.Rect(box_x + 20, input_y, box_w - 40, 40)
        pygame.draw.rect(self.screen, (30, 30, 35), input_box, border_radius=4)
        pygame.draw.rect(self.screen, (80, 80, 100), input_box, 2, border_radius=4)
        
        # Text
        text_surf = self.font.render(self.text, True, (220, 220, 220))
        self.screen.blit(text_surf, (input_box.x + 10, input_box.y + 8))
        
        # Cursor
        if self.cursor_visible:
            cursor_x = input_box.x + 10 + self.font.size(self.text[:self.cursor_pos])[0]
            pygame.draw.line(self.screen, (220, 220, 220), 
                           (cursor_x, input_box.y + 8), 
                           (cursor_x, input_box.y + 32), 2)
        
        # Instructions
        instr_y = input_y + 50
        instr = self.font.render("Enter to confirm | ESC to cancel", True, (150, 150, 160))
        instr_x = box_x + (box_w - instr.get_width()) // 2
        self.screen.blit(instr, (instr_x, instr_y))


# --------------------------------------------------------------------
# Character Launcher
# --------------------------------------------------------------------

class CharacterLauncher:
    """Interactive character selection screen."""
    
    def __init__(self):
        pygame.init()
        
        self.screen_width = 800
        self.screen_height = 600
        self.screen = pygame.display.set_mode((self.screen_width, self.screen_height))
        pygame.display.set_caption("Pose Editor - Select Character")
        
        self.font = pygame.font.SysFont("consolas", 20)
        self.title_font = pygame.font.SysFont("consolas", 32, bold=True)
        self.small_font = pygame.font.SysFont("consolas", 16)
        
        self.characters = load_character_list()
        self.char_list = sorted(self.characters.keys())
        
        if not self.char_list:
            print("No characters found in characters.json!")
            sys.exit(1)
        
        self.selected_index = 0
        self.scroll = 0
        
    def run(self) -> Optional[str]:
        """Run launcher and return selected character ID, or None if cancelled."""
        clock = pygame.time.Clock()
        running = True
        
        while running:
            clock.tick(60)
            
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return None
                elif event.type == pygame.KEYDOWN:
                    result = self.handle_keydown(event.key)
                    if result is not None:
                        return result
                elif event.type == pygame.MOUSEBUTTONDOWN:
                    result = self.handle_mouse_click(event.pos)
                    if result is not None:
                        return result
                elif event.type == pygame.MOUSEWHEEL:
                    self.scroll = max(0, self.scroll - event.y * 2)
            
            self.draw()
            pygame.display.flip()
        
        return None
    
    def handle_keydown(self, key) -> Optional[str]:
        if key == pygame.K_ESCAPE:
            return None
        elif key == pygame.K_UP:
            self.selected_index = max(0, self.selected_index - 1)
            self.ensure_visible()
        elif key == pygame.K_DOWN:
            self.selected_index = min(len(self.char_list) - 1, self.selected_index + 1)
            self.ensure_visible()
        elif key in (pygame.K_RETURN, pygame.K_SPACE):
            return self.char_list[self.selected_index]
        
        return "continue"
    
    def handle_mouse_click(self, pos) -> Optional[str]:
        mx, my = pos
        
        start_y = 150
        row_height = 60
        list_area_x = 100
        list_area_width = 600
        
        visible_rows = (self.screen_height - start_y - 50) // row_height
        
        for i in range(visible_rows):
            idx = self.scroll + i
            if idx >= len(self.char_list):
                break
            
            y = start_y + i * row_height
            
            if (list_area_x <= mx <= list_area_x + list_area_width and
                y <= my <= y + row_height - 5):
                return self.char_list[idx]
        
        return "continue"
    
    def ensure_visible(self):
        visible_rows = (self.screen_height - 150 - 50) // 60
        if self.selected_index < self.scroll:
            self.scroll = self.selected_index
        elif self.selected_index >= self.scroll + visible_rows:
            self.scroll = self.selected_index - visible_rows + 1
    
    def draw(self):
        self.screen.fill((20, 20, 25))
        
        # Title
        title = self.title_font.render("Select Character", True, (220, 220, 255))
        title_x = (self.screen_width - title.get_width()) // 2
        self.screen.blit(title, (title_x, 40))
        
        # Instructions
        instr = self.small_font.render("Click or press Enter to select | ESC to quit", True, (150, 150, 160))
        instr_x = (self.screen_width - instr.get_width()) // 2
        self.screen.blit(instr, (instr_x, 90))
        
        # Character list
        start_y = 150
        row_height = 60
        list_area_x = 100
        list_area_width = 600
        
        visible_rows = (self.screen_height - start_y - 50) // row_height
        
        for i in range(visible_rows):
            idx = self.scroll + i
            if idx >= len(self.char_list):
                break
            
            char_id = self.char_list[idx]
            char_data = self.characters[char_id]
            y = start_y + i * row_height
            
            # Background
            if idx == self.selected_index:
                pygame.draw.rect(self.screen, (60, 60, 100), 
                               (list_area_x, y, list_area_width, row_height - 5), 
                               border_radius=5)
            else:
                pygame.draw.rect(self.screen, (35, 35, 45), 
                               (list_area_x, y, list_area_width, row_height - 5), 
                               border_radius=5)
            
            # Border on hover
            pygame.draw.rect(self.screen, (80, 80, 120), 
                           (list_area_x, y, list_area_width, row_height - 5), 
                           2, border_radius=5)
            
            # Character name
            name_surf = self.font.render(char_id.capitalize(), True, (220, 220, 220))
            self.screen.blit(name_surf, (list_area_x + 20, y + 10))
            
            # Default pose info
            default_pose = char_data.get("defaultPose", "none")
            pose_surf = self.small_font.render(f"Default: {default_pose}", True, (150, 150, 160))
            self.screen.blit(pose_surf, (list_area_x + 20, y + 35))
        
        # Scrollbar if needed
        if len(self.char_list) > visible_rows:
            bar_h = self.screen_height - start_y - 50
            thumb_h = max(20, int(bar_h * visible_rows / len(self.char_list)))
            thumb_y = start_y + int((self.scroll / len(self.char_list)) * bar_h)
            
            pygame.draw.rect(self.screen, (60, 60, 70), 
                           (list_area_x + list_area_width + 10, start_y, 8, bar_h))
            pygame.draw.rect(self.screen, (120, 120, 140), 
                           (list_area_x + list_area_width + 10, thumb_y, 8, thumb_h), 
                           border_radius=4)


# --------------------------------------------------------------------
# History/Undo system
# --------------------------------------------------------------------

class History:
    def __init__(self, max_size=50):
        self.states = []
        self.current = -1
        self.max_size = max_size
    
    def push(self, state):
        # Remove any states after current
        self.states = self.states[:self.current + 1]
        
        # Add new state
        self.states.append(deepcopy(state))
        self.current += 1
        
        # Trim if too large
        if len(self.states) > self.max_size:
            self.states.pop(0)
            self.current -= 1
    
    def undo(self):
        if self.current > 0:
            self.current -= 1
            return deepcopy(self.states[self.current])
        return None
    
    def redo(self):
        if self.current < len(self.states) - 1:
            self.current += 1
            return deepcopy(self.states[self.current])
        return None
    
    def can_undo(self):
        return self.current > 0
    
    def can_redo(self):
        return self.current < len(self.states) - 1


# --------------------------------------------------------------------
# Pygame pose editor
# --------------------------------------------------------------------

class PoseEditor:
    def __init__(self, character_id: str, pose_name: Optional[str] = None):
        self.character_id = character_id

        pygame.init()
        
        self.screen_width = 1600
        self.screen_height = 900
        self.fullscreen = False
        self.screen = pygame.display.set_mode((self.screen_width, self.screen_height))

        self.font = pygame.font.SysFont("consolas", 16)
        self.small_font = pygame.font.SysFont("consolas", 14)
        self.big_font = pygame.font.SysFont("consolas", 20, bold=True)
        self.tiny_font = pygame.font.SysFont("consolas", 12)

        self.atlas = Atlas.from_xml(character_id)
        self.frame_names = self.atlas.list_frame_names()

        self.frame_index = 0
        self.frame_scroll = 0

        self.layers = []
        self.layer_index = -1

        self.poses_data = load_poses(character_id)
        self.pose_list = sorted(self.poses_data.get("poses", {}).keys())
        
        # Initialize with provided pose or first available
        if pose_name:
            self.pose_name = pose_name
            if pose_name not in self.pose_list:
                self.pose_list.append(pose_name)
        elif self.pose_list:
            self.pose_name = self.pose_list[0]
        else:
            self.pose_name = "new_pose"
            self.pose_list.append(self.pose_name)
        
        self.pose_index = self.pose_list.index(self.pose_name)
        self.pose_scroll = 0
        
        self.load_current_pose()

        # Preview area center
        self.preview_cx = 1100
        self.preview_cy = 450
        
        # UI state
        self.active_panel = "frames"
        self.preview_scale = 1.0
        self.show_grid = True
        self.show_help = False
        self.show_layers_panel = True
        self.preview_mode = False  # Layer preview mode
        
        # Clipboard for copy/paste
        self.clipboard_layer = None
        
        # Undo/redo
        self.history = History()
        self.push_history()
        
        # Unsaved changes tracking
        self.unsaved_changes = False
        self.save_feedback_timer = 0
        
        # Search/filter
        self.frame_filter = ""
        self.filtered_frames = self.frame_names.copy()
        
        # Context menu state
        self.context_menu_pos = None
        self.context_menu_target = None  # "pose" or "frame"
        
        self.update_title()

    def update_title(self):
        unsaved = "*" if self.unsaved_changes else ""
        pygame.display.set_caption(
            f"Pose Editor - {self.character_id} / {self.pose_name}{unsaved}"
        )

    # -----------------------------
    # History management
    # -----------------------------

    def push_history(self):
        state = {
            "layers": deepcopy(self.layers),
            "layer_index": self.layer_index
        }
        self.history.push(state)

    def restore_state(self, state):
        if state:
            self.layers = deepcopy(state["layers"])
            self.layer_index = state["layer_index"]
            self.unsaved_changes = True
            self.update_title()

    # -----------------------------
    # Data loading / saving
    # -----------------------------

    def load_current_pose(self):
        """Load the currently selected pose."""
        pose = self.poses_data.get("poses", {}).get(self.pose_name)
        if pose is None:
            self.layers = []
            self.layer_index = -1
        else:
            self.layers = []
            for layer in pose.get("layers", []):
                self.layers.append({
                    "frame": layer["frame"],
                    "x": int(layer["x"]),
                    "y": int(layer["y"])
                })
            self.layer_index = 0 if self.layers else -1
        
        self.unsaved_changes = False
        self.history = History()
        self.push_history()
        self.update_title()

    def save_pose(self):
        pose_entry = {
            "layers": [
                {"frame": l["frame"], "x": int(l["x"]), "y": int(l["y"])}
                for l in self.layers
            ]
        }
        if "poses" not in self.poses_data:
            self.poses_data["poses"] = {}
        self.poses_data["poses"][self.pose_name] = pose_entry
        save_poses(self.character_id, self.poses_data)
        
        self.unsaved_changes = False
        self.save_feedback_timer = 60  # Show feedback for 1 second
        self.update_title()
        print(f"Saved pose '{self.pose_name}' for '{self.character_id}'")

    def switch_pose(self, new_index):
        """Switch to a different pose."""
        if 0 <= new_index < len(self.pose_list):
            if self.unsaved_changes:
                # Auto-save current pose before switching
                self.save_pose()
            
            self.pose_index = new_index
            self.pose_name = self.pose_list[self.pose_index]
            self.load_current_pose()

    def create_new_pose(self, name: str):
        """Create a new pose with the given name."""
        if name and name not in self.pose_list:
            self.pose_list.append(name)
            self.pose_list.sort()
            self.pose_index = self.pose_list.index(name)
            self.pose_name = name
            self.layers = []
            self.layer_index = -1
            self.unsaved_changes = True
            self.history = History()
            self.push_history()
            self.update_title()
            return True
        return False

    def rename_current_pose(self, new_name: str):
        """Rename the current pose."""
        if new_name and new_name != self.pose_name and new_name not in self.pose_list:
            # Remove old pose from data
            if self.pose_name in self.poses_data.get("poses", {}):
                del self.poses_data["poses"][self.pose_name]
            
            # Update list
            old_name = self.pose_name
            self.pose_list[self.pose_index] = new_name
            self.pose_list.sort()
            self.pose_name = new_name
            self.pose_index = self.pose_list.index(new_name)
            
            self.unsaved_changes = True
            self.save_pose()
            self.update_title()
            print(f"Renamed pose '{old_name}' to '{new_name}'")
            return True
        return False

    def delete_current_pose(self):
        """Delete the current pose."""
        if len(self.pose_list) <= 1:
            print("Cannot delete the last pose!")
            return False
        
        # Remove from data
        if self.pose_name in self.poses_data.get("poses", {}):
            del self.poses_data["poses"][self.pose_name]
        
        # Remove from list
        deleted_name = self.pose_name
        self.pose_list.pop(self.pose_index)
        
        # Move to adjacent pose
        self.pose_index = min(self.pose_index, len(self.pose_list) - 1)
        self.pose_name = self.pose_list[self.pose_index]
        
        # Save and reload
        save_poses(self.character_id, self.poses_data)
        self.load_current_pose()
        
        print(f"Deleted pose '{deleted_name}'")
        return True

    def toggle_fullscreen(self):
        """Toggle fullscreen mode."""
        self.fullscreen = not self.fullscreen
        
        if self.fullscreen:
            self.screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
            self.screen_width = self.screen.get_width()
            self.screen_height = self.screen.get_height()
        else:
            self.screen_width = 1600
            self.screen_height = 900
            self.screen = pygame.display.set_mode((self.screen_width, self.screen_height))
        
        # Recenter preview
        self.preview_cx = (self.screen_width - 350 - 250) // 2 + 350
        self.preview_cy = self.screen_height // 2

    def duplicate_current_pose(self):
        """Duplicate the current pose with a new name."""
        base_name = self.pose_name
        counter = 1
        new_name = f"{base_name}_copy"
        while new_name in self.pose_list:
            counter += 1
            new_name = f"{base_name}_copy{counter}"
        
        # Save current layers to the new pose
        self.create_new_pose(new_name)

    # -----------------------------
    # Event handling
    # -----------------------------

    def run(self):
        clock = pygame.time.Clock()
        running = True

        while running:
            dt = clock.tick(60)
            
            if self.save_feedback_timer > 0:
                self.save_feedback_timer -= 1

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    if self.unsaved_changes:
                        self.save_pose()
                    running = False
                elif event.type == pygame.KEYDOWN:
                    running = self.handle_keydown(event.key, pygame.key.get_mods())
                elif event.type == pygame.MOUSEWHEEL:
                    self.handle_mousewheel(event.y, pygame.key.get_mods())
                elif event.type == pygame.MOUSEBUTTONDOWN:
                    if event.button == 1:  # Left click
                        self.handle_mouse_click(event.pos)
                    elif event.button == 3:  # Right click
                        self.handle_right_click(event.pos)

            self.draw()
            pygame.display.flip()

        pygame.quit()

    def handle_mousewheel(self, y, mods):
        """Handle mouse wheel for zooming or scrolling."""
        if mods & pygame.KMOD_CTRL:
            # Zoom
            if y > 0:
                self.preview_scale = min(3.0, self.preview_scale + 0.1)
            else:
                self.preview_scale = max(0.3, self.preview_scale - 0.1)
        else:
            # Scroll active panel
            if self.active_panel == "frames":
                self.frame_scroll = max(0, self.frame_scroll - y * 3)
            elif self.active_panel == "poses":
                self.pose_scroll = max(0, self.pose_scroll - y * 3)

    def handle_mouse_click(self, pos):
        """Handle mouse clicks for selecting frames, poses, and layers."""
        mx, my = pos
        
        # Close context menu if clicking outside
        if self.context_menu_pos:
            if not self.is_click_in_context_menu(pos):
                self.context_menu_pos = None
                self.context_menu_target = None
            else:
                self.handle_context_menu_click(pos)
                return
        
        # Check frame list (left panel)
        panel_width = 350
        if mx < panel_width:
            self.active_panel = "frames"
            row_height = 22
            start_y = 50
            visible_rows = (self.screen_height - start_y - 10) // row_height
            
            for i in range(visible_rows):
                idx = self.frame_scroll + i
                if idx >= len(self.filtered_frames):
                    break
                y = start_y + i * row_height
                
                if start_y <= my <= self.screen_height and y <= my < y + row_height:
                    self.frame_index = idx
                    # Double-click to add layer
                    if pygame.time.get_ticks() - getattr(self, '_last_frame_click', 0) < 300:
                        self.add_layer_from_current_frame()
                    self._last_frame_click = pygame.time.get_ticks()
                    break
        
        # Check pose list (right panel)
        panel_x = self.screen_width - 250
        panel_width = 250
        if mx >= panel_x:
            self.active_panel = "poses"
            row_height = 30
            start_y = 50
            visible_rows = (self.screen_height - start_y - 10) // row_height
            
            for i in range(visible_rows):
                idx = self.pose_scroll + i
                if idx >= len(self.pose_list):
                    break
                y = start_y + i * row_height
                
                if start_y <= my <= self.screen_height and y <= my < y + row_height:
                    self.switch_pose(idx)
                    break

    def handle_right_click(self, pos):
        """Handle right-click for context menus."""
        mx, my = pos
        
        # Check if in pose list
        panel_x = self.screen_width - 250
        if mx >= panel_x:
            row_height = 30
            start_y = 50
            visible_rows = (self.screen_height - start_y - 10) // row_height
            
            for i in range(visible_rows):
                idx = self.pose_scroll + i
                if idx >= len(self.pose_list):
                    break
                y = start_y + i * row_height
                
                if start_y <= my <= self.screen_height and y <= my < y + row_height:
                    self.pose_index = idx
                    self.pose_name = self.pose_list[idx]
                    self.context_menu_pos = pos
                    self.context_menu_target = "pose"
                    break
    
    def is_click_in_context_menu(self, pos) -> bool:
        """Check if click is within context menu bounds."""
        if not self.context_menu_pos:
            return False
        
        mx, my = pos
        menu_x, menu_y = self.context_menu_pos
        menu_width = 180
        menu_height = 120  # 4 items * 30
        
        return (menu_x <= mx <= menu_x + menu_width and 
                menu_y <= my <= menu_y + menu_height)
    
    def handle_context_menu_click(self, pos):
        """Handle clicks on context menu items."""
        if not self.context_menu_pos:
            return
        
        mx, my = pos
        menu_x, menu_y = self.context_menu_pos
        item_height = 30
        
        relative_y = my - menu_y
        item_index = int(relative_y / item_height)
        
        if self.context_menu_target == "pose":
            if item_index == 0:  # New Pose
                dialog = TextInputDialog(self.screen, "New Pose", "", "Enter pose name:")
                new_name = dialog.run()
                if new_name:
                    self.create_new_pose(new_name)
            elif item_index == 1:  # Rename
                dialog = TextInputDialog(self.screen, "Rename Pose", self.pose_name, "Enter new name:")
                new_name = dialog.run()
                if new_name:
                    self.rename_current_pose(new_name)
            elif item_index == 2:  # Duplicate
                self.duplicate_current_pose()
            elif item_index == 3:  # Delete
                if len(self.pose_list) > 1:
                    self.delete_current_pose()
        
        self.context_menu_pos = None
        self.context_menu_target = None

    def handle_keydown(self, key, mods):
        mod_shift = mods & pygame.KMOD_SHIFT
        mod_ctrl = mods & pygame.KMOD_CTRL

        if key == pygame.K_ESCAPE:
            if self.unsaved_changes:
                self.save_pose()
            return False

        # Help toggle
        if key in (pygame.K_h, pygame.K_F1):
            self.show_help = not self.show_help

        # Grid toggle
        elif key == pygame.K_g and not mod_ctrl:
            self.show_grid = not self.show_grid

        # Fullscreen toggle
        elif key == pygame.K_F11 or (key == pygame.K_f and mod_ctrl):
            self.toggle_fullscreen()

        # Layer preview toggle
        elif key == pygame.K_p and not mod_ctrl:
            self.preview_mode = not self.preview_mode

        # Layers panel toggle
        elif key == pygame.K_l and not mod_ctrl:
            self.show_layers_panel = not self.show_layers_panel

        # Undo/Redo
        elif key == pygame.K_z and mod_ctrl:
            if mod_shift:
                self.restore_state(self.history.redo())
            else:
                self.restore_state(self.history.undo())

        # Redo (Ctrl+Y alternative)
        elif key == pygame.K_y and mod_ctrl:
            self.restore_state(self.history.redo())

        # Panel switching
        elif key == pygame.K_TAB and not mod_ctrl:
            if self.active_panel == "frames":
                self.active_panel = "poses"
            else:
                self.active_panel = "frames"

        # Frame list navigation
        elif key == pygame.K_UP:
            if self.active_panel == "frames":
                if self.frame_index > 0:
                    self.frame_index -= 1
                    self.ensure_frame_visible(-1)
            elif self.active_panel == "poses":
                if self.pose_index > 0:
                    self.switch_pose(self.pose_index - 1)

        elif key == pygame.K_DOWN:
            if self.active_panel == "frames":
                if self.frame_index < len(self.filtered_frames) - 1:
                    self.frame_index += 1
                    self.ensure_frame_visible(1)
            elif self.active_panel == "poses":
                if self.pose_index < len(self.pose_list) - 1:
                    self.switch_pose(self.pose_index + 1)

        elif key == pygame.K_PAGEUP:
            if self.active_panel == "frames":
                self.frame_index = max(0, self.frame_index - 10)
                self.ensure_frame_visible(-10)
            elif self.active_panel == "poses":
                self.switch_pose(max(0, self.pose_index - 5))

        elif key == pygame.K_PAGEDOWN:
            if self.active_panel == "frames":
                self.frame_index = min(len(self.filtered_frames) - 1, self.frame_index + 10)
                self.ensure_frame_visible(10)
            elif self.active_panel == "poses":
                self.switch_pose(min(len(self.pose_list) - 1, self.pose_index + 5))

        # Add layer from current frame
        elif key in (pygame.K_RETURN, pygame.K_SPACE):
            if self.active_panel == "frames":
                self.add_layer_from_current_frame()

        # Layer selection cycling
        elif key == pygame.K_TAB and mod_ctrl:
            self.cycle_layer(reverse=mod_shift)

        # Layer reordering
        elif key == pygame.K_LEFTBRACKET:
            self.move_layer_order(-1)
        elif key == pygame.K_RIGHTBRACKET:
            self.move_layer_order(1)

        # Movement of current layer
        elif key in (pygame.K_LEFT, pygame.K_RIGHT) and self.active_panel != "poses":
            self.move_current_layer(key, mod_shift)
        elif key in (pygame.K_UP, pygame.K_DOWN) and self.active_panel != "poses":
            self.move_current_layer(key, mod_shift)

        # Delete current layer
        elif key in (pygame.K_DELETE, pygame.K_BACKSPACE):
            self.delete_current_layer()

        # Copy/Paste layer
        elif key == pygame.K_c and mod_ctrl:
            self.copy_current_layer()
        elif key == pygame.K_v and mod_ctrl:
            self.paste_layer()

        # Save
        elif key == pygame.K_s and mod_ctrl:
            self.save_pose()

        # Reload from poses.json
        elif key == pygame.K_r and mod_ctrl:
            self.load_current_pose()

        # Clear all layers
        elif key == pygame.K_n and mod_ctrl:
            self.layers = []
            self.layer_index = -1
            self.unsaved_changes = True
            self.push_history()
            self.update_title()

        # Duplicate pose
        elif key == pygame.K_d and mod_ctrl:
            self.duplicate_current_pose()

        # Zoom controls
        elif key in (pygame.K_EQUALS, pygame.K_PLUS):
            self.preview_scale = min(3.0, self.preview_scale + 0.1)
        elif key in (pygame.K_MINUS, pygame.K_UNDERSCORE):
            self.preview_scale = max(0.3, self.preview_scale - 0.1)
        elif key == pygame.K_0 and mod_ctrl:
            self.preview_scale = 1.0

        return True

    def ensure_frame_visible(self, direction):
        visible_rows = (self.screen_height - 100) // 22
        if self.frame_index < self.frame_scroll:
            self.frame_scroll = self.frame_index
        elif self.frame_index >= self.frame_scroll + visible_rows:
            self.frame_scroll = self.frame_index - visible_rows + 1

    def add_layer_from_current_frame(self):
        if not self.filtered_frames:
            return
        frame_name = self.filtered_frames[self.frame_index]
        new_layer = {"frame": frame_name, "x": 0, "y": 0}
        self.layers.append(new_layer)
        self.layer_index = len(self.layers) - 1
        self.unsaved_changes = True
        self.push_history()
        self.update_title()

    def cycle_layer(self, reverse=False):
        if not self.layers:
            self.layer_index = -1
            return
        if reverse:
            self.layer_index = (self.layer_index - 1) % len(self.layers)
        else:
            self.layer_index = (self.layer_index + 1) % len(self.layers)

    def move_layer_order(self, direction):
        """Move current layer up or down in the layer stack."""
        if self.layer_index < 0 or self.layer_index >= len(self.layers):
            return
        
        new_index = self.layer_index + direction
        if 0 <= new_index < len(self.layers):
            self.layers[self.layer_index], self.layers[new_index] = \
                self.layers[new_index], self.layers[self.layer_index]
            self.layer_index = new_index
            self.unsaved_changes = True
            self.push_history()
            self.update_title()

    def move_current_layer(self, key, mod_shift):
        if self.layer_index < 0 or self.layer_index >= len(self.layers):
            return
        step = 10 if mod_shift else 1
        layer = self.layers[self.layer_index]
        if key == pygame.K_LEFT:
            layer["x"] -= step
        elif key == pygame.K_RIGHT:
            layer["x"] += step
        elif key == pygame.K_UP:
            layer["y"] -= step
        elif key == pygame.K_DOWN:
            layer["y"] += step
        self.unsaved_changes = True
        self.update_title()

    def delete_current_layer(self):
        if self.layer_index < 0 or self.layer_index >= len(self.layers):
            return
        del self.layers[self.layer_index]
        if not self.layers:
            self.layer_index = -1
        else:
            self.layer_index = min(self.layer_index, len(self.layers) - 1)
        self.unsaved_changes = True
        self.push_history()
        self.update_title()

    def copy_current_layer(self):
        if self.layer_index >= 0 and self.layer_index < len(self.layers):
            self.clipboard_layer = deepcopy(self.layers[self.layer_index])
            print(f"Copied layer: {self.clipboard_layer['frame']}")

    def paste_layer(self):
        if self.clipboard_layer:
            new_layer = deepcopy(self.clipboard_layer)
            new_layer["x"] += 10  # Offset slightly
            new_layer["y"] += 10
            self.layers.append(new_layer)
            self.layer_index = len(self.layers) - 1
            self.unsaved_changes = True
            self.push_history()
            self.update_title()
            print(f"Pasted layer: {new_layer['frame']}")

    # -----------------------------
    # Rendering
    # -----------------------------

    def draw(self):
        self.screen.fill((15, 15, 20))

        if self.preview_mode:
            # Layer preview mode - show individual layers
            self.draw_layer_preview()
        else:
            # Normal editing mode
            # Left panel (frames)
            self.draw_frame_list()

            # Right panel (poses)
            self.draw_pose_list()

            # Preview panel
            self.draw_preview()
            
            # Layers panel (optional)
            if self.show_layers_panel:
                self.draw_layers_panel()

        # Context menu (always on top)
        if self.context_menu_pos:
            self.draw_context_menu()

        # Help overlay
        if self.show_help:
            self.draw_help()

        # Save feedback
        if self.save_feedback_timer > 0:
            self.draw_save_feedback()

    def draw_frame_list(self):
        panel_width = 350
        panel_color = (40, 40, 50) if self.active_panel == "frames" else (30, 30, 40)
        pygame.draw.rect(self.screen, panel_color, (0, 0, panel_width, self.screen_height))

        # Title
        title_text = f"Frames ({len(self.filtered_frames)})"
        if self.active_panel == "frames":
            title_text += " [ACTIVE]"
        title = self.font.render(title_text, True, (200, 200, 220))
        self.screen.blit(title, (10, 10))

        # Frame list
        row_height = 22
        start_y = 50
        visible_rows = (self.screen_height - start_y - 10) // row_height

        for i in range(visible_rows):
            idx = self.frame_scroll + i
            if idx >= len(self.filtered_frames):
                break
            name = self.filtered_frames[idx]
            y = start_y + i * row_height

            if idx == self.frame_index:
                pygame.draw.rect(self.screen, (60, 80, 120), (5, y - 2, panel_width - 10, row_height))

            text = self.small_font.render(name, True, (220, 220, 220))
            self.screen.blit(text, (10, y))

        # Scrollbar indicator
        if len(self.filtered_frames) > visible_rows:
            total_h = self.screen_height - start_y - 10
            bar_h = max(20, int(total_h * visible_rows / len(self.filtered_frames)))
            bar_y = start_y + int((self.frame_scroll / len(self.filtered_frames)) * total_h)
            pygame.draw.rect(self.screen, (100, 100, 120), (panel_width - 8, bar_y, 6, bar_h))

    def draw_pose_list(self):
        panel_x = self.screen_width - 250
        panel_width = 250
        panel_color = (40, 40, 50) if self.active_panel == "poses" else (30, 30, 40)
        pygame.draw.rect(self.screen, panel_color, (panel_x, 0, panel_width, self.screen_height))

        # Title
        title_text = f"Poses ({len(self.pose_list)})"
        if self.active_panel == "poses":
            title_text += " [ACTIVE]"
        title = self.font.render(title_text, True, (200, 200, 220))
        self.screen.blit(title, (panel_x + 10, 10))

        # Pose list
        row_height = 30
        start_y = 50
        visible_rows = (self.screen_height - start_y - 10) // row_height

        for i in range(visible_rows):
            idx = self.pose_scroll + i
            if idx >= len(self.pose_list):
                break
            pose_name = self.pose_list[idx]
            y = start_y + i * row_height

            if idx == self.pose_index:
                pygame.draw.rect(self.screen, (80, 60, 120), 
                               (panel_x + 5, y - 2, panel_width - 10, row_height))

            # Pose name
            text = self.small_font.render(pose_name, True, (220, 220, 220))
            self.screen.blit(text, (panel_x + 10, y))

            # Layer count
            pose_data = self.poses_data.get("poses", {}).get(pose_name, {})
            layer_count = len(pose_data.get("layers", []))
            count_text = self.tiny_font.render(f"({layer_count} layers)", True, (150, 150, 160))
            self.screen.blit(count_text, (panel_x + 10, y + 15))

    def draw_preview(self):
        # Background area
        panel_x = 360
        panel_y = 10
        panel_w = self.screen_width - panel_x - 260
        panel_h = self.screen_height - 10

        pygame.draw.rect(self.screen, (25, 25, 30), (panel_x, panel_y, panel_w, panel_h))

        # Grid
        if self.show_grid:
            grid_spacing = 50
            grid_color = (40, 40, 45)
            for x in range(panel_x, panel_x + panel_w, grid_spacing):
                pygame.draw.line(self.screen, grid_color, (x, panel_y), (x, panel_y + panel_h))
            for y in range(panel_y, panel_y + panel_h, grid_spacing):
                pygame.draw.line(self.screen, grid_color, (panel_x, y), (panel_x + panel_w, y))

        # Center crosshair
        cx, cy = self.preview_cx, self.preview_cy
        pygame.draw.line(self.screen, (100, 100, 110), (cx - 20, cy), (cx + 20, cy), 2)
        pygame.draw.line(self.screen, (100, 100, 110), (cx, cy - 20), (cx, cy + 20), 2)

        # Draw each layer
        for idx, layer in enumerate(self.layers):
            try:
                surf = self.atlas.get_surface(layer["frame"])
            except KeyError:
                continue

            # Apply zoom
            if self.preview_scale != 1.0:
                new_w = int(surf.get_width() * self.preview_scale)
                new_h = int(surf.get_height() * self.preview_scale)
                surf = pygame.transform.scale(surf, (new_w, new_h))

            x = cx + int(layer["x"] * self.preview_scale) - surf.get_width() // 2
            y = cy + int(layer["y"] * self.preview_scale) - surf.get_height() // 2

            self.screen.blit(surf, (x, y))

            # Outline for selected layer
            if idx == self.layer_index:
                rect = pygame.Rect(x, y, surf.get_width(), surf.get_height())
                pygame.draw.rect(self.screen, (255, 255, 0), rect, 2)
                
                # Draw layer info
                info_text = f"Layer {idx}: {layer['frame']} ({layer['x']}, {layer['y']})"
                info_surf = self.small_font.render(info_text, True, (255, 255, 100))
                self.screen.blit(info_surf, (panel_x + 10, panel_y + panel_h - 30))

        # Top info bar
        info_lines = [
            f"Pose: {self.pose_name}",
            f"Layers: {len(self.layers)}",
            f"Zoom: {self.preview_scale:.1f}x",
            f"Grid: {'ON' if self.show_grid else 'OFF'}"
        ]
        
        for i, line in enumerate(info_lines):
            surf = self.small_font.render(line, True, (200, 200, 220))
            self.screen.blit(surf, (panel_x + 10 + i * 150, panel_y + 10))

    def draw_help(self):
        # Semi-transparent overlay
        overlay = pygame.Surface((self.screen_width, self.screen_height))
        overlay.set_alpha(200)
        overlay.fill((10, 10, 15))
        self.screen.blit(overlay, (0, 0))

        # Help box
        box_w = 1000
        box_h = 680
        box_x = (self.screen_width - box_w) // 2
        box_y = (self.screen_height - box_h) // 2

        pygame.draw.rect(self.screen, (30, 30, 40), (box_x, box_y, box_w, box_h))
        pygame.draw.rect(self.screen, (100, 100, 120), (box_x, box_y, box_w, box_h), 2)

        # Title
        title = self.big_font.render("Keyboard & Mouse Controls", True, (220, 220, 255))
        self.screen.blit(title, (box_x + 20, box_y + 15))

        # Help content in three columns
        col1_x = box_x + 25
        col2_x = box_x + 355
        col3_x = box_x + 685
        y_start = box_y + 55
        line_height = 18
        
        col1_help = [
            ("PANEL NAVIGATION:", True),
            ("  TAB - Switch panels", False),
            ("  UP/DOWN - Navigate", False),
            ("  PgUp/PgDn - Fast scroll", False),
            ("  Click - Select item", False),
            ("  Double Click - Add layer", False),
            ("  Right Click - Context menu", False),
            ("", False),
            ("LAYER OPERATIONS:", True),
            ("  Enter/Space - Add layer", False),
            ("  Ctrl+TAB - Cycle forward", False),
            ("  Shift+Ctrl+TAB - Backward", False),
            ("  Arrows - Move (Shift=x10)", False),
            ("  [ / ] - Reorder layer", False),
            ("  Delete - Remove layer", False),
            ("", False),
            ("COPY/PASTE:", True),
            ("  Ctrl+C - Copy", False),
            ("  Ctrl+V - Paste", False),
        ]
        
        col2_help = [
            ("UNDO/REDO:", True),
            ("  Ctrl+Z - Undo", False),
            ("  Ctrl+Shift+Z - Redo", False),
            ("  Ctrl+Y - Redo (alt)", False),
            ("", False),
            ("SAVE/LOAD:", True),
            ("  Ctrl+S - Save pose", False),
            ("  Ctrl+R - Reload", False),
            ("  Ctrl+N - Clear layers", False),
            ("  Ctrl+D - Duplicate pose", False),
            ("", False),
            ("VIEW:", True),
            ("  G - Toggle grid", False),
            ("  P - Layer preview", False),
            ("  L - Toggle layers panel", False),
            ("  +/- - Zoom", False),
            ("  Ctrl+0 - Reset zoom", False),
            ("  Wheel - Scroll", False),
            ("  Ctrl+Wheel - Zoom", False),
        ]
        
        col3_help = [
            ("FULLSCREEN:", True),
            ("  F11 - Toggle fullscreen", False),
            ("  Ctrl+F - Toggle fullscreen", False),
            ("", False),
            ("POSE MANAGEMENT:", True),
            ("  Right click on pose:", False),
            ("    • New Pose", False),
            ("    • Rename", False),
            ("    • Duplicate", False),
            ("    • Delete", False),
            ("", False),
            ("OTHER:", True),
            ("  H / F1 - This help", False),
            ("  ESC - Save & quit", False),
            ("", False),
            ("", False),
            ("TIPS:", True),
            ("  • Auto-saves on quit", False),
            ("  • Double-click frames", False),
            ("  • Right-click for menus", False),
        ]
        
        # Draw all columns
        for col_x, col_help in [(col1_x, col1_help), (col2_x, col2_help), (col3_x, col3_help)]:
            y = y_start
            for text, is_header in col_help:
                if not text:
                    y += line_height * 0.5
                    continue
                
                if is_header:
                    color = (180, 200, 255)
                    surf = self.font.render(text, True, color)
                else:
                    color = (200, 200, 200)
                    surf = self.small_font.render(text, True, color)
                self.screen.blit(surf, (col_x, y))
                y += line_height

    def draw_save_feedback(self):
        alpha = min(255, self.save_feedback_timer * 4)
        text = self.big_font.render("SAVED", True, (100, 255, 100))
        text.set_alpha(alpha)
        x = self.screen_width // 2 - text.get_width() // 2
        y = 50
        self.screen.blit(text, (x, y))

    def draw_context_menu(self):
        """Draw right-click context menu."""
        if not self.context_menu_pos:
            return
        
        menu_x, menu_y = self.context_menu_pos
        menu_width = 180
        item_height = 30
        
        items = []
        if self.context_menu_target == "pose":
            items = ["New Pose", "Rename", "Duplicate", "Delete"]
        
        menu_height = len(items) * item_height
        
        # Background
        pygame.draw.rect(self.screen, (45, 45, 55), 
                        (menu_x, menu_y, menu_width, menu_height), 
                        border_radius=4)
        pygame.draw.rect(self.screen, (100, 100, 120), 
                        (menu_x, menu_y, menu_width, menu_height), 
                        2, border_radius=4)
        
        # Items
        mx, my = pygame.mouse.get_pos()
        for i, item in enumerate(items):
            item_y = menu_y + i * item_height
            
            # Hover highlight
            if (menu_x <= mx <= menu_x + menu_width and 
                item_y <= my < item_y + item_height):
                pygame.draw.rect(self.screen, (60, 60, 80), 
                               (menu_x + 2, item_y + 2, menu_width - 4, item_height - 4))
            
            # Text
            text_color = (220, 220, 220)
            if item == "Delete":
                text_color = (255, 100, 100)
            
            text_surf = self.small_font.render(item, True, text_color)
            self.screen.blit(text_surf, (menu_x + 10, item_y + 8))

    def draw_layers_panel(self):
        """Draw floating layers panel showing current layer stack."""
        if not self.layers:
            return
        
        panel_width = 200
        panel_height = min(400, len(self.layers) * 25 + 40)
        panel_x = self.screen_width - 260 - panel_width - 10
        panel_y = self.screen_height - panel_height - 10
        
        # Background
        pygame.draw.rect(self.screen, (35, 35, 45), 
                        (panel_x, panel_y, panel_width, panel_height), 
                        border_radius=6)
        pygame.draw.rect(self.screen, (80, 80, 100), 
                        (panel_x, panel_y, panel_width, panel_height), 
                        2, border_radius=6)
        
        # Title
        title = self.font.render("Layers", True, (200, 200, 220))
        self.screen.blit(title, (panel_x + 10, panel_y + 10))
        
        # Layer list (reverse order - top to bottom)
        y = panel_y + 35
        for i in range(len(self.layers) - 1, -1, -1):
            layer = self.layers[i]
            
            # Highlight selected
            if i == self.layer_index:
                pygame.draw.rect(self.screen, (60, 60, 90), 
                               (panel_x + 5, y - 2, panel_width - 10, 22))
            
            # Layer number and frame name
            layer_text = f"{i}: {layer['frame'][:15]}"
            if len(layer['frame']) > 15:
                layer_text += "..."
            
            text_surf = self.tiny_font.render(layer_text, True, (200, 200, 200))
            self.screen.blit(text_surf, (panel_x + 10, y))
            
            y += 22
            if y > panel_y + panel_height - 10:
                break

    def draw_layer_preview(self):
        """Draw individual layer preview mode."""
        self.screen.fill((20, 20, 25))
        
        if not self.layers:
            # No layers message
            msg = self.big_font.render("No layers to preview", True, (150, 150, 160))
            self.screen.blit(msg, (
                self.screen_width // 2 - msg.get_width() // 2,
                self.screen_height // 2
            ))
            
            hint = self.font.render("Press P to exit preview mode", True, (120, 120, 130))
            self.screen.blit(hint, (
                self.screen_width // 2 - hint.get_width() // 2,
                self.screen_height // 2 + 40
            ))
            return
        
        # Calculate grid layout
        cols = min(4, len(self.layers))
        rows = (len(self.layers) + cols - 1) // cols
        
        cell_w = self.screen_width // cols
        cell_h = self.screen_height // rows
        
        # Draw each layer in grid
        for idx, layer in enumerate(self.layers):
            col = idx % cols
            row = idx // cols
            
            cell_x = col * cell_w
            cell_y = row * cell_h
            
            # Cell background
            bg_color = (30, 30, 35) if idx == self.layer_index else (25, 25, 30)
            pygame.draw.rect(self.screen, bg_color, (cell_x, cell_y, cell_w, cell_h))
            pygame.draw.rect(self.screen, (50, 50, 60), (cell_x, cell_y, cell_w, cell_h), 1)
            
            # Draw layer
            try:
                surf = self.atlas.get_surface(layer["frame"])
                
                # Scale to fit cell
                max_w = cell_w - 40
                max_h = cell_h - 60
                scale = min(max_w / surf.get_width(), max_h / surf.get_height(), 1.0)
                
                if scale < 1.0:
                    new_w = int(surf.get_width() * scale)
                    new_h = int(surf.get_height() * scale)
                    surf = pygame.transform.scale(surf, (new_w, new_h))
                
                # Center in cell
                x = cell_x + (cell_w - surf.get_width()) // 2
                y = cell_y + (cell_h - surf.get_height()) // 2 - 10
                
                self.screen.blit(surf, (x, y))
                
            except KeyError:
                error_text = self.small_font.render("Missing", True, (255, 100, 100))
                self.screen.blit(error_text, (cell_x + 10, cell_y + cell_h // 2))
            
            # Label
            label = self.small_font.render(f"Layer {idx}", True, (180, 180, 200))
            self.screen.blit(label, (cell_x + 10, cell_y + 10))
            
            # Frame name
            frame_name = layer["frame"]
            if len(frame_name) > 20:
                frame_name = frame_name[:17] + "..."
            name_surf = self.tiny_font.render(frame_name, True, (150, 150, 160))
            self.screen.blit(name_surf, (cell_x + 10, cell_y + cell_h - 25))
        
        # Instructions
        instr = self.font.render("Press P to exit | Ctrl+TAB to cycle layers", True, (200, 200, 220))
        instr_x = (self.screen_width - instr.get_width()) // 2
        self.screen.blit(instr, (instr_x, 10))


# --------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------

def main():
    print("=" * 60)
    print("Pose Editor for Dissonance")
    print("=" * 60)
    
    # Show character launcher
    launcher = CharacterLauncher()
    selected_char = launcher.run()
    pygame.quit()
    
    if selected_char is None:
        print("Cancelled.")
        return
    
    print(f"\nLoading character: {selected_char}")
    
    # Launch pose editor
    try:
        editor = PoseEditor(selected_char, pose_name=None)
        editor.run()
        print(f"\nPose editor closed.")
    except FileNotFoundError as e:
        print(f"\nError: {e}")
        print(f"Make sure the character assets exist in:")
        print(f"  - {IMAGES_DIR / selected_char}")
        print(f"  - {DATA_DIR / selected_char}")
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()