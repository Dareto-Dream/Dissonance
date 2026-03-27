"""
Story Editor Module

Visual node-based editor for creating VN scene files.
Supports all node types from the engine specification.
"""

import copy
import json
from pathlib import Path
from typing import Optional, Dict, List, Tuple

import pygame
import pygame.freetype

from modules.ui.widgets import Dropdown, TextInput


DEFAULT_STORY_CONFIG = {
    "default_node_type": "dialogue",
    "type_order": ["dialogue", "narration", "action", "choice", "if", "jump", "game", "end"],
    "float_fields": ["duration", "effect_speed", "effect_intensity", "effect_amplitude"],
    "json_fields": ["choices"],
    "bool_fields": ["auto_advance", "loop", "skippable", "persistent", "enabled"],
    "node_types": {
        "dialogue": {
            "fields": [
                {"key": "speaker", "label": "Speaker", "type": "text"},
                {"key": "character", "label": "Character", "type": "text"},
                {"key": "pose", "label": "Pose", "type": "text"},
                {"key": "text", "label": "Text", "type": "text"},
                {"key": "text_effect", "label": "Text Effect", "type": "text"},
                {"key": "effect_speed", "label": "Effect Speed", "type": "float"},
                {"key": "effect_intensity", "label": "Effect Intensity", "type": "float"},
                {"key": "effect_amplitude", "label": "Effect Amplitude", "type": "float"},
                {"key": "next", "label": "Next", "type": "text"},
            ]
        },
        "narration": {
            "fields": [
                {"key": "text", "label": "Text", "type": "text"},
                {"key": "text_effect", "label": "Text Effect", "type": "text"},
                {"key": "effect_speed", "label": "Effect Speed", "type": "float"},
                {"key": "next", "label": "Next", "type": "text"},
            ]
        },
        "action": {
            # Supported action types:
            #   set_bg            : background, transition, duration
            #   show_character    : character, pose, transition, duration
            #   hide_character    : character, transition, duration
            #   move_character    : character, slot, duration
            #   flip_character    : character, flipped
            #   bounce_character  : character, height, duration
            #   shake_character   : character, intensity, duration
            #   set_tint          : character (optional), color
            #   clear_tint        : character (optional)
            #   shake_screen      : intensity, duration
            #   flash             : color, duration
            #   glitch            : intensity, duration
            #   play_sound        : sound, volume
            #   play_music        : track, volume, transition, duration
            #   stop_music        : (no extra fields)
            #   fade_out_music    : duration
            #   set_variable      : variable, value, op (add/subtract/multiply/set)
            #   set_flag          : flag, value
            "fields": [
                {"key": "action",     "label": "Action Type",           "type": "text"},
                {"key": "background", "label": "Background (set_bg)",   "type": "text"},
                {"key": "character",  "label": "Character",             "type": "text"},
                {"key": "pose",       "label": "Pose",                  "type": "text"},
                {"key": "slot",       "label": "Slot (far_left/left/center_left/center/center_right/right/far_right)", "type": "text"},
                {"key": "flipped",    "label": "Flipped",               "type": "bool"},
                {"key": "height",     "label": "Height (bounce)",       "type": "float"},
                {"key": "intensity",  "label": "Intensity",             "type": "float"},
                {"key": "color",      "label": "Color (hex/#rrggbb)",   "type": "text"},
                {"key": "transition", "label": "Transition",            "type": "text"},
                {"key": "duration",   "label": "Duration (s)",          "type": "float"},
                {"key": "sound",      "label": "Sound (play_sound)",    "type": "text"},
                {"key": "track",      "label": "Track (play_music)",    "type": "text"},
                {"key": "volume",     "label": "Volume (0-1)",          "type": "float"},
                {"key": "variable",   "label": "Variable (set_variable)", "type": "text"},
                {"key": "flag",       "label": "Flag (set_flag)",       "type": "text"},
                {"key": "op",         "label": "Op (add/subtract/multiply/set)", "type": "text"},
                {"key": "value",      "label": "Value",                 "type": "text"},
                {"key": "text_effect","label": "Text Effect",           "type": "text"},
                {"key": "next",       "label": "Next",                  "type": "text"},
            ]
        },
        "choice": {
            "fields": [
                {"key": "choices", "label": "Choices (JSON)", "type": "json"},
            ]
        },
        "if": {
            "fields": [
                {"key": "condition", "label": "Condition", "type": "text"},
                {"key": "trueNode", "label": "True Node", "type": "text"},
                {"key": "falseNode", "label": "False Node", "type": "text"},
            ]
        },
        "jump": {
            "fields": [
                {"key": "target", "label": "Target Node", "type": "text"},
            ]
        },
        "game": {
            "fields": [
                {"key": "song", "label": "Song Id", "type": "text"},
                {"key": "next", "label": "Next Node", "type": "text"},
            ]
        },
        "end": {
            "fields": [
                {"key": "next_scene", "label": "Next Scene", "type": "text"},
            ]
        },
    },
}


