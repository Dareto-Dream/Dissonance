"""Scene Placement Module - Position characters and backgrounds."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Optional

import pygame
import pygame.freetype

from modules.utils.data_loader import ensure_export_dir


class ScenePlacement:
    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = project_root
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)

        # Scene browser state
        self.show_browser = True
        self.available_scenes = self._find_scene_files()
        self.selected_scene_index = 0
        self.browser_scroll = 0
        
        # Scene data
        self.scene = None
        self.scene_id = ""
        self.scene_path = None
        self.stage_rect = self._compute_stage_rect()

        self.nodes = []
        self.current_node_index = 0
        self.background_path = ""
        self.visible_characters: Dict[str, Dict] = {}
        self.placements = {}
        
        self.selected_character: Optional[str] = None
        self.dragging = False
        self.drag_offset = (0, 0)
        self.status_message = ""
        self.status_timer = 0.0
    
    def _find_scene_files(self) -> List[Dict]:
        """Find all JSON scene files in the project."""
        scenes = []
        
        # Look in common scene directories
        search_paths = [
            self.project_root / "assets" / "data" / "scenes",
            self.project_root / "scenes",
            self.project_root / "data" / "scenes",
        ]
        
        for search_path in search_paths:
            if not search_path.exists():
                continue
            
            # Find all .json files recursively
            for json_file in search_path.rglob("*.json"):
                try:
                    with open(json_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    
                    # Check if it's a valid scene file
                    if "scene_id" in data and "nodes" in data:
                        relative_path = json_file.relative_to(self.project_root)
                        scenes.append({
                            "path": json_file,
                            "relative_path": str(relative_path),
                            "scene_id": data.get("scene_id", "unknown"),
                            "node_count": len(data.get("nodes", []))
                        })
                except (json.JSONDecodeError, Exception):
                    continue
        
        # Sort by relative path
        scenes.sort(key=lambda x: x["relative_path"])
        
        if not scenes:
            # Add a message about no scenes found
            scenes.append({
                "path": None,
                "relative_path": "No scenes found",
                "scene_id": "Place .json scene files in assets/data/scenes/",
                "node_count": 0
            })
        
        return scenes
    
    def _load_scene(self, scene_info: Dict):
        """Load a specific scene file."""
        if not scene_info["path"] or not scene_info["path"].exists():
            self.status_message = "Invalid scene file"
            self.status_timer = 3.0
            return
        
        try:
            with open(scene_info["path"], 'r', encoding='utf-8') as f:
                self.scene = json.load(f)
            
            self.scene_id = self.scene.get("scene_id", "unknown")
            self.scene_path = scene_info["path"]
            self.nodes = self.scene.get("nodes", [])
            self.current_node_index = 0
            self.background_path = ""
            self.visible_characters.clear()
            self.placements.clear()
            
            self._update_scene_state()
            self.show_browser = False
            self.status_message = f"Loaded: {scene_info['relative_path']}"
            self.status_timer = 3.0
            
        except Exception as e:
            self.status_message = f"Error loading scene: {str(e)}"
            self.status_timer = 3.0

    def _update_scene_state(self):
        """Process all nodes up to current index to build scene state"""
        if not self.scene or not self.nodes:
            return
        
        self.visible_characters.clear()
        self.background_path = ""
        
        for i in range(self.current_node_index + 1):
            if i >= len(self.nodes):
                break
            node = self.nodes[i]
            node_id = node.get("id")
            
            if node.get("type") == "action":
                action = node.get("action")
                
                if action == "set_bg":
                    self.background_path = node.get("background", "")
                
                elif action == "show_character":
                    char_id = node.get("character", "unknown")
                    pose = node.get("pose", "default")
                    slot = node.get("position", "center")
                    
                    if node_id in self.placements and char_id in self.placements[node_id]:
                        saved = self.placements[node_id][char_id]
                        x, y = saved["x"], saved["y"]
                        slot = saved["slot"]
                    else:
                        x, y = self._slot_to_point(slot)
                    
                    self.visible_characters[char_id] = {
                        "character": char_id,
                        "pose": pose,
                        "slot": slot,
                        "x": x,
                        "y": y,
                    }
                
                elif action == "hide_character":
                    char_id = node.get("character")
                    if char_id in self.visible_characters:
                        del self.visible_characters[char_id]

    def _get_current_node(self):
        """Get current node data"""
        if 0 <= self.current_node_index < len(self.nodes):
            return self.nodes[self.current_node_index]
        return None

    def _save_current_placements(self):
        """Save current character placements for this node"""
        node = self._get_current_node()
        if not node:
            return
        
        node_id = node.get("id")
        if node_id not in self.placements:
            self.placements[node_id] = {}
        
        for char_id, char_data in self.visible_characters.items():
            self.placements[node_id][char_id] = {
                "x": char_data["x"],
                "y": char_data["y"],
                "slot": char_data["slot"]
            }

    def _next_node(self):
        """Advance to next node"""
        self._save_current_placements()
        
        if self.current_node_index < len(self.nodes) - 1:
            self.current_node_index += 1
            self._update_scene_state()
            self.status_message = f"Node {self.current_node_index + 1}/{len(self.nodes)}"
            self.status_timer = 2.0

    def _prev_node(self):
        """Go to previous node"""
        if self.current_node_index > 0:
            self.current_node_index -= 1
            self._update_scene_state()
            self.status_message = f"Node {self.current_node_index + 1}/{len(self.nodes)}"
            self.status_timer = 2.0

    def handle_event(self, event):
        # Handle scene browser events
        if self.show_browser:
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_UP:
                    self.selected_scene_index = max(0, self.selected_scene_index - 1)
                elif event.key == pygame.K_DOWN:
                    self.selected_scene_index = min(len(self.available_scenes) - 1, self.selected_scene_index + 1)
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    if self.available_scenes:
                        self._load_scene(self.available_scenes[self.selected_scene_index])
                elif event.key == pygame.K_r:
                    # Refresh scene list
                    self.available_scenes = self._find_scene_files()
                    self.selected_scene_index = 0
                    self.status_message = "Scene list refreshed"
                    self.status_timer = 2.0
                elif event.key == pygame.K_ESCAPE:
                    if self.scene:
                        self.show_browser = False
            elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                # Check if clicking on a scene in the browser
                browser_rect = self._get_browser_rect()
                list_y = browser_rect.y + 100
                item_height = 60
                
                for i, scene_info in enumerate(self.available_scenes):
                    item_rect = pygame.Rect(
                        browser_rect.x + 20,
                        list_y + i * item_height - self.browser_scroll,
                        browser_rect.width - 40,
                        item_height - 5
                    )
                    if item_rect.collidepoint(event.pos) and browser_rect.colliderect(item_rect):
                        self.selected_scene_index = i
                        self._load_scene(scene_info)
                        break
            elif event.type == pygame.MOUSEWHEEL:
                self.browser_scroll = max(0, self.browser_scroll - event.y * 30)
            return
        
        # Handle placement editor events
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            for char_id, char_data in self.visible_characters.items():
                rect = self._character_rect(char_data)
                if rect.collidepoint(event.pos):
                    self.selected_character = char_id
                    self.dragging = True
                    self.drag_offset = (
                        event.pos[0] - char_data["x"],
                        event.pos[1] - char_data["y"]
                    )
                    break
        elif event.type == pygame.MOUSEBUTTONUP and event.button == 1:
            if self.dragging and self.selected_character:
                char_data = self.visible_characters[self.selected_character]
                char_data["slot"] = self._slot_from_position(char_data["x"])
                self._save_current_placements()
            self.dragging = False
        elif event.type == pygame.MOUSEMOTION and self.dragging and self.selected_character:
            self._drag_selected_character(event.pos)
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_RIGHT or event.key == pygame.K_SPACE:
                self._next_node()
            elif event.key == pygame.K_LEFT:
                self._prev_node()
            elif event.key == pygame.K_s and pygame.key.get_mods() & pygame.KMOD_CTRL:
                self._save_layout()
            elif event.key == pygame.K_l and pygame.key.get_mods() & pygame.KMOD_CTRL:
                # Open scene browser
                self.show_browser = True
                self.selected_scene_index = 0
                self.browser_scroll = 0
            elif event.key == pygame.K_ESCAPE:
                # Open scene browser
                self.show_browser = True
                self.selected_scene_index = 0
                self.browser_scroll = 0

    def _drag_selected_character(self, pos):
        if not self.selected_character:
            return
        char_data = self.visible_characters[self.selected_character]
        new_x = pos[0] - self.drag_offset[0]
        new_y = pos[1] - self.drag_offset[1]
        padding = 80
        new_x = max(self.stage_rect.x + padding, min(self.stage_rect.right - padding, new_x))
        new_y = max(self.stage_rect.y + padding, min(self.stage_rect.bottom - padding, new_y))
        char_data["x"] = new_x
        char_data["y"] = new_y

    def _slot_to_point(self, slot: str):
        if slot == "far_left":
            x = self.stage_rect.x + self.stage_rect.width * 0.1
        elif slot == "left":
            x = self.stage_rect.x + self.stage_rect.width * 0.25
        elif slot == "right":
            x = self.stage_rect.x + self.stage_rect.width * 0.75
        elif slot == "far_right":
            x = self.stage_rect.x + self.stage_rect.width * 0.9
        else:
            x = self.stage_rect.centerx
        y = self.stage_rect.bottom - 120
        return x, y

    def _slot_from_position(self, x: float) -> str:
        width = self.stage_rect.width
        stage_x = self.stage_rect.x
        
        if x < stage_x + width * 0.2:
            return "far_left"
        elif x < stage_x + width * 0.4:
            return "left"
        elif x < stage_x + width * 0.6:
            return "center"
        elif x < stage_x + width * 0.8:
            return "right"
        else:
            return "far_right"

    def _character_rect(self, character: Dict) -> pygame.Rect:
        width = 160
        height = 260
        x = character["x"] - width // 2
        y = character["y"] - height
        return pygame.Rect(x, y, width, height)

    def _save_layout(self):
        export_dir = ensure_export_dir(self.project_root, "placements")
        path = export_dir / f"{self.scene_id}_placement.json"
        
        payload = {
            "scene_id": self.scene_id,
            "placements": {}
        }
        
        for node_id, chars in self.placements.items():
            payload["placements"][node_id] = {}
            for char_id, placement in chars.items():
                payload["placements"][node_id][char_id] = {
                    "x": placement["x"],
                    "y": placement["y"],
                    "slot": placement["slot"]
                }
        
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
        self.status_message = f"Saved placement to {path.relative_to(self.project_root)}"
        self.status_timer = 3.0

    def update(self, dt):
        if self.status_timer > 0:
            self.status_timer -= dt
        else:
            self.status_message = ""

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        
        if self.show_browser:
            self._draw_scene_browser(surface)
        else:
            self.stage_rect = self._compute_stage_rect()
            self._draw_header(surface)
            self._draw_stage(surface)
            self._draw_sidebar(surface)
            self._draw_controls(surface)
        
        self._draw_status(surface)

    def _get_browser_rect(self):
        """Get the browser panel rect."""
        width = min(800, self.rect.width - 100)
        height = min(600, self.rect.height - 100)
        x = (self.rect.width - width) // 2
        y = (self.rect.height - height) // 2
        return pygame.Rect(x, y, width, height)
    
    def _draw_scene_browser(self, surface):
        """Draw scene file browser."""
        browser_rect = self._get_browser_rect()
        
        # Draw overlay
        overlay = pygame.Surface((self.rect.width, self.rect.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        surface.blit(overlay, (0, 0))
        
        # Draw browser panel
        pygame.draw.rect(surface, self.theme.bg_medium, browser_rect, border_radius=12)
        pygame.draw.rect(surface, self.theme.border, browser_rect, 2, border_radius=12)
        
        # Title
        title_surf, _ = self.title_font.render("Select Scene", self.theme.text_primary)
        title_rect = title_surf.get_rect(centerx=browser_rect.centerx, y=browser_rect.y + 20)
        surface.blit(title_surf, title_rect)
        
        # Instructions
        if self.available_scenes and self.available_scenes[0]["path"]:
            instructions = "↑↓ to navigate  |  Enter/Click to load  |  R to refresh  |  Esc to cancel"
        else:
            instructions = "No scene files found. Press R to refresh."
        
        inst_surf, _ = self.small_font.render(instructions, self.theme.text_secondary)
        inst_rect = inst_surf.get_rect(centerx=browser_rect.centerx, y=browser_rect.y + 60)
        surface.blit(inst_surf, inst_rect)
        
        # Scene list
        list_y = browser_rect.y + 100
        list_height = browser_rect.height - 120
        item_height = 60
        
        # Clamp scroll
        max_scroll = max(0, len(self.available_scenes) * item_height - list_height)
        self.browser_scroll = max(0, min(self.browser_scroll, max_scroll))
        
        # Create clipping area for scene list
        list_rect = pygame.Rect(browser_rect.x + 10, list_y, browser_rect.width - 20, list_height)
        surface.set_clip(list_rect)
        
        for i, scene_info in enumerate(self.available_scenes):
            item_y = list_y + i * item_height - self.browser_scroll
            
            # Skip if not visible
            if item_y + item_height < list_y or item_y > list_y + list_height:
                continue
            
            item_rect = pygame.Rect(
                browser_rect.x + 20,
                item_y,
                browser_rect.width - 40,
                item_height - 5
            )
            
            # Highlight selected
            if i == self.selected_scene_index:
                pygame.draw.rect(surface, self.theme.accent_blue, item_rect, border_radius=6)
            else:
                pygame.draw.rect(surface, self.theme.bg_light, item_rect, border_radius=6)
            
            pygame.draw.rect(surface, self.theme.border, item_rect, 1, border_radius=6)
            
            # Scene info
            path_surf, _ = self.small_font.render(
                scene_info["relative_path"],
                self.theme.text_primary
            )
            id_surf, _ = self.small_font.render(
                f"ID: {scene_info['scene_id']}",
                self.theme.text_secondary
            )
            nodes_surf, _ = self.small_font.render(
                f"Nodes: {scene_info['node_count']}",
                self.theme.text_disabled
            )
            
            surface.blit(path_surf, (item_rect.x + 10, item_rect.y + 8))
            surface.blit(id_surf, (item_rect.x + 10, item_rect.y + 26))
            surface.blit(nodes_surf, (item_rect.x + 10, item_rect.y + 44))
        
        surface.set_clip(None)
        
        # Scrollbar
        if len(self.available_scenes) * item_height > list_height:
            scrollbar_height = max(20, int(list_height * (list_height / (len(self.available_scenes) * item_height))))
            scrollbar_y = list_y + int((self.browser_scroll / max_scroll) * (list_height - scrollbar_height))
            scrollbar_rect = pygame.Rect(browser_rect.right - 15, scrollbar_y, 8, scrollbar_height)
            pygame.draw.rect(surface, self.theme.accent_blue, scrollbar_rect, border_radius=4)

    def _draw_header(self, surface):
        title_surf, _ = self.title_font.render("Scene Placement", self.theme.text_primary)
        surface.blit(title_surf, (20, 20))
        
        info = f"Scene: {self.scene_id}  |  Node {self.current_node_index + 1}/{len(self.nodes)}"
        info_surf, _ = self.font.render(info, self.theme.text_secondary)
        surface.blit(info_surf, (20, 60))
        
        node = self._get_current_node()
        if node:
            node_type = node.get("type", "unknown")
            node_id = node.get("id", "unknown")
            node_info = f"Type: {node_type}  |  ID: {node_id}"
            
            if node_type == "dialogue":
                speaker = node.get("speaker", "")
                text = node.get("text", "")[:50]
                node_info += f"  |  {speaker}: {text}..."
            elif node_type == "narration":
                text = node.get("text", "")[:50]
                node_info += f"  |  {text}..."
            elif node_type == "action":
                action = node.get("action", "")
                node_info += f"  |  Action: {action}"
            
            node_surf, _ = self.small_font.render(node_info, self.theme.text_secondary)
            surface.blit(node_surf, (20, 90))

    def _draw_stage(self, surface):
        pygame.draw.rect(surface, self.theme.bg_medium, self.stage_rect, border_radius=12)
        pygame.draw.rect(surface, self.theme.border, self.stage_rect, 2, border_radius=12)

        bg_label = f"BG: {self.background_path}" if self.background_path else "No background"
        bg_surf, _ = self.small_font.render(bg_label, self.theme.text_secondary)
        surface.blit(bg_surf, (self.stage_rect.x + 10, self.stage_rect.y + 10))

        floor_rect = pygame.Rect(self.stage_rect.x, self.stage_rect.bottom - 60, self.stage_rect.width, 60)
        pygame.draw.rect(surface, (50, 50, 50), floor_rect, border_radius=0)

        slot_positions = {
            "far_left": 0.1,
            "left": 0.25,
            "center": 0.5,
            "right": 0.75,
            "far_right": 0.9
        }
        
        for slot_name, ratio in slot_positions.items():
            x = self.stage_rect.x + self.stage_rect.width * ratio
            pygame.draw.line(surface, self.theme.border, (x, floor_rect.y), (x, floor_rect.bottom), 1)
            label_surf, _ = self.small_font.render(slot_name, self.theme.text_disabled)
            surface.blit(label_surf, (x - 30, floor_rect.y + 5))

        for char_id, char in self.visible_characters.items():
            rect = self._character_rect(char)
            color = self._character_color(char_id)
            
            if char_id == self.selected_character:
                highlight_rect = rect.inflate(8, 8)
                pygame.draw.rect(surface, self.theme.accent_blue, highlight_rect, border_radius=10)
            
            pygame.draw.rect(surface, color, rect, border_radius=8)
            pygame.draw.rect(surface, self.theme.border, rect, 2, border_radius=8)

            name = char_id.title()
            pose = char.get("pose", "default")
            slot = char.get("slot", "center")
            
            y = rect.y + 8
            name_surf, _ = self.small_font.render(name, self.theme.text_primary)
            pose_surf, _ = self.small_font.render(f"Pose: {pose}", self.theme.text_secondary)
            slot_surf, _ = self.small_font.render(f"Slot: {slot}", self.theme.text_disabled)
            
            surface.blit(name_surf, (rect.x + 8, y))
            surface.blit(pose_surf, (rect.x + 8, y + 18))
            surface.blit(slot_surf, (rect.x + 8, rect.bottom - 24))

        instruction = "Drag characters to reposition. Slots update automatically."
        inst_surf, _ = self.small_font.render(instruction, self.theme.text_secondary)
        surface.blit(inst_surf, (self.stage_rect.x + 10, self.stage_rect.bottom - 80))

    def _draw_sidebar(self, surface):
        panel_rect = pygame.Rect(20, 130, 280, 500)
        pygame.draw.rect(surface, self.theme.bg_medium, panel_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel_rect, 1, border_radius=8)

        header_surf, _ = self.font.render("Visible Characters", self.theme.text_primary)
        surface.blit(header_surf, (panel_rect.x + 10, panel_rect.y + 10))

        if not self.visible_characters:
            no_chars_surf, _ = self.small_font.render("No characters visible", self.theme.text_disabled)
            surface.blit(no_chars_surf, (panel_rect.x + 10, panel_rect.y + 40))
            return

        y = panel_rect.y + 40
        for char_id, char_data in self.visible_characters.items():
            row = pygame.Rect(panel_rect.x + 10, y, panel_rect.width - 20, 70)
            is_active = char_id == self.selected_character
            color = self.theme.accent_blue if is_active else self.theme.bg_light
            pygame.draw.rect(surface, color, row, border_radius=6)
            pygame.draw.rect(surface, self.theme.border, row, 1, border_radius=6)

            name_surf, _ = self.small_font.render(char_id.title(), self.theme.text_primary)
            pose_surf, _ = self.small_font.render(f"Pose: {char_data.get('pose', 'default')}", self.theme.text_secondary)
            slot_surf, _ = self.small_font.render(f"Slot: {char_data.get('slot', 'center')}", self.theme.text_secondary)
            pos_surf, _ = self.small_font.render(f"Pos: ({int(char_data['x'])}, {int(char_data['y'])})", self.theme.text_disabled)

            surface.blit(name_surf, (row.x + 10, row.y + 6))
            surface.blit(pose_surf, (row.x + 10, row.y + 24))
            surface.blit(slot_surf, (row.x + 10, row.y + 42))
            surface.blit(pos_surf, (row.x + 10, row.y + 60))
            y += 80

    def _draw_controls(self, surface):
        panel_rect = pygame.Rect(20, 650, 280, 150)
        pygame.draw.rect(surface, self.theme.bg_medium, panel_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel_rect, 1, border_radius=8)

        header_surf, _ = self.font.render("Navigation", self.theme.text_primary)
        surface.blit(header_surf, (panel_rect.x + 10, panel_rect.y + 10))

        controls = [
            "→ / Space - Next line",
            "← - Previous line",
            "Drag - Move character",
            "Ctrl+S - Export JSON",
            "Ctrl+L / Esc - Scene browser"
        ]

        y = panel_rect.y + 35
        for control in controls:
            surf, _ = self.small_font.render(control, self.theme.text_secondary)
            surface.blit(surf, (panel_rect.x + 10, y))
            y += 22

    def _draw_status(self, surface):
        if not self.status_message:
            return
        status_surf, _ = self.font.render(self.status_message, self.theme.accent_green)
        surface.blit(status_surf, (320, self.rect.height - 40))

    def _character_color(self, name: str):
        base = abs(hash(name)) % 200
        return (80 + base % 100, 60 + (base // 2) % 120, 120)

    def _compute_stage_rect(self):
        width = max(400, self.rect.width - 360)
        height = max(260, self.rect.height - 220)
        return pygame.Rect(320, 120, width, height)

    def get_help_entries(self):
        """Provide help text for the main editor's help system."""
        return [
            ("Scene Browser", [
                "Ctrl+L or Esc - Open scene browser",
                "↑↓ - Navigate scene list",
                "Enter or Click - Load scene",
                "R - Refresh scene list",
                "Esc (in browser) - Cancel and return"
            ]),
            ("Scene Placement Controls", [
                "→ or Space - Advance to next node",
                "← - Go to previous node",
                "Click and drag character - Reposition character",
                "Ctrl+S - Export placements to JSON"
            ]),
            ("How It Works", [
                "Module searches for .json files in assets/data/scenes/",
                "Select a scene from the browser to begin",
                "Step through your scene node by node",
                "Characters appear/disappear as show/hide actions execute",
                "Drag characters to adjust their positions",
                "Positions snap to slots: far_left, left, center, right, far_right",
                "Placements are saved per-node for precise positioning"
            ]),
            ("Export Format", [
                "Creates {scene_id}_placement.json",
                "Organized by node_id for engine integration",
                "Contains x, y, and slot for each character at each node"
            ])
        ]

    def cleanup(self):
        pass