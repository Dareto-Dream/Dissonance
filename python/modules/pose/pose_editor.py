"""
Pose Editor Module - Enhanced Version

Interactive character pose composer with full editing capabilities.
Integrates with the Dissonance VN Editor main application.

Features:
- Character and pose selection
- Interactive layer manipulation
- Copy/paste with Ctrl+C/V
- Undo/redo with Ctrl+Z/Ctrl+Shift+Z
- Layer reordering with [/]
- Grid overlay toggle
- Zoom controls
- Context menus for pose management
- Auto-save on switch
- Layer preview mode
"""

import json
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from copy import deepcopy

import pygame
import pygame.freetype


class Atlas:
    """Texture atlas loader for Sparrow format."""
    
    def __init__(self, image_surface, frames):
        self.image = image_surface
        self.frames = frames  # name -> (x, y, w, h, rotated)
    
    @classmethod
    def from_xml(cls, character_id: str, project_root: Path):
        """Load atlas from XML and PNG files."""
        char_dir = project_root / "assets" / "images" / "characters" / character_id
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
        """Extract a frame surface from the atlas."""
        if name not in self.frames:
            raise KeyError(f"Frame not found: {name}")
        
        x, y, w, h, rotated = self.frames[name]
        rect = pygame.Rect(x, y, w, h)
        sub = self.image.subsurface(rect).copy()
        
        if rotated:
            sub = pygame.transform.rotate(sub, -90)
        
        return sub


class History:
    """Undo/redo history manager."""
    
    def __init__(self, max_size=50):
        self.states = []
        self.current = -1
        self.max_size = max_size
    
    def push(self, state):
        """Push a new state onto the history."""
        self.states = self.states[:self.current + 1]
        self.states.append(deepcopy(state))
        self.current += 1
        
        if len(self.states) > self.max_size:
            self.states.pop(0)
            self.current -= 1
    
    def undo(self):
        """Undo to previous state."""
        if self.current > 0:
            self.current -= 1
            return deepcopy(self.states[self.current])
        return None
    
    def redo(self):
        """Redo to next state."""
        if self.current < len(self.states) - 1:
            self.current += 1
            return deepcopy(self.states[self.current])
        return None
    
    def can_undo(self):
        return self.current > 0
    
    def can_redo(self):
        return self.current < len(self.states) - 1


class TextInputDialog:
    """Modal text input dialog."""
    
    def __init__(self, parent_surface, title: str, initial_text: str = "", prompt: str = ""):
        self.parent_surface = parent_surface
        self.title = title
        self.prompt = prompt
        self.text = initial_text
        self.cursor_pos = len(initial_text)
        self.cursor_visible = True
        self.cursor_timer = 0
        
        self.font = pygame.freetype.SysFont("Arial", 18)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        
        self.active = True
        self.result = None
    
    def run(self) -> Optional[str]:
        """Run modal dialog and return result."""
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
                    self.handle_keydown(event.key, event.unicode)
            
            self.draw()
            pygame.display.flip()
        
        return self.result
    
    def handle_keydown(self, key, unicode):
        """Handle keyboard input."""
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
        """Draw dialog overlay."""
        # Darken background
        overlay = pygame.Surface(self.parent_surface.get_size())
        overlay.set_alpha(180)
        overlay.fill((0, 0, 0))
        self.parent_surface.blit(overlay, (0, 0))
        
        # Dialog box
        box_w = 500
        box_h = 200
        box_x = (self.parent_surface.get_width() - box_w) // 2
        box_y = (self.parent_surface.get_height() - box_h) // 2
        
        pygame.draw.rect(self.parent_surface, (40, 40, 50), 
                        (box_x, box_y, box_w, box_h), border_radius=8)
        pygame.draw.rect(self.parent_surface, (100, 100, 120), 
                        (box_x, box_y, box_w, box_h), 3, border_radius=8)
        
        # Title
        title_surf, _ = self.title_font.render(self.title, (220, 220, 255))
        self.parent_surface.blit(title_surf, (box_x + 20, box_y + 20))
        
        # Prompt
        if self.prompt:
            prompt_surf, _ = self.font.render(self.prompt, (180, 180, 200))
            self.parent_surface.blit(prompt_surf, (box_x + 20, box_y + 60))
        
        # Input box
        input_y = box_y + 95 if self.prompt else box_y + 70
        input_box = pygame.Rect(box_x + 20, input_y, box_w - 40, 40)
        pygame.draw.rect(self.parent_surface, (30, 30, 35), input_box, border_radius=4)
        pygame.draw.rect(self.parent_surface, (80, 80, 100), input_box, 2, border_radius=4)
        
        # Text
        text_surf, _ = self.font.render(self.text, (220, 220, 220))
        self.parent_surface.blit(text_surf, (input_box.x + 10, input_box.y + 10))
        
        # Cursor
        if self.cursor_visible:
            cursor_x = input_box.x + 10
            if self.cursor_pos > 0:
                pre_text, _ = self.font.render(self.text[:self.cursor_pos], (220, 220, 220))
                cursor_x += pre_text.get_width()
            pygame.draw.line(self.parent_surface, (220, 220, 220),
                           (cursor_x, input_box.y + 8),
                           (cursor_x, input_box.y + 32), 2)
        
        # Instructions
        instr_y = input_y + 50
        instr, _ = self.font.render("Enter to confirm | ESC to cancel", (150, 150, 160))
        instr_x = box_x + (box_w - instr.get_width()) // 2
        self.parent_surface.blit(instr, (instr_x, instr_y))