class StoryNode:
    """Represents a single node in the story graph."""
    
    def __init__(self, node_id: str, node_type: str, x: float, y: float):
        self.id = node_id
        self.type = node_type
        self.x = x
        self.y = y
        self.data = {"id": node_id, "type": node_type}
        self.width = 180
        self.height = 80
    
    def get_rect(self) -> pygame.Rect:
        return pygame.Rect(self.x, self.y, self.width, self.height)
    
    def contains_point(self, x: float, y: float) -> bool:
        return self.get_rect().collidepoint(x, y)
    
    def get_color(self, theme):
        """Get color based on node type."""
        type_colors = {
            "dialogue": theme.node_dialogue,
            "narration": theme.node_narration,
            "action": theme.node_action,
            "choice": theme.node_choice,
            "if": theme.node_condition,
            "jump": theme.node_jump,
            "game": theme.node_game,
            "end": theme.node_end
        }
        return type_colors.get(self.type, theme.bg_light)
    
    def get_connection_point(self) -> Tuple[float, float]:
        """Get the center-right point for connections."""
        return (self.x + self.width, self.y + self.height // 2)
    
    def get_input_point(self) -> Tuple[float, float]:
        """Get the center-left point for incoming connections."""
        return (self.x, self.y + self.height // 2)


class StoryEditor:
    """Visual story editor with node graph."""
    
    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = Path(project_root)
        self.config = self._load_config()
        self.node_types = self.config.get("node_types", {})
        self.node_type_order = self.config.get("type_order") or sorted(self.node_types.keys())
        if not self.node_type_order:
            self.node_type_order = ["dialogue"]
        self.default_node_type = self.config.get("default_node_type", self.node_type_order[0])
        self.float_fields = set(self.config.get("float_fields", []))
        self.json_fields = set(self.config.get("json_fields", []))
        self.bool_fields = set(self.config.get("bool_fields", []))
        
        # Fonts
        self.font = pygame.freetype.SysFont("Arial", 12)
        self.title_font = pygame.freetype.SysFont("Arial", 14, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 10)
        
        # Scene data
        self.scene_id = "new_scene"
        self.start_node = None
        self.nodes: Dict[str, StoryNode] = {}
        
        # Camera
        self.camera_x = 0
        self.camera_y = 0
        self.zoom = 1.0
        
        # Interaction state
        self.selected_node = None
        self.dragging_node = None
        self.drag_offset_x = 0
        self.drag_offset_y = 0
        self.panning = False
        self.pan_start_x = 0
        self.pan_start_y = 0
        self.drag_moved = False
        
        # UI state
        self.show_grid = True
        self.show_node_ids = True
        
        # Toolbar area
        self.toolbar_height = 50
        self.mouse_pos = (0, 0)
        
        # Property editing
        self.property_inputs: List[Dict] = []
        self.property_node_id: Optional[str] = None
        self.property_apply_rect = None
        self.property_revert_rect = None
        self.property_status = ""
        self.property_status_timer = 0.0
        self.property_status_color = self.theme.text_secondary
        self.dropdown_overlays: List[Dropdown] = []
        
        # Context menu / linking
        self.context_menu = {"visible": False, "rect": None, "items": []}
        self.link_mode = None
        
        # Undo/redo history
        self.history: List[Dict] = []
        self.future: List[Dict] = []
        self.max_history = 50
        
        # Create sample nodes and capture baseline history
        self._create_sample_scene()
        self._record_history(force=True)

    def _load_config(self) -> Dict:
        config_path = Path(__file__).with_name("config.json")
        base = copy.deepcopy(DEFAULT_STORY_CONFIG)
        if config_path.exists():
            try:
                with open(config_path, "r", encoding="utf-8") as handle:
                    data = json.load(handle)
                base = self._merge_config(base, data)
            except Exception as exc:  # noqa: BLE001
                print(f"Failed to load story config: {exc}")
        return base

    @staticmethod
    def _merge_config(base: Dict, override: Dict) -> Dict:
        merged = copy.deepcopy(base)
        for key, value in override.items():
            if key == "node_types":
                merged.setdefault("node_types", {}).update(value)
            else:
                merged[key] = value
        return merged
    
    def _create_sample_scene(self):
        """Create a sample scene for demonstration."""
        # Clear existing
        self.nodes = {}
        
        # Create nodes
        n1 = StoryNode("n1", "action", 100, 100)
        n1.data.update({
            "action": "set_bg",
            "background": "assets/images/bg/classroom_day.png",
            "transition": "fade",
            "duration": 0.6,
            "next": "n2"
        })
        self.nodes["n1"] = n1
        
        n2 = StoryNode("n2", "narration", 350, 100)
        n2.data.update({
            "text": "The bell rings.",
            "next": "n3"
        })
        self.nodes["n2"] = n2
        
        n3 = StoryNode("n3", "dialogue", 600, 100)
        n3.data.update({
            "speaker": "Tiffany",
            "character": "tiffany",
            "pose": "default_smile",
            "text": "Welcome to the club!",
            "next": "n4"
        })
        self.nodes["n3"] = n3
        
        n4 = StoryNode("n4", "choice", 850, 100)
        n4.data.update({
            "choices": [
                {"text": "Thank you", "target": "n5a"},
                {"text": "Stay silent", "target": "n5b"}
            ]
        })
        self.nodes["n4"] = n4
        
        n5a = StoryNode("n5a", "dialogue", 850, 230)
        n5a.data.update({
            "speaker": "MC",
            "text": "Thank you for having me.",
            "next": "n6"
        })
        self.nodes["n5a"] = n5a
        
        n5b = StoryNode("n5b", "narration", 1050, 230)
        n5b.data.update({
            "text": "You nod quietly.",
            "next": "n6"
        })
        self.nodes["n5b"] = n5b
        
        n6 = StoryNode("n6", "end", 950, 360)
        n6.data.update({
            "next_scene": "act1_scene2"
        })
        self.nodes["n6"] = n6
        
        self.start_node = "n1"
    
    # History helpers -------------------------------------------------
    def _snapshot_state(self) -> Dict:
        """Capture current graph state for undo/redo."""
        node_snapshots = []
        for node_id in sorted(self.nodes.keys()):
            node = self.nodes[node_id]
            node_snapshots.append({
                "id": node.id,
                "type": node.type,
                "x": node.x,
                "y": node.y,
                "data": copy.deepcopy(node.data),
            })
        return {
            "scene_id": self.scene_id,
            "start": self.start_node,
            "nodes": node_snapshots,
        }
    
    def _restore_state(self, snapshot: Dict):
        """Restore state from snapshot without modifying history."""
        self.scene_id = snapshot.get("scene_id", self.scene_id)
        self.start_node = snapshot.get("start")
        restored_nodes: Dict[str, StoryNode] = {}
        for node_info in snapshot.get("nodes", []):
            node = StoryNode(
                node_info["id"],
                node_info.get("type", "dialogue"),
                node_info.get("x", 0),
                node_info.get("y", 0),
            )
            node.data = copy.deepcopy(node_info.get("data", {}))
            restored_nodes[node.id] = node
        self.nodes = restored_nodes
        self.selected_node = None
        self.dragging_node = None
        self._ensure_property_inputs(force=True)
    
    def _record_history(self, force: bool = False):
        """Append current state to history stack."""
        snapshot = self._snapshot_state()
        if not force and self.history and self.history[-1] == snapshot:
            return
        self.history.append(snapshot)
        if len(self.history) > self.max_history:
            self.history.pop(0)
        self.future.clear()
    
    def undo(self):
        """Revert to previous state."""
        if len(self.history) <= 1:
            return
        current = self.history.pop()
        self.future.append(current)
        previous = self.history[-1]
        self._restore_state(previous)
    
    def redo(self):
        """Re-apply a reverted state."""
        if not self.future:
            return
        snapshot = self.future.pop()
        self.history.append(snapshot)
        self._restore_state(snapshot)
    
    def handle_event(self, event):
        """Handle input events."""
        if hasattr(event, "pos"):
            self.mouse_pos = event.pos
        
        if self._handle_context_menu_event(event):
            return
        
        if self._handle_property_event(event):
            return
        
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # Left click
                if self.link_mode:
                    self._complete_link_at(event.pos)
                    return
                self._handle_left_click(event.pos)
            elif event.button == 2:  # Middle click
                self.panning = True
                self.pan_start_x = event.pos[0]
                self.pan_start_y = event.pos[1]
            elif event.button == 3:  # Right click
                self._handle_right_click(event.pos)
            elif event.button == 4:  # Scroll up
                self.zoom = min(2.0, self.zoom * 1.1)
            elif event.button == 5:  # Scroll down
                self.zoom = max(0.3, self.zoom / 1.1)
        
        elif event.type == pygame.MOUSEBUTTONUP:
            if event.button == 1:
                if self.dragging_node and self.drag_moved:
                    self._record_history()
                self.dragging_node = None
                self.drag_moved = False
            elif event.button == 2:
                self.panning = False
        
        elif event.type == pygame.MOUSEMOTION:
            if self.dragging_node:
                world_x, world_y = self.screen_to_world(event.pos[0], event.pos[1])
                new_x = world_x - self.drag_offset_x
                new_y = world_y - self.drag_offset_y
                if new_x != self.dragging_node.x or new_y != self.dragging_node.y:
                    self.dragging_node.x = new_x
                    self.dragging_node.y = new_y
                    self.drag_moved = True
            elif self.panning:
                dx = event.pos[0] - self.pan_start_x
                dy = event.pos[1] - self.pan_start_y
                self.camera_x -= dx / self.zoom
                self.camera_y -= dy / self.zoom
                self.pan_start_x = event.pos[0]
                self.pan_start_y = event.pos[1]
        
        elif event.type == pygame.KEYDOWN:
            mods = pygame.key.get_mods()
            if event.key == pygame.K_ESCAPE and self.link_mode:
                self.link_mode = None
                return
            if self._property_widget_has_focus():
                return
            if event.key == pygame.K_g:
                self.show_grid = not self.show_grid
            elif event.key == pygame.K_i:
                self.show_node_ids = not self.show_node_ids
            elif event.key == pygame.K_f:
                self._frame_all_nodes()
            elif event.key == pygame.K_s and mods & pygame.KMOD_CTRL:
                self.save_scene()
            elif event.key == pygame.K_l and mods & pygame.KMOD_CTRL:
                self.load_scene()
            elif event.key == pygame.K_n and mods & pygame.KMOD_CTRL:
                self._add_new_node()
            elif event.key == pygame.K_d and mods & pygame.KMOD_CTRL:
                self._duplicate_selected_node()
            elif event.key == pygame.K_z and mods & pygame.KMOD_CTRL:
                if mods & pygame.KMOD_SHIFT:
                    self.redo()
                else:
                    self.undo()
            elif event.key == pygame.K_y and mods & pygame.KMOD_CTRL:
                self.redo()
            elif event.key == pygame.K_DELETE and self.selected_node:
                self._delete_node(self.selected_node)
    
    def _handle_left_click(self, pos):
        """Handle left mouse click."""
        if pos[1] < self.toolbar_height:
            self._handle_toolbar_click(pos)
            return
        
        world_x, world_y = self.screen_to_world(pos[0], pos[1])
        
        # Check if clicking on a node
        clicked_node = None
        for node in self.nodes.values():
            if node.contains_point(world_x, world_y):
                clicked_node = node
                break
        
        if clicked_node:
            self.selected_node = clicked_node
            self.dragging_node = clicked_node
            self.drag_offset_x = world_x - clicked_node.x
            self.drag_offset_y = world_y - clicked_node.y
            self.drag_moved = False
        else:
            self.selected_node = None
        self._ensure_property_inputs()
    
    def _handle_right_click(self, pos):
        """Handle right mouse click for context menu."""
        if pos[1] < self.toolbar_height:
            return
        world_x, world_y = self.screen_to_world(pos[0], pos[1])
        clicked_node = None
        for node in self.nodes.values():
            if node.contains_point(world_x, world_y):
                clicked_node = node
                break
        self._show_context_menu(pos, clicked_node, world_pos=(world_x, world_y))
    
    def _handle_toolbar_click(self, pos):
        """Handle clicks on toolbar buttons."""
        # Define button positions
        button_width = 80
        button_height = 30
        button_y = 10
        button_x = 10
        spacing = 10
        
        buttons = [
            ("New", self._create_new_scene),
            ("Load", self.load_scene),
            ("Save", self.save_scene),
            ("Add Node", self._add_new_node),
            ("Export", self.export_json)
        ]
        
        for i, (label, callback) in enumerate(buttons):
            btn_rect = pygame.Rect(
                button_x + i * (button_width + spacing),
                button_y,
                button_width,
                button_height
            )
            if btn_rect.collidepoint(pos):
                callback()
                break
    
    def _generate_new_node_id(self) -> str:
        """Generate sequential node ids (n1, n2, ...)."""
        i = 1
        while f"n{i}" in self.nodes:
            i += 1
        return f"n{i}"
    
    def _generate_duplicate_id(self, base_id: str) -> str:
        """Generate unique id when duplicating a node."""
        suffix = 1
        candidate = f"{base_id}_copy"
        while candidate in self.nodes:
            candidate = f"{base_id}_copy{suffix}"
            suffix += 1
        return candidate
    
    def _add_new_node(self):
        """Add a new node to the scene."""
        node_id = self._generate_new_node_id()
        x = -self.camera_x + 100
        y = -self.camera_y + 100
        
        node_type = self.default_node_type if self.default_node_type in self.node_types else "dialogue"
        new_node = StoryNode(node_id, node_type, x, y)
        new_node.data.update({
            "speaker": "Character",
            "text": "New dialogue",
            "next": ""
        })
        self.nodes[node_id] = new_node
        self.selected_node = new_node
        self._record_history()
        self._ensure_property_inputs(force=True)
    
    def _add_node_at_position(self, x, y):
        """Add a new node at specific world position."""
        node_id = self._generate_new_node_id()
        node_type = self.default_node_type if self.default_node_type in self.node_types else "dialogue"
        new_node = StoryNode(node_id, node_type, x, y)
        new_node.data.update({
            "speaker": "Character",
            "text": "New dialogue",
            "next": ""
        })
        self.nodes[node_id] = new_node
        self.selected_node = new_node
        self._record_history()
        self._ensure_property_inputs(force=True)
    
    def _delete_node(self, node_id):
        """Delete a node from the scene."""
        if node_id in self.nodes:
            del self.nodes[node_id]
            self.selected_node = None
            self._record_history()
            self._ensure_property_inputs(force=True)
            if self.link_mode and self.link_mode.get("source") == node_id:
                self.link_mode = None
    
    def _duplicate_selected_node(self):
        """Duplicate currently selected node."""
        if not self.selected_node:
            return
        source = self.selected_node
        new_id = self._generate_duplicate_id(source.id)
        duplicate = StoryNode(new_id, source.type, source.x + 40, source.y + 40)
        duplicate.data = copy.deepcopy(source.data)
        duplicate.data["id"] = new_id
        self.nodes[new_id] = duplicate
        self.selected_node = duplicate
        self._record_history()
        self._ensure_property_inputs(force=True)

    def _duplicate_node_by_id(self, node_id: str):
        node = self.nodes.get(node_id)
        if not node:
            return
        self.selected_node = node
        self._duplicate_selected_node()

    # Property panel helpers -------------------------------------------------
    def _ensure_property_inputs(self, force: bool = False):
        if not self.selected_node:
            self.property_inputs = []
            self.property_node_id = None
            return
        if not force and self.property_inputs and self.property_node_id == self.selected_node.id:
            return
        self.property_node_id = self.selected_node.id
        self._build_property_inputs()

    def _node_panel_rect(self):
        panel_width = 340
        panel_height = self.rect.height - self.toolbar_height - 20
        panel_x = self.rect.width - panel_width - 10
        panel_y = self.toolbar_height + 10
        return pygame.Rect(panel_x, panel_y, panel_width, panel_height)

    def _property_schema_for_node(self, node: StoryNode):
        schema = [
            {"key": "id", "label": "Node ID", "type": "text", "placeholder": "Unique id"},
            {"key": "type", "label": "Type", "type": "choice", "placeholder": "dialogue"},
        ]
        seen = {field["key"] for field in schema}
        type_meta = self.node_types.get(node.type, {})
        for field in type_meta.get("fields", []):
            key = field["key"]
            if key in seen:
                continue
            schema.append({
                "key": key,
                "label": field.get("label", key.replace("_", " ").title()),
                "type": field.get("type", "text"),
                "placeholder": field.get("placeholder", key),
                "options": field.get("options"),
            })
            seen.add(key)
        for data_key, value in node.data.items():
            if data_key in seen:
                continue
            inferred_type = "json" if isinstance(value, (list, dict)) or data_key in self.json_fields else "float" if data_key in self.float_fields else "bool" if isinstance(value, bool) or data_key in self.bool_fields else "text"
            schema.append({
                "key": data_key,
                "label": data_key.replace("_", " ").title(),
                "type": inferred_type,
                "placeholder": data_key,
            })
            seen.add(data_key)
        return schema

    def _build_property_inputs(self):
        if not self.selected_node:
            self.property_inputs = []
            return
        panel_rect = self._node_panel_rect()
        schema = self._property_schema_for_node(self.selected_node)
        self.property_inputs = []
        y = panel_rect.y + 50
        node = self.selected_node
        for field in schema:
            key = field["key"]
            value = node.data.get(key, "")
            if key == "id":
                value = node.id
            elif key == "type":
                value = node.type
            widget_rect = pygame.Rect(panel_rect.x + 10, y + 20, panel_rect.width - 20, 28)
            field_type = field["type"]
            if field_type == "choice" and key == "type":
                widget = Dropdown(widget_rect, self.font, self.node_type_order, value=value or node.type, placeholder="Node type")
                kind = "dropdown"
            elif field_type == "bool":
                if isinstance(value, str) and value:
                    current_value = value.lower()
                else:
                    current_value = "true" if value else "false"
                widget = Dropdown(widget_rect, self.font, ["true", "false"], value=current_value, placeholder="false")
                kind = "dropdown"
            elif field_type == "choice":
                options = field.get("options") or []
                widget = Dropdown(widget_rect, self.font, options, value=value if value in options else (options[0] if options else ""), placeholder=field.get("placeholder", "Select"))
                kind = "dropdown"
            else:
                if isinstance(value, (dict, list)):
                    text_value = json.dumps(value)
                elif value is None:
                    text_value = ""
                else:
                    text_value = str(value)
                widget = TextInput(widget_rect, self.font, placeholder=field.get("placeholder", ""), text=text_value)
                kind = "text"
            self.property_inputs.append({
                "key": key,
                "label": field["label"],
                "type": field_type,
                "widget": widget,
                "kind": kind,
            })
            y += 60
        self.property_apply_rect = pygame.Rect(panel_rect.x + 10, panel_rect.bottom - 40, 120, 28)
        self.property_revert_rect = pygame.Rect(panel_rect.x + 140, panel_rect.bottom - 40, 120, 28)

    def _handle_property_event(self, event):
        if not self.selected_node or not self.property_inputs:
            return False
        panel_rect = self._node_panel_rect()
        consumed = False
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.property_apply_rect and self.property_apply_rect.collidepoint(event.pos):
                self._apply_property_changes()
                return True
            if self.property_revert_rect and self.property_revert_rect.collidepoint(event.pos):
                self._build_property_inputs()
                return True
            if panel_rect.collidepoint(event.pos):
                consumed = True
        for field in self.property_inputs:
            widget = field["widget"]
            if field["kind"] == "text":
                before_active = widget.active
                if widget.handle_event(event):
                    consumed = True
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    if before_active or widget.rect.collidepoint(event.pos):
                        consumed = True
                elif event.type == pygame.KEYDOWN and widget.active:
                    consumed = True
            else:
                if widget.handle_event(event):
                    consumed = True
        return consumed

    def _apply_property_changes(self):
        if not self.selected_node:
            return
        node = self.selected_node
        target_id = node.id
        updated_data = copy.deepcopy(node.data)
        for field in self.property_inputs:
            key = field["key"]
            widget = field["widget"]
            raw = widget.get_value() if hasattr(widget, "get_value") else ""
            if key == "id":
                if raw and raw != node.id:
                    if not self._rename_node(node.id, raw):
                        return
                    node = self.nodes[raw]
                    updated_data = copy.deepcopy(node.data)
                    target_id = raw
                continue
            if key == "type":
                if raw and raw in self.node_types:
                    node.type = raw
                    updated_data["type"] = raw
                elif raw:
                    self._set_property_status("Unknown node type", error=True)
                    return
                continue
            if not raw:
                updated_data.pop(key, None)
                continue
            try:
                value = self._parse_field_value(key, raw, field.get("type"))
            except ValueError as exc:
                self._set_property_status(str(exc), error=True)
                return
            updated_data[key] = value
        node.data = updated_data
        node.data["type"] = node.type
        self._set_property_status("Properties updated")
        self._record_history()
        self._ensure_property_inputs(force=True)

    def _parse_field_value(self, key: str, raw: str, field_type: str):
        if field_type == "json" or key in self.json_fields:
            try:
                return json.loads(raw)
            except json.JSONDecodeError as exc:  # noqa: BLE001
                raise ValueError(f"Invalid JSON for {key}: {exc}") from exc
        if field_type == "float" or key in self.float_fields:
            try:
                return float(raw)
            except ValueError as exc:
                raise ValueError(f"{key} must be a number") from exc
        if field_type == "bool" or key in self.bool_fields:
            return str(raw).lower() in {"true", "1", "yes", "on"}
        return raw

    def _rename_node(self, old_id: str, new_id: str) -> bool:
        if not new_id:
            self._set_property_status("Node ID cannot be empty", error=True)
            return False
        if new_id in self.nodes and new_id != old_id:
            self._set_property_status("Node ID already exists", error=True)
            return False
        if new_id == old_id:
            return True
        node = self.nodes.pop(old_id)
        node.id = new_id
        node.data["id"] = new_id
        self.nodes[new_id] = node
        if self.selected_node is node:
            self.selected_node = node
        if self.start_node == old_id:
            self.start_node = new_id
        for other in self.nodes.values():
            if other.data.get("next") == old_id:
                other.data["next"] = new_id
            if other.data.get("trueNode") == old_id:
                other.data["trueNode"] = new_id
            if other.data.get("falseNode") == old_id:
                other.data["falseNode"] = new_id
            if other.data.get("target") == old_id:
                other.data["target"] = new_id
            if "choices" in other.data:
                for choice in other.data["choices"]:
                    if choice.get("target") == old_id:
                        choice["target"] = new_id
        return True

    def _set_property_status(self, message: str, error: bool = False):
        self.property_status = message
        self.property_status_color = self.theme.accent_red if error else self.theme.accent_green
        self.property_status_timer = 3.0

    def _property_widget_has_focus(self) -> bool:
        for field in self.property_inputs:
            widget = field["widget"]
            if field["kind"] == "text" and getattr(widget, "active", False):
                return True
            if field["kind"] == "dropdown" and getattr(widget, "open", False):
                return True
        return False

    # Context menu / linking helpers -----------------------------------------
    def _handle_context_menu_event(self, event):
        menu = self.context_menu
        if not menu["visible"]:
            return False
        if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
            self._close_context_menu()
            return True
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1 and menu["rect"] and menu["rect"].collidepoint(event.pos):
                index = (event.pos[1] - menu["rect"].y) // menu["item_height"]
                if 0 <= index < len(menu["items"]):
                    action = menu["items"][index]["action"]
                    self._close_context_menu()
                    action()
                    return True
            self._close_context_menu()
            return True
        return False

    def _show_context_menu(self, pos, node: Optional[StoryNode], world_pos=None):
        items = []
        world_x, world_y = world_pos if world_pos else (0, 0)
        if node:
            self.selected_node = node
            self._ensure_property_inputs()
            items.append({"label": "Duplicate Node (Ctrl+D)", "action": lambda nid=node.id: self._duplicate_node_by_id(nid)})
            items.append({"label": "Delete Node (Del)", "action": lambda n=node: self._delete_node(n.id)})
            items.append({"label": "Set As Start Node", "action": lambda n=node: self._set_start_node(n.id)})
            if node.data.get("next") is not None or node.type not in {"choice", "end"}:
                items.append({"label": "Link Next →", "action": lambda n=node: self._start_link_mode(n.id, "next", "Link Next")})
            if node.type == "if":
                items.append({"label": "Link True Branch", "action": lambda n=node: self._start_link_mode(n.id, "trueNode", "Link True Branch")})
                items.append({"label": "Link False Branch", "action": lambda n=node: self._start_link_mode(n.id, "falseNode", "Link False Branch")})
            if node.type == "choice":
                choices = node.data.get("choices", [])
                for idx, choice in enumerate(choices):
                    label = choice.get("text") or f"Choice {idx + 1}"
                    items.append({
                        "label": f"Link Choice {idx + 1}: {label[:18]}",
                        "action": lambda n=node, i=idx: self._start_link_mode(n.id, "choices", f"Link Choice {i + 1}", choice_index=i),
                    })
        else:
            items.append({"label": "Add Dialogue Node Here", "action": lambda: self._add_node_at_position(world_x, world_y)})
        if not items:
            return
        width = max(self.font.get_rect(item["label"])[2] for item in items) + 20
        item_height = 28
        height = item_height * len(items)
        rect = pygame.Rect(pos[0], pos[1], width, height)
        rect.x = min(rect.x, self.rect.width - rect.width - 5)
        rect.y = min(rect.y, self.rect.height - rect.height - 5)
        rect.y = max(rect.y, self.toolbar_height)
        rect.x = max(rect.x, 0)
        self.context_menu = {
            "visible": True,
            "rect": rect,
            "items": items,
            "item_height": item_height,
        }

    def _close_context_menu(self):
        self.context_menu = {"visible": False, "rect": None, "items": []}

    def _set_start_node(self, node_id: str):
        if self.start_node == node_id:
            self._set_property_status("Already the start node")
            return
        self.start_node = node_id
        self._set_property_status(f"Start node set to {node_id}")
        self._record_history()

    def _start_link_mode(self, node_id: str, field: str, label: str, choice_index: Optional[int] = None):
        self.link_mode = {
            "source": node_id,
            "field": field,
            "label": label,
            "choice_index": choice_index,
        }
        self._set_property_status(f"{label}: select a target node")

    def _complete_link_at(self, pos):
        if not self.link_mode:
            return
        world_x, world_y = self.screen_to_world(pos[0], pos[1])
        target = None
        for node in self.nodes.values():
            if node.contains_point(world_x, world_y):
                target = node
                break
        if not target:
            return
        source = self.nodes.get(self.link_mode["source"])
        if not source:
            self.link_mode = None
            return
        field = self.link_mode["field"]
        if field == "choices":
            idx = self.link_mode.get("choice_index", 0)
            choices = source.data.setdefault("choices", [])
            while len(choices) <= idx:
                choices.append({"text": f"Choice {len(choices) + 1}", "target": ""})
            choices[idx]["target"] = target.id
        else:
            source.data[field] = target.id
        self.link_mode = None
        self._record_history()
        self._set_property_status(f"Linked {field} to {target.id}")
    
    def _create_new_scene(self):
        """Create a new empty scene."""
        self.nodes = {}
        self.start_node = None
        self.scene_id = "new_scene"
        self.selected_node = None
        self.camera_x = 0
        self.camera_y = 0
        self._record_history()
        self._ensure_property_inputs(force=True)
    
    def _frame_all_nodes(self):
        """Center camera on all nodes."""
        if not self.nodes:
            return
        
        min_x = min(node.x for node in self.nodes.values())
        max_x = max(node.x + node.width for node in self.nodes.values())
        min_y = min(node.y for node in self.nodes.values())
        max_y = max(node.y + node.height for node in self.nodes.values())
        
        center_x = (min_x + max_x) / 2
        center_y = (min_y + max_y) / 2
        
        self.camera_x = center_x - self.rect.width / (2 * self.zoom)
        self.camera_y = center_y - self.rect.height / (2 * self.zoom)
    
    def screen_to_world(self, screen_x, screen_y):
        """Convert screen coordinates to world coordinates."""
        world_x = (screen_x / self.zoom) + self.camera_x
        world_y = ((screen_y - self.toolbar_height) / self.zoom) + self.camera_y
        return world_x, world_y
    
    def world_to_screen(self, world_x, world_y):
        """Convert world coordinates to screen coordinates."""
        screen_x = (world_x - self.camera_x) * self.zoom
        screen_y = ((world_y - self.camera_y) * self.zoom) + self.toolbar_height
        return screen_x, screen_y
    
    def save_scene(self):
        """Save scene to JSON file."""
        scene_data = {
            "scene_id": self.scene_id,
            "start": self.start_node or "n1",
            "nodes": [node.data for node in self.nodes.values()]
        }
        
        output_path = self.project_root / "assets" / "data" / "scenes" / f"{self.scene_id}.json"
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(scene_data, f, indent=2)
        
        print(f"Scene saved: {output_path}")
    
    def load_scene(self):
        """Load scene from JSON file."""
        # For now, just use the sample scene
        # In a full implementation, this would open a file dialog
        self._create_sample_scene()
        self._record_history()
        print("Sample scene loaded")
    
    def export_json(self):
        """Export scene JSON to output directory."""
        scene_data = {
            "scene_id": self.scene_id,
            "start": self.start_node or "n1",
            "nodes": [node.data for node in self.nodes.values()]
        }
        
        output_path = Path("/mnt/user-data/outputs") / f"{self.scene_id}.json"
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(scene_data, f, indent=2)
        
        print(f"Scene exported: {output_path}")
    
    def update(self, dt):
        """Update animation state."""
        if self.property_status_timer > 0:
            self.property_status_timer -= dt
            if self.property_status_timer <= 0:
                self.property_status = ""
        for field in self.property_inputs:
            if field["kind"] == "text":
                field["widget"].update(dt)
    
    def draw(self, surface):
        """Draw the story editor interface."""
        # Clear background
        surface.fill(self.theme.bg_dark)
        
        # Draw toolbar
        self.draw_toolbar(surface)
        
        # Create canvas surface for node graph
        canvas_rect = pygame.Rect(0, self.toolbar_height, self.rect.width, self.rect.height - self.toolbar_height)
        canvas = surface.subsurface(canvas_rect)
        
        # Draw grid
        if self.show_grid:
            self.draw_grid(canvas)
        
        # Draw connections
        self.draw_connections(canvas)
        
        # Draw nodes
        self.draw_nodes(canvas)
        
        if self.link_mode:
            self.draw_link_preview(canvas)
        
        # Draw node details panel
        if self.selected_node:
            self.draw_node_details(surface)

        self._draw_dropdown_overlays(surface)
        
        # Draw hints
        self.draw_hints(surface)
        
        if self.context_menu["visible"]:
            self._draw_context_menu(surface)
    
    def draw_toolbar(self, surface):
        """Draw top toolbar."""
        toolbar_rect = pygame.Rect(0, 0, self.rect.width, self.toolbar_height)
        pygame.draw.rect(surface, self.theme.bg_medium, toolbar_rect)
        pygame.draw.line(surface, self.theme.border, (0, self.toolbar_height), (self.rect.width, self.toolbar_height), 2)
        
        # Buttons
        button_width = 80
        button_height = 30
        button_y = 10
        button_x = 10
        spacing = 10
        
        buttons = [
            ("New", self.theme.accent_blue),
            ("Load", self.theme.accent_green),
            ("Save", self.theme.accent_green),
            ("Add Node", self.theme.accent_purple),
            ("Export", self.theme.accent_yellow)
        ]
        
        mouse_pos = pygame.mouse.get_pos()
        
        for i, (label, color) in enumerate(buttons):
            btn_rect = pygame.Rect(
                button_x + i * (button_width + spacing),
                button_y,
                button_width,
                button_height
            )
            
            is_hover = btn_rect.collidepoint(mouse_pos)
            btn_color = color if is_hover else self.theme.button_normal
            
            pygame.draw.rect(surface, btn_color, btn_rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, btn_rect, 1, border_radius=4)
            
            text_surf, text_rect = self.font.render(label, self.theme.text_primary)
            text_rect.center = btn_rect.center
            surface.blit(text_surf, text_rect)
        
        # Scene info
        info_x = button_x + len(buttons) * (button_width + spacing) + 20
        info_text = f"Scene: {self.scene_id} | Nodes: {len(self.nodes)} | Zoom: {self.zoom:.1f}x"
        info_surf, _ = self.font.render(info_text, self.theme.text_secondary)
        surface.blit(info_surf, (info_x, button_y + 8))
    
    def draw_grid(self, surface):
        """Draw background grid."""
        grid_size = 50
        
        # Calculate visible range
        start_x = int(self.camera_x / grid_size) * grid_size
        start_y = int(self.camera_y / grid_size) * grid_size
        
        end_x = start_x + int(self.rect.width / self.zoom) + grid_size
        end_y = start_y + int(self.rect.height / self.zoom) + grid_size
        
        # Draw vertical lines
        x = start_x
        while x < end_x:
            screen_x, _ = self.world_to_screen(x, 0)
            color = self.theme.grid_major if x % (grid_size * 4) == 0 else self.theme.grid_line
            pygame.draw.line(surface, color, (screen_x, 0), (screen_x, self.rect.height), 1)
            x += grid_size
        
        # Draw horizontal lines
        y = start_y
        while y < end_y:
            _, screen_y = self.world_to_screen(0, y)
            color = self.theme.grid_major if y % (grid_size * 4) == 0 else self.theme.grid_line
            pygame.draw.line(surface, color, (0, screen_y), (self.rect.width, screen_y), 1)
            y += grid_size
    
    def draw_connections(self, surface):
        """Draw connections between nodes."""
        for node in self.nodes.values():
            # Get next node(s)
            next_ids = []
            
            if "next" in node.data and node.data["next"]:
                next_ids.append(node.data["next"])
            elif "choices" in node.data:
                for choice in node.data["choices"]:
                    if "target" in choice:
                        next_ids.append(choice["target"])
            elif "trueNode" in node.data:
                next_ids.append(node.data["trueNode"])
                if "falseNode" in node.data:
                    next_ids.append(node.data["falseNode"])
            
            # Draw connections
            for next_id in next_ids:
                if next_id in self.nodes:
                    self.draw_connection_line(surface, node, self.nodes[next_id])
    
    def draw_connection_line(self, surface, from_node, to_node):
        """Draw a Bezier curve connection between nodes."""
        start_x, start_y = from_node.get_connection_point()
        end_x, end_y = to_node.get_input_point()
        
        # Convert to screen space
        screen_start_x, screen_start_y = self.world_to_screen(start_x, start_y)
        screen_end_x, screen_end_y = self.world_to_screen(end_x, end_y)
        
        # Control points for Bezier curve
        ctrl_offset = 50 * self.zoom
        ctrl1_x = screen_start_x + ctrl_offset
        ctrl1_y = screen_start_y
        ctrl2_x = screen_end_x - ctrl_offset
        ctrl2_y = screen_end_y
        
        # Draw curve
        points = []
        steps = 20
        for i in range(steps + 1):
            t = i / steps
            t2 = t * t
            t3 = t2 * t
            mt = 1 - t
            mt2 = mt * mt
            mt3 = mt2 * mt
            
            x = mt3 * screen_start_x + 3 * mt2 * t * ctrl1_x + 3 * mt * t2 * ctrl2_x + t3 * screen_end_x
            y = mt3 * screen_start_y + 3 * mt2 * t * ctrl1_y + 3 * mt * t2 * ctrl2_y + t3 * screen_end_y
            points.append((x, y))
        
        if len(points) > 1:
            pygame.draw.lines(surface, self.theme.border, False, points, 2)
            
            # Draw arrow at end
            if len(points) >= 2:
                arrow_size = 8
                dx = points[-1][0] - points[-2][0]
                dy = points[-1][1] - points[-2][1]
                import math
                angle = math.atan2(dy, dx)
                
                arrow_p1 = (
                    points[-1][0] - arrow_size * math.cos(angle - math.pi / 6),
                    points[-1][1] - arrow_size * math.sin(angle - math.pi / 6)
                )
                arrow_p2 = (
                    points[-1][0] - arrow_size * math.cos(angle + math.pi / 6),
                    points[-1][1] - arrow_size * math.sin(angle + math.pi / 6)
                )
                
                pygame.draw.polygon(surface, self.theme.border, [points[-1], arrow_p1, arrow_p2])

    def draw_link_preview(self, surface):
        """Draw temporary link when user is connecting nodes."""
        if not self.link_mode:
            return
        source = self.nodes.get(self.link_mode["source"])
        if not source:
            return
        start_x, start_y = source.get_connection_point()
        screen_start_x, screen_start_y = self.world_to_screen(start_x, start_y)
        screen_start_y -= self.toolbar_height
        cursor_x = self.mouse_pos[0]
        cursor_y = self.mouse_pos[1] - self.toolbar_height
        cursor_x = max(0, min(surface.get_width(), cursor_x))
        cursor_y = max(0, min(surface.get_height(), cursor_y))
        pygame.draw.line(
            surface,
            self.theme.accent_yellow,
            (screen_start_x, screen_start_y),
            (cursor_x, cursor_y),
            2,
        )
        label = self.link_mode.get("label", "Linking...")
        hint_surf, _ = self.small_font.render(f"{label}: click target node (Esc to cancel)", self.theme.accent_yellow)
        surface.blit(hint_surf, (10, 10))
    
    def draw_nodes(self, surface):
        """Draw all nodes."""
        for node in self.nodes.values():
            self.draw_node(surface, node)
    
    def draw_node(self, surface, node):
        """Draw a single node."""
        screen_x, screen_y = self.world_to_screen(node.x, node.y)
        screen_width = node.width * self.zoom
        screen_height = node.height * self.zoom
        
        node_rect = pygame.Rect(screen_x, screen_y, screen_width, screen_height)
        
        # Node background
        node_color = node.get_color(self.theme)
        is_selected = node == self.selected_node
        
        if is_selected:
            # Draw selection glow
            glow_rect = node_rect.inflate(8, 8)
            pygame.draw.rect(surface, self.theme.accent_blue, glow_rect, border_radius=6)
        
        pygame.draw.rect(surface, node_color, node_rect, border_radius=4)
        pygame.draw.rect(surface, self.theme.border, node_rect, 2, border_radius=4)
        
        # Node header
        header_rect = pygame.Rect(screen_x, screen_y, screen_width, 20 * self.zoom)
        pygame.draw.rect(surface, (0, 0, 0, 60), header_rect, border_top_left_radius=4, border_top_right_radius=4)
        
        # Node type text
        if self.zoom > 0.5:
            type_surf, _ = self.small_font.render(node.type.upper(), self.theme.text_primary)
            type_surf = pygame.transform.scale(type_surf, (int(type_surf.get_width() * self.zoom), int(type_surf.get_height() * self.zoom)))
            surface.blit(type_surf, (screen_x + 5 * self.zoom, screen_y + 4 * self.zoom))
        
        # Node ID or main text
        if self.zoom > 0.6:
            if self.show_node_ids:
                id_text = node.id
            else:
                # Show preview of content
                if "text" in node.data:
                    id_text = node.data["text"][:20]
                elif "speaker" in node.data:
                    id_text = node.data["speaker"]
                elif "action" in node.data:
                    id_text = node.data["action"]
                else:
                    id_text = node.id
            
            id_surf, _ = self.font.render(id_text, self.theme.text_primary)
            id_surf = pygame.transform.scale(id_surf, (int(id_surf.get_width() * self.zoom), int(id_surf.get_height() * self.zoom)))
            surface.blit(id_surf, (screen_x + 5 * self.zoom, screen_y + 30 * self.zoom))
    
    def draw_node_details(self, surface):
        """Draw node details panel for selected node."""
        if not self.selected_node:
            return
        self._ensure_property_inputs()
        self.dropdown_overlays = []
        panel_rect = self._node_panel_rect()
        
        pygame.draw.rect(surface, self.theme.bg_medium, panel_rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, panel_rect, 2, border_radius=6)
        
        title_surf, _ = self.title_font.render("Node Properties", self.theme.text_primary)
        surface.blit(title_surf, (panel_rect.x + 10, panel_rect.y + 10))
        subtitle = f"Selected: {self.selected_node.id}"
        subtitle_surf, _ = self.small_font.render(subtitle, self.theme.text_secondary)
        surface.blit(subtitle_surf, (panel_rect.x + 10, panel_rect.y + 28))
        
        y = panel_rect.y + 60
        for field in self.property_inputs:
            label_surf, _ = self.small_font.render(field["label"], self.theme.text_secondary)
            surface.blit(label_surf, (panel_rect.x + 12, y))
            widget_rect = pygame.Rect(panel_rect.x + 10, y + 18, panel_rect.width - 20, 28)
            widget = field["widget"]
            if hasattr(widget, "set_rect"):
                widget.set_rect(widget_rect)
            else:
                widget.rect = pygame.Rect(widget_rect)
            widget.draw(surface, self.theme)
            if field["kind"] == "dropdown" and getattr(widget, "open", False):
                self.dropdown_overlays.append(widget)
            y += 60
            if y > panel_rect.bottom - 80:
                break
        
        if self.property_apply_rect:
            pygame.draw.rect(surface, self.theme.accent_green, self.property_apply_rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, self.property_apply_rect, 1, border_radius=4)
            apply_surf, _ = self.font.render("Apply", self.theme.text_primary)
            apply_rect = apply_surf.get_rect(center=self.property_apply_rect.center)
            surface.blit(apply_surf, apply_rect)
        if self.property_revert_rect:
            pygame.draw.rect(surface, self.theme.bg_light, self.property_revert_rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, self.property_revert_rect, 1, border_radius=4)
            revert_surf, _ = self.font.render("Revert", self.theme.text_primary)
            revert_rect = revert_surf.get_rect(center=self.property_revert_rect.center)
            surface.blit(revert_surf, revert_rect)
        
        if self.property_status:
            status_surf, _ = self.small_font.render(self.property_status, self.property_status_color)
            surface.blit(status_surf, (panel_rect.x + 10, panel_rect.bottom - 60))

    def _draw_dropdown_overlays(self, surface):
        for dropdown in self.dropdown_overlays:
            dropdown.draw_popup(surface, self.theme)
        self.dropdown_overlays = []
    
    def draw_hints(self, surface):
        """Draw keyboard hints."""
        hints = [
            "G: Grid | I: IDs | F: Frame | H: Help",
            "Ctrl+S: Save | Ctrl+L: Load Sample | Ctrl+N: New Node | Ctrl+D: Duplicate",
            "Ctrl+Z: Undo | Ctrl+Shift+Z or Ctrl+Y: Redo | Delete: Remove Node",
            "Middle Mouse: Pan | Scroll: Zoom | Right Click: Add Node"
        ]
        if self.link_mode:
            hints.insert(0, f"{self.link_mode.get('label', 'Link')} – click a target node or press Esc")
        
        y = self.rect.height - len(hints) * 18 - 5
        for hint in hints:
            hint_surf, _ = self.small_font.render(hint, self.theme.text_disabled)
            surface.blit(hint_surf, (10, y))
            y += 18

    def _draw_context_menu(self, surface):
        menu = self.context_menu
        if not menu["visible"] or not menu.get("rect"):
            return
        rect = menu["rect"]
        pygame.draw.rect(surface, self.theme.bg_light, rect, border_radius=4)
        pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)
        for index, item in enumerate(menu["items"]):
            item_rect = pygame.Rect(rect.x, rect.y + index * menu["item_height"], rect.width, menu["item_height"])
            label_surf, _ = self.font.render(item["label"], self.theme.text_primary)
            surface.blit(label_surf, (item_rect.x + 8, item_rect.y + 6))
    
    def get_help_entries(self):
        """Return story-editor specific help sections for the global overlay."""
        return [
            (
                "Story Editor Shortcuts",
                [
                    "Ctrl+N - Add dialogue node at camera focus",
                    "Ctrl+D - Duplicate selected node",
                    "Ctrl+Z / Ctrl+Shift+Z (or Ctrl+Y) - Undo / Redo graph edits",
                    "Delete - Remove selected node | Right click - Context menu",
                ],
            ),
            (
                "Navigation & Editing",
                [
                    "Left click selects & drags nodes | Right click adds node at cursor",
                    "Middle click drag pans canvas | Scroll wheel zooms",
                    "G toggles grid, I toggles IDs, F frames all nodes | H shows help",
                    "Ctrl+S saves to assets, Ctrl+L reloads demo scene",
                    "Use property panel on the right to edit node data and connections",
                    "Choose 'Link' options from the context menu, then click a target node",
                ],
            ),
        ]
    
    def cleanup(self):
        """Cleanup resources."""
        pass