class PoseEditorModule:
    """Interactive pose editor module for the VN Editor."""
    
    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = project_root
        
        # Fonts
        self.font = pygame.freetype.SysFont("Arial", 16)
        self.small_font = pygame.freetype.SysFont("Arial", 14)
        self.big_font = pygame.freetype.SysFont("Arial", 20, bold=True)
        self.tiny_font = pygame.freetype.SysFont("Arial", 12)
        
        # Load character list
        self.characters = self.load_character_list()
        self.character_names = sorted(self.characters.keys())
        
        # Character selection
        self.selected_character_index = 0
        self.current_character = None
        self.atlas = None
        self.frame_names = []
        
        # Frame list state
        self.frame_index = 0
        self.frame_scroll = 0
        
        # Layer editing
        self.layers = []
        self.layer_index = -1
        
        # Pose management
        self.poses_data = {}
        self.pose_list = []
        self.pose_index = 0
        self.pose_name = "default"
        self.pose_scroll = 0
        
        # UI state
        self.active_panel = "characters"  # "characters", "frames", "poses"
        self.preview_scale = 1.0
        self.show_grid = True
        self.show_layers_panel = True
        self.preview_mode = False
        
        # Preview center
        self.preview_cx = self.rect.width // 2
        self.preview_cy = self.rect.height // 2
        
        # Clipboard
        self.clipboard_layer = None
        
        # History
        self.history = History()
        
        # Status
        self.unsaved_changes = False
        self.save_feedback_timer = 0
        self.status_message = ""
        
        # Context menu
        self.context_menu_pos = None
        self.context_menu_target = None
        
        # Load first character if available
        if self.character_names:
            self.load_character(self.character_names[0])
    
    def load_character_list(self):
        """Load available characters from characters.json."""
        chars_path = self.project_root / "assets" / "data" / "characters" / "characters.json"
        
        if not chars_path.exists():
            return {}
        
        try:
            with chars_path.open("r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading characters.json: {e}")
            return {}
    
    def load_character(self, character_id: str):
        """Load a character's atlas and pose data."""
        try:
            self.atlas = Atlas.from_xml(character_id, self.project_root)
            self.frame_names = self.atlas.list_frame_names()
            self.current_character = character_id
            
            # Load poses
            self.load_poses(character_id)
            
            # Reset state
            self.frame_index = 0
            self.frame_scroll = 0
            self.active_panel = "frames"
            
            print(f"Loaded character: {character_id}")
            
        except Exception as e:
            print(f"Error loading character {character_id}: {e}")
            self.status_message = f"Error: {e}"
    
    def load_poses(self, character_id: str):
        """Load pose data for character."""
        char_data_dir = self.project_root / "assets" / "data" / "characters" / character_id
        poses_path = char_data_dir / "poses.json"
        
        if poses_path.exists():
            with poses_path.open("r", encoding="utf-8") as f:
                self.poses_data = json.load(f)
        else:
            self.poses_data = {
                "character": character_id,
                "config": {"scale": 1.0, "base_offset": {"x": 0, "y": 0}},
                "poses": {}
            }
        
        self.pose_list = sorted(self.poses_data.get("poses", {}).keys())
        
        if not self.pose_list:
            self.pose_list = ["default"]
            self.poses_data["poses"] = {"default": {"layers": []}}
        
        self.pose_index = 0
        self.pose_name = self.pose_list[0]
        self.load_current_pose()
    
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
    
    def save_pose(self):
        """Save current pose to file."""
        if not self.current_character:
            return
        
        pose_entry = {
            "layers": [
                {"frame": l["frame"], "x": int(l["x"]), "y": int(l["y"])}
                for l in self.layers
            ]
        }
        
        if "poses" not in self.poses_data:
            self.poses_data["poses"] = {}
        
        self.poses_data["poses"][self.pose_name] = pose_entry
        
        # Save to file
        char_data_dir = self.project_root / "assets" / "data" / "characters" / self.current_character
        char_data_dir.mkdir(parents=True, exist_ok=True)
        poses_path = char_data_dir / "poses.json"
        
        with poses_path.open("w", encoding="utf-8") as f:
            json.dump(self.poses_data, f, indent=2)
        
        self.unsaved_changes = False
        self.save_feedback_timer = 60
        self.status_message = f"Saved pose '{self.pose_name}'"
    
    def push_history(self):
        """Push current state to history."""
        state = {
            "layers": deepcopy(self.layers),
            "layer_index": self.layer_index
        }
        self.history.push(state)
    
    def restore_state(self, state):
        """Restore state from history."""
        if state:
            self.layers = deepcopy(state["layers"])
            self.layer_index = state["layer_index"]
            self.unsaved_changes = True
    
    def handle_event(self, event):
        """Handle input events."""
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # Left click
                self.handle_mouse_click(event.pos)
            elif event.button == 3:  # Right click
                self.handle_right_click(event.pos)
        
        elif event.type == pygame.MOUSEWHEEL:
            self.handle_mousewheel(event.y, pygame.key.get_mods())
        
        elif event.type == pygame.KEYDOWN:
            self.handle_keydown(event.key, pygame.key.get_mods())
    
    def handle_mouse_click(self, pos):
        """Handle left mouse clicks."""
        mx, my = pos
        
        # Close context menu
        if self.context_menu_pos:
            if not self.is_click_in_context_menu((mx, my)):
                self.context_menu_pos = None
                self.context_menu_target = None
            else:
                self.handle_context_menu_click((mx, my))
                return
        
        # Character list (left panel, 300px wide)
        if mx < 300:
            self.active_panel = "characters"
            row_height = 30
            start_y = 80
            visible_rows = (self.rect.height - start_y - 10) // row_height
            
            for i in range(visible_rows):
                idx = i
                if idx >= len(self.character_names):
                    break
                y = start_y + i * row_height
                
                if y <= my < y + row_height:
                    if idx != self.selected_character_index:
                        if self.unsaved_changes:
                            self.save_pose()
                        self.selected_character_index = idx
                        self.load_character(self.character_names[idx])
                    break
        
        # Frame list (left panel below characters)
        elif mx < 300:
            self.active_panel = "frames"
        
        # Pose list (right panel, 250px wide)
        elif mx >= self.rect.width - 250:
            self.active_panel = "poses"
            panel_x = self.rect.width - 250
            row_height = 30
            start_y = 50
            
            relative_y = my - start_y
            idx = self.pose_scroll + (relative_y // row_height)
            
            if 0 <= idx < len(self.pose_list):
                self.switch_pose(idx)
    
    def handle_right_click(self, pos):
        """Handle right mouse clicks for context menus."""
        mx, my = pos
        
        # Check pose list
        if mx >= self.rect.width - 250:
            row_height = 30
            start_y = 50
            
            relative_y = my - start_y
            idx = self.pose_scroll + (relative_y // row_height)
            
            if 0 <= idx < len(self.pose_list):
                self.pose_index = idx
                self.pose_name = self.pose_list[idx]
                self.context_menu_pos = pos
                self.context_menu_target = "pose"
    
    def is_click_in_context_menu(self, pos) -> bool:
        """Check if click is in context menu."""
        if not self.context_menu_pos:
            return False
        
        mx, my = pos
        menu_x, menu_y = self.context_menu_pos
        menu_width = 180
        menu_height = 120
        
        return (menu_x <= mx <= menu_x + menu_width and
                menu_y <= my <= menu_y + menu_height)
    
    def handle_context_menu_click(self, pos):
        """Handle context menu selection."""
        mx, my = pos
        menu_x, menu_y = self.context_menu_pos
        item_height = 30
        
        relative_y = my - menu_y
        item_index = int(relative_y / item_height)
        
        if self.context_menu_target == "pose":
            if item_index == 0:  # New Pose
                # Would need access to parent surface for modal dialog
                pass
            elif item_index == 1:  # Rename
                pass
            elif item_index == 2:  # Duplicate
                self.duplicate_current_pose()
            elif item_index == 3:  # Delete
                self.delete_current_pose()
        
        self.context_menu_pos = None
        self.context_menu_target = None
    
    def handle_mousewheel(self, y, mods):
        """Handle mouse wheel for zoom/scroll."""
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
    
    def handle_keydown(self, key, mods):
        """Handle keyboard input."""
        mod_shift = mods & pygame.KMOD_SHIFT
        mod_ctrl = mods & pygame.KMOD_CTRL
        
        # Grid toggle
        if key == pygame.K_g and not mod_ctrl:
            self.show_grid = not self.show_grid
        
        # Preview mode toggle
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
        
        elif key == pygame.K_y and mod_ctrl:
            self.restore_state(self.history.redo())
        
        # Navigation
        elif key == pygame.K_UP:
            if self.active_panel == "characters":
                self.selected_character_index = max(0, self.selected_character_index - 1)
            elif self.active_panel == "frames":
                self.frame_index = max(0, self.frame_index - 1)
            elif self.active_panel == "poses":
                self.switch_pose(max(0, self.pose_index - 1))
        
        elif key == pygame.K_DOWN:
            if self.active_panel == "characters":
                self.selected_character_index = min(len(self.character_names) - 1,
                                                   self.selected_character_index + 1)
            elif self.active_panel == "frames":
                self.frame_index = min(len(self.frame_names) - 1, self.frame_index + 1)
            elif self.active_panel == "poses":
                self.switch_pose(min(len(self.pose_list) - 1, self.pose_index + 1))
        
        # Add layer
        elif key in (pygame.K_RETURN, pygame.K_SPACE):
            if self.active_panel == "frames" and self.frame_names:
                self.add_layer_from_current_frame()
        
        # Layer movement
        elif key in (pygame.K_LEFT, pygame.K_RIGHT) and self.layer_index >= 0:
            self.move_current_layer(key, mod_shift)
        
        # Layer reordering
        elif key == pygame.K_LEFTBRACKET:
            self.move_layer_order(-1)
        elif key == pygame.K_RIGHTBRACKET:
            self.move_layer_order(1)
        
        # Delete layer
        elif key in (pygame.K_DELETE, pygame.K_BACKSPACE):
            self.delete_current_layer()
        
        # Copy/Paste
        elif key == pygame.K_c and mod_ctrl:
            self.copy_current_layer()
        elif key == pygame.K_v and mod_ctrl:
            self.paste_layer()
        
        # Save
        elif key == pygame.K_s and mod_ctrl:
            self.save_pose()
        
        # Zoom
        elif key in (pygame.K_EQUALS, pygame.K_PLUS):
            self.preview_scale = min(3.0, self.preview_scale + 0.1)
        elif key in (pygame.K_MINUS, pygame.K_UNDERSCORE):
            self.preview_scale = max(0.3, self.preview_scale - 0.1)
        elif key == pygame.K_0 and mod_ctrl:
            self.preview_scale = 1.0
    
    def switch_pose(self, new_index):
        """Switch to different pose."""
        if 0 <= new_index < len(self.pose_list):
            if self.unsaved_changes:
                self.save_pose()
            
            self.pose_index = new_index
            self.pose_name = self.pose_list[self.pose_index]
            self.load_current_pose()
    
    def add_layer_from_current_frame(self):
        """Add current frame as new layer."""
        if not self.frame_names:
            return
        
        frame_name = self.frame_names[self.frame_index]
        new_layer = {"frame": frame_name, "x": 0, "y": 0}
        self.layers.append(new_layer)
        self.layer_index = len(self.layers) - 1
        self.unsaved_changes = True
        self.push_history()
    
    def move_current_layer(self, key, mod_shift):
        """Move current layer with arrow keys."""
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
    
    def move_layer_order(self, direction):
        """Reorder layers."""
        if self.layer_index < 0 or self.layer_index >= len(self.layers):
            return
        
        new_index = self.layer_index + direction
        if 0 <= new_index < len(self.layers):
            self.layers[self.layer_index], self.layers[new_index] = \
                self.layers[new_index], self.layers[self.layer_index]
            self.layer_index = new_index
            self.unsaved_changes = True
            self.push_history()
    
    def delete_current_layer(self):
        """Delete selected layer."""
        if self.layer_index < 0 or self.layer_index >= len(self.layers):
            return
        
        del self.layers[self.layer_index]
        if not self.layers:
            self.layer_index = -1
        else:
            self.layer_index = min(self.layer_index, len(self.layers) - 1)
        
        self.unsaved_changes = True
        self.push_history()
    
    def copy_current_layer(self):
        """Copy current layer to clipboard."""
        if 0 <= self.layer_index < len(self.layers):
            self.clipboard_layer = deepcopy(self.layers[self.layer_index])
            self.status_message = f"Copied: {self.clipboard_layer['frame']}"
    
    def paste_layer(self):
        """Paste layer from clipboard."""
        if self.clipboard_layer:
            new_layer = deepcopy(self.clipboard_layer)
            new_layer["x"] += 10
            new_layer["y"] += 10
            self.layers.append(new_layer)
            self.layer_index = len(self.layers) - 1
            self.unsaved_changes = True
            self.push_history()
            self.status_message = f"Pasted: {new_layer['frame']}"
    
    def duplicate_current_pose(self):
        """Duplicate current pose with new name."""
        base_name = self.pose_name
        counter = 1
        new_name = f"{base_name}_copy"
        
        while new_name in self.pose_list:
            counter += 1
            new_name = f"{base_name}_copy{counter}"
        
        self.pose_list.append(new_name)
        self.pose_list.sort()
        self.poses_data["poses"][new_name] = deepcopy(
            self.poses_data["poses"][self.pose_name]
        )
        
        self.pose_index = self.pose_list.index(new_name)
        self.pose_name = new_name
        self.unsaved_changes = True
        self.save_pose()
    
    def delete_current_pose(self):
        """Delete current pose."""
        if len(self.pose_list) <= 1:
            return
        
        if self.pose_name in self.poses_data.get("poses", {}):
            del self.poses_data["poses"][self.pose_name]
        
        self.pose_list.pop(self.pose_index)
        self.pose_index = min(self.pose_index, len(self.pose_list) - 1)
        self.pose_name = self.pose_list[self.pose_index]
        
        self.save_pose()
        self.load_current_pose()
    
    def update(self, dt):
        """Update per frame."""
        if self.save_feedback_timer > 0:
            self.save_feedback_timer -= 1
        
        if self.status_message and self.save_feedback_timer == 0:
            self.status_message = ""
    
    def draw(self, surface):
        """Render the pose editor."""
        surface.fill(self.theme.bg_dark)
        
        if self.preview_mode:
            self.draw_layer_preview(surface)
        else:
            self.draw_character_list(surface)
            self.draw_pose_list(surface)
            self.draw_preview(surface)
            
            if self.show_layers_panel:
                self.draw_layers_panel(surface)
        
        if self.context_menu_pos:
            self.draw_context_menu(surface)
        
        if self.save_feedback_timer > 0:
            self.draw_save_feedback(surface)
    
    def draw_character_list(self, surface):
        """Draw character selection panel."""
        panel_width = 300
        panel_color = self.theme.bg_medium if self.active_panel == "characters" else self.theme.bg_light
        
        pygame.draw.rect(surface, panel_color, (0, 0, panel_width, self.rect.height))
        
        # Title
        title_text = f"Characters ({len(self.character_names)})"
        if self.active_panel == "characters":
            title_text += " [ACTIVE]"
        
        title_surf, _ = self.font.render(title_text, self.theme.text_primary)
        surface.blit(title_surf, (10, 10))
        
        # Current character indicator
        if self.current_character:
            curr_surf, _ = self.small_font.render(
                f"Current: {self.current_character}",
                self.theme.accent_blue
            )
            surface.blit(curr_surf, (10, 40))
        
        # Character list
        row_height = 30
        start_y = 80
        visible_rows = (self.rect.height - start_y - 10) // row_height
        
        for i in range(visible_rows):
            idx = i
            if idx >= len(self.character_names):
                break
            
            name = self.character_names[idx]
            y = start_y + i * row_height
            
            # Highlight selected
            if idx == self.selected_character_index:
                pygame.draw.rect(surface, self.theme.accent_blue,
                               (5, y - 2, panel_width - 10, row_height))
            
            text_surf, _ = self.small_font.render(name, self.theme.text_primary)
            surface.blit(text_surf, (10, y + 5))
    
    def draw_pose_list(self, surface):
        """Draw pose list panel."""
        panel_x = self.rect.width - 250
        panel_width = 250
        panel_color = self.theme.bg_medium if self.active_panel == "poses" else self.theme.bg_light
        
        pygame.draw.rect(surface, panel_color,
                        (panel_x, 0, panel_width, self.rect.height))
        
        # Title
        title_text = f"Poses ({len(self.pose_list)})"
        if self.active_panel == "poses":
            title_text += " [ACTIVE]"
        
        title_surf, _ = self.font.render(title_text, self.theme.text_primary)
        surface.blit(title_surf, (panel_x + 10, 10))
        
        # Pose list
        row_height = 30
        start_y = 50
        visible_rows = (self.rect.height - start_y - 10) // row_height
        
        for i in range(visible_rows):
            idx = self.pose_scroll + i
            if idx >= len(self.pose_list):
                break
            
            pose_name = self.pose_list[idx]
            y = start_y + i * row_height
            
            # Highlight current
            if idx == self.pose_index:
                pygame.draw.rect(surface, self.theme.accent_blue,
                               (panel_x + 5, y - 2, panel_width - 10, row_height))
            
            # Pose name
            text_surf, _ = self.small_font.render(pose_name, self.theme.text_primary)
            surface.blit(text_surf, (panel_x + 10, y))
            
            # Layer count
            pose_data = self.poses_data.get("poses", {}).get(pose_name, {})
            layer_count = len(pose_data.get("layers", []))
            count_surf, _ = self.tiny_font.render(
                f"({layer_count} layers)",
                self.theme.text_secondary
            )
            surface.blit(count_surf, (panel_x + 10, y + 15))
    
    def draw_preview(self, surface):
        """Draw pose preview area."""
        # Calculate preview area
        panel_x = 310
        panel_y = 10
        panel_w = self.rect.width - panel_x - 260
        panel_h = self.rect.height - 10
        
        pygame.draw.rect(surface, (25, 25, 30), (panel_x, panel_y, panel_w, panel_h))
        
        # Grid
        if self.show_grid:
            grid_spacing = 50
            grid_color = (40, 40, 45)
            for x in range(panel_x, panel_x + panel_w, grid_spacing):
                pygame.draw.line(surface, grid_color, (x, panel_y), (x, panel_y + panel_h))
            for y in range(panel_y, panel_y + panel_h, grid_spacing):
                pygame.draw.line(surface, grid_color, (panel_x, y), (panel_x + panel_w, y))
        
        # Center crosshair
        cx = panel_x + panel_w // 2
        cy = panel_y + panel_h // 2
        pygame.draw.line(surface, (100, 100, 110), (cx - 20, cy), (cx + 20, cy), 2)
        pygame.draw.line(surface, (100, 100, 110), (cx, cy - 20), (cx, cy + 20), 2)
        
        # Draw layers
        if self.atlas:
            for idx, layer in enumerate(self.layers):
                try:
                    surf = self.atlas.get_surface(layer["frame"])
                    
                    # Apply zoom
                    if self.preview_scale != 1.0:
                        new_w = int(surf.get_width() * self.preview_scale)
                        new_h = int(surf.get_height() * self.preview_scale)
                        surf = pygame.transform.scale(surf, (new_w, new_h))
                    
                    x = cx + int(layer["x"] * self.preview_scale) - surf.get_width() // 2
                    y = cy + int(layer["y"] * self.preview_scale) - surf.get_height() // 2
                    
                    surface.blit(surf, (x, y))
                    
                    # Outline selected
                    if idx == self.layer_index:
                        rect = pygame.Rect(x, y, surf.get_width(), surf.get_height())
                        pygame.draw.rect(surface, (255, 255, 0), rect, 2)
                
                except KeyError:
                    pass
        
        # Info bar
        info_lines = [
            f"Pose: {self.pose_name}",
            f"Layers: {len(self.layers)}",
            f"Zoom: {self.preview_scale:.1f}x",
            f"Grid: {'ON' if self.show_grid else 'OFF'}"
        ]
        
        for i, line in enumerate(info_lines):
            surf, _ = self.small_font.render(line, self.theme.text_primary)
            surface.blit(surf, (panel_x + 10 + i * 150, panel_y + 10))
        
        # Selected layer info
        if self.layer_index >= 0 and self.layer_index < len(self.layers):
            layer = self.layers[self.layer_index]
            info = f"Layer {self.layer_index}: {layer['frame']} ({layer['x']}, {layer['y']})"
            info_surf, _ = self.small_font.render(info, self.theme.accent_green)
            surface.blit(info_surf, (panel_x + 10, panel_y + panel_h - 30))
    
    def draw_layers_panel(self, surface):
        """Draw floating layers panel."""
        if not self.layers:
            return
        
        panel_width = 200
        panel_height = min(400, len(self.layers) * 25 + 40)
        panel_x = self.rect.width - 260 - panel_width - 10
        panel_y = self.rect.height - panel_height - 10
        
        pygame.draw.rect(surface, self.theme.bg_medium,
                        (panel_x, panel_y, panel_width, panel_height),
                        border_radius=6)
        pygame.draw.rect(surface, self.theme.border,
                        (panel_x, panel_y, panel_width, panel_height),
                        2, border_radius=6)
        
        # Title
        title_surf, _ = self.font.render("Layers", self.theme.text_primary)
        surface.blit(title_surf, (panel_x + 10, panel_y + 10))
        
        # Layer list (reverse order)
        y = panel_y + 35
        for i in range(len(self.layers) - 1, -1, -1):
            layer = self.layers[i]
            
            if i == self.layer_index:
                pygame.draw.rect(surface, self.theme.accent_blue,
                               (panel_x + 5, y - 2, panel_width - 10, 22))
            
            layer_text = f"{i}: {layer['frame'][:15]}"
            if len(layer['frame']) > 15:
                layer_text += "..."
            
            text_surf, _ = self.tiny_font.render(layer_text, self.theme.text_primary)
            surface.blit(text_surf, (panel_x + 10, y))
            
            y += 22
            if y > panel_y + panel_height - 10:
                break
    
    def draw_layer_preview(self, surface):
        """Draw individual layer preview grid."""
        surface.fill((20, 20, 25))
        
        if not self.layers:
            msg_surf, _ = self.big_font.render("No layers to preview",
                                              self.theme.text_secondary)
            surface.blit(msg_surf, (
                self.rect.width // 2 - msg_surf.get_width() // 2,
                self.rect.height // 2
            ))
            
            hint_surf, _ = self.font.render("Press P to exit preview mode",
                                           self.theme.text_secondary)
            surface.blit(hint_surf, (
                self.rect.width // 2 - hint_surf.get_width() // 2,
                self.rect.height // 2 + 40
            ))
            return
        
        # Grid layout
        cols = min(4, len(self.layers))
        rows = (len(self.layers) + cols - 1) // cols
        
        cell_w = self.rect.width // cols
        cell_h = self.rect.height // rows
        
        # Draw each layer
        for idx, layer in enumerate(self.layers):
            col = idx % cols
            row = idx // cols
            
            cell_x = col * cell_w
            cell_y = row * cell_h
            
            # Cell background
            bg_color = self.theme.bg_medium if idx == self.layer_index else self.theme.bg_light
            pygame.draw.rect(surface, bg_color, (cell_x, cell_y, cell_w, cell_h))
            pygame.draw.rect(surface, self.theme.border,
                           (cell_x, cell_y, cell_w, cell_h), 1)
            
            # Draw layer
            if self.atlas:
                try:
                    surf = self.atlas.get_surface(layer["frame"])
                    
                    # Scale to fit
                    max_w = cell_w - 40
                    max_h = cell_h - 60
                    scale = min(max_w / surf.get_width(), max_h / surf.get_height(), 1.0)
                    
                    if scale < 1.0:
                        new_w = int(surf.get_width() * scale)
                        new_h = int(surf.get_height() * scale)
                        surf = pygame.transform.scale(surf, (new_w, new_h))
                    
                    x = cell_x + (cell_w - surf.get_width()) // 2
                    y = cell_y + (cell_h - surf.get_height()) // 2 - 10
                    
                    surface.blit(surf, (x, y))
                
                except KeyError:
                    error_surf, _ = self.small_font.render("Missing",
                                                          self.theme.error_red)
                    surface.blit(error_surf, (cell_x + 10, cell_y + cell_h // 2))
            
            # Label
            label_surf, _ = self.small_font.render(f"Layer {idx}",
                                                   self.theme.text_primary)
            surface.blit(label_surf, (cell_x + 10, cell_y + 10))
            
            # Frame name
            frame_name = layer["frame"]
            if len(frame_name) > 20:
                frame_name = frame_name[:17] + "..."
            name_surf, _ = self.tiny_font.render(frame_name, self.theme.text_secondary)
            surface.blit(name_surf, (cell_x + 10, cell_y + cell_h - 25))
        
        # Instructions
        instr_surf, _ = self.font.render(
            "Press P to exit | Ctrl+TAB to cycle layers",
            self.theme.text_primary
        )
        instr_x = (self.rect.width - instr_surf.get_width()) // 2
        surface.blit(instr_surf, (instr_x, 10))
    
    def draw_context_menu(self, surface):
        """Draw right-click context menu."""
        if not self.context_menu_pos:
            return
        
        menu_x, menu_y = self.context_menu_pos
        menu_width = 180
        item_height = 30
        
        items = ["New Pose", "Rename", "Duplicate", "Delete"]
        menu_height = len(items) * item_height
        
        pygame.draw.rect(surface, (45, 45, 55),
                        (menu_x, menu_y, menu_width, menu_height),
                        border_radius=4)
        pygame.draw.rect(surface, (100, 100, 120),
                        (menu_x, menu_y, menu_width, menu_height),
                        2, border_radius=4)
        
        mx, my = pygame.mouse.get_pos()
        for i, item in enumerate(items):
            item_y = menu_y + i * item_height
            
            if (menu_x <= mx <= menu_x + menu_width and
                item_y <= my < item_y + item_height):
                pygame.draw.rect(surface, (60, 60, 80),
                               (menu_x + 2, item_y + 2, menu_width - 4, item_height - 4))
            
            text_color = self.theme.error_red if item == "Delete" else self.theme.text_primary
            text_surf, _ = self.small_font.render(item, text_color)
            surface.blit(text_surf, (menu_x + 10, item_y + 8))
    
    def draw_save_feedback(self, surface):
        """Draw save confirmation."""
        alpha = min(255, self.save_feedback_timer * 4)
        text_surf, _ = self.big_font.render("SAVED", self.theme.accent_green)
        
        # Create a temporary surface with alpha
        temp_surf = pygame.Surface(text_surf.get_size(), pygame.SRCALPHA)
        temp_surf.fill((0, 0, 0, 0))
        temp_surf.blit(text_surf, (0, 0))
        temp_surf.set_alpha(alpha)
        
        x = self.rect.width // 2 - text_surf.get_width() // 2
        y = 50
        surface.blit(temp_surf, (x, y))
    
    def get_help_entries(self):
        """Return help text for this module."""
        return [
            (
                "Pose Editor Controls",
                [
                    "TAB - Switch between panels",
                    "UP/DOWN - Navigate lists",
                    "Enter/Space - Add frame as layer",
                    "Arrows - Move selected layer (Shift=x10)",
                    "[ / ] - Reorder layer up/down",
                    "Delete - Remove layer",
                ]
            ),
            (
                "Editing",
                [
                    "Ctrl+C - Copy layer",
                    "Ctrl+V - Paste layer",
                    "Ctrl+Z - Undo",
                    "Ctrl+Shift+Z - Redo",
                    "Ctrl+S - Save pose",
                ]
            ),
            (
                "View",
                [
                    "G - Toggle grid",
                    "P - Toggle layer preview mode",
                    "L - Toggle layers panel",
                    "+/- - Zoom in/out",
                    "Ctrl+0 - Reset zoom",
                    "Ctrl+Wheel - Zoom",
                    "Wheel - Scroll panels",
                ]
            ),
            (
                "Poses",
                [
                    "Right-click pose - Context menu",
                    "  • New Pose",
                    "  • Rename",
                    "  • Duplicate",
                    "  • Delete",
                ]
            )
        ]
    
    def cleanup(self):
        """Clean up resources."""
        if self.unsaved_changes:
            self.save_pose()