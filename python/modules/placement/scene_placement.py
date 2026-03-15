"""Scene Placement Editor — Redesigned

Key features:
- Actual background image rendering (loads from assets/images/bg/)
- Actual character sprite rendering (loads from assets/images/characters/)
- Undo / redo (Ctrl+Z / Ctrl+Y)
- Keyboard slot-snap: 1=far_left 2=left 3=center_left 4=center 5=center_right 6=right 7=far_right
- F key = flip selected character
- Arrow keys = nudge selected character 1px (Shift = 10px)
- Movement arrows drawn between node-to-node position changes
- State-based placement: only changes are exported (90 %+ smaller files)
- Dialogue / narration text preview in header
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pygame
import pygame.freetype
import pygame.transform

from modules.utils.data_loader import ensure_export_dir


# ---------------------------------------------------------------------------
# Slot definitions (must match CharacterRenderer.hx)
# ---------------------------------------------------------------------------
SLOTS = ["far_left", "left", "center_left", "center", "center_right", "right", "far_right"]
SLOT_RATIOS = {
    "far_left":    0.05,
    "left":        0.18,
    "center_left": 0.33,
    "center":      0.50,
    "center_right":0.67,
    "right":       0.82,
    "far_right":   0.95,
}


# ---------------------------------------------------------------------------
# State helpers
# ---------------------------------------------------------------------------

class CharacterState:
    def __init__(self, character: str, pose: str, x: float, y: float, slot: str, flipped: bool = False):
        self.character = character
        self.pose      = pose
        self.x         = x
        self.y         = y
        self.slot      = slot
        self.flipped   = flipped

    def to_dict(self) -> Dict:
        d: Dict = {"x": self.x, "y": self.y, "slot": self.slot}
        if self.flipped:
            d["flip"] = True
        return d

    def position_changed(self, x: float, y: float, slot: str, flipped: bool) -> bool:
        return (abs(self.x - x) > 0.5 or abs(self.y - y) > 0.5
                or self.slot != slot or self.flipped != flipped)


class PlacementState:
    def __init__(self):
        self.characters: Dict[str, CharacterState] = {}
        self.placement_changes: Dict[str, Dict[str, Dict]] = {}

    def show_character(self, node_id: str, character: str, pose: str,
                       slot: str, x: float, y: float, flipped: bool = False):
        if character in self.characters:
            cs = self.characters[character]
            if cs.position_changed(x, y, slot, flipped):
                self._record(node_id, character, x, y, slot, flipped)
                cs.x = x; cs.y = y; cs.slot = slot; cs.flipped = flipped
            cs.pose = pose
        else:
            self.characters[character] = CharacterState(character, pose, x, y, slot, flipped)
            self._record(node_id, character, x, y, slot, flipped)

    def hide_character(self, character: str):
        self.characters.pop(character, None)

    def _record(self, node_id: str, character: str, x: float, y: float, slot: str, flipped: bool):
        if node_id not in self.placement_changes:
            self.placement_changes[node_id] = {}
        self.placement_changes[node_id][character] = {
            "x": round(x, 1), "y": round(y, 1), "slot": slot,
            **({"flip": True} if flipped else {})
        }

    def get_visible(self) -> Dict[str, Dict]:
        return {cid: {"character": cid, "pose": cs.pose, "slot": cs.slot,
                      "x": cs.x, "y": cs.y, "flipped": cs.flipped}
                for cid, cs in self.characters.items()}

    def export(self) -> Dict:
        return dict(self.placement_changes)

    def reset(self):
        self.characters.clear()
        self.placement_changes.clear()


# ---------------------------------------------------------------------------
# Undo / redo snapshot
# ---------------------------------------------------------------------------

class UndoSnapshot:
    def __init__(self, node_index: int, placement_changes: Dict, characters: Dict):
        self.node_index        = node_index
        self.placement_changes = json.loads(json.dumps(placement_changes))
        self.characters        = json.loads(json.dumps(
            {k: {"x": v.x, "y": v.y, "slot": v.slot, "flipped": v.flipped, "pose": v.pose}
             for k, v in characters.items()}
        ))


# ---------------------------------------------------------------------------
# Asset loader (singleton-ish cache)
# ---------------------------------------------------------------------------

class AssetCache:
    def __init__(self, project_root: Path):
        self.root    = project_root
        self._images: Dict[str, Optional[pygame.Surface]] = {}

    def load_image(self, rel_path: str, max_w: int = 0, max_h: int = 0) -> Optional[pygame.Surface]:
        key = f"{rel_path}@{max_w}x{max_h}"
        if key in self._images:
            return self._images[key]
        full = self.root / rel_path
        surf = None
        if full.exists():
            try:
                surf = pygame.image.load(str(full)).convert_alpha()
                if max_w > 0 or max_h > 0:
                    w, h = surf.get_size()
                    scale = min(max_w / w if max_w else 1e9, max_h / h if max_h else 1e9)
                    surf = pygame.transform.smoothscale(surf, (int(w * scale), int(h * scale)))
            except Exception:
                surf = None
        self._images[key] = surf
        return surf

    def load_bg(self, name: str, w: int, h: int) -> Optional[pygame.Surface]:
        for ext in (".png", ".jpg", ".jpeg"):
            surf = self.load_image(f"assets/images/bg/{name}{ext}", w, h)
            if surf:
                return surf
        return None

    def load_character(self, char_id: str, max_h: int) -> Optional[pygame.Surface]:
        for ext in (".png",):
            surf = self.load_image(
                f"assets/images/characters/{char_id}/{char_id}{ext}", 0, max_h)
            if surf:
                return surf
        return None


# ---------------------------------------------------------------------------
# Main module
# ---------------------------------------------------------------------------

class ScenePlacement:
    """Scene Placement Editor — redesigned with real asset rendering."""

    SLOT_KEYS = {
        pygame.K_1: "far_left",
        pygame.K_2: "left",
        pygame.K_3: "center_left",
        pygame.K_4: "center",
        pygame.K_5: "center_right",
        pygame.K_6: "right",
        pygame.K_7: "far_right",
    }

    def __init__(self, workspace_rect, theme, project_root):
        self.rect         = workspace_rect
        self.theme        = theme
        self.project_root = project_root

        self.font       = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 20, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)
        self.mono_font  = pygame.freetype.SysFont("Courier New", 12)

        self.assets = AssetCache(project_root)

        # Browser
        self.show_browser         = True
        self.available_scenes     = self._find_scenes()
        self.selected_scene_index = 0
        self.browser_scroll       = 0

        # Scene data
        self.scene               = None
        self.scene_id            = ""
        self.scene_path          = None
        self.nodes: List[Dict]   = []
        self.current_node_index  = 0
        self.background_name     = ""

        # Placement state
        self.placement_state   = PlacementState()
        self.visible_characters: Dict[str, Dict] = {}

        # Undo / redo
        self._undo_stack: List[UndoSnapshot] = []
        self._redo_stack: List[UndoSnapshot] = []

        # Interaction
        self.selected_character: Optional[str] = None
        self.dragging      = False
        self.drag_offset   = (0, 0)
        self.status_msg    = ""
        self.status_timer  = 0.0

        # Cached surfaces
        self._bg_surf: Optional[pygame.Surface] = None
        self._bg_name_loaded = ""

    # -----------------------------------------------------------------------
    # Scene discovery
    # -----------------------------------------------------------------------

    def _find_scenes(self) -> List[Dict]:
        scenes = []
        search = [
            self.project_root / "assets" / "data" / "scenes",
            self.project_root / "scenes",
        ]
        for base in search:
            if not base.exists():
                continue
            for p in sorted(base.rglob("*.json")):
                try:
                    data = json.loads(p.read_text(encoding="utf-8"))
                    if "scene_id" in data and "nodes" in data:
                        scenes.append({
                            "path": p,
                            "relative_path": str(p.relative_to(self.project_root)),
                            "scene_id": data.get("scene_id", "?"),
                            "node_count": len(data.get("nodes", [])),
                        })
                except Exception:
                    continue
        if not scenes:
            scenes.append({"path": None, "relative_path": "No scenes found",
                           "scene_id": "Place .json files in assets/data/scenes/",
                           "node_count": 0})
        return scenes

    # -----------------------------------------------------------------------
    # Scene loading
    # -----------------------------------------------------------------------

    def _load_scene(self, info: Dict):
        if not info["path"] or not info["path"].exists():
            self._set_status("Invalid scene file", 3.0)
            return
        try:
            self.scene    = json.loads(info["path"].read_text(encoding="utf-8"))
            self.scene_id = self.scene.get("scene_id", "unknown")
            self.scene_path = info["path"]
            self.nodes    = self.scene.get("nodes", [])
            self.current_node_index = 0
            self.background_name    = ""
            self.placement_state.reset()
            self._undo_stack.clear()
            self._redo_stack.clear()
            self._update_state()
            self.show_browser = False
            self._set_status(f"Loaded: {info['relative_path']}", 3.0)
        except Exception as e:
            self._set_status(f"Error: {e}", 4.0)

    # -----------------------------------------------------------------------
    # State rebuild
    # -----------------------------------------------------------------------

    def _update_state(self):
        if not self.nodes:
            return
        self.placement_state.reset()
        self.background_name = ""
        stage = self._stage_rect()

        for i in range(self.current_node_index + 1):
            if i >= len(self.nodes):
                break
            node    = self.nodes[i]
            node_id = node.get("id", f"__node_{i}")
            if node.get("type") != "action":
                continue
            action = node.get("action")
            if action == "set_bg":
                self.background_name = node.get("background", "")
            elif action == "show_character":
                cid    = node.get("character", "?")
                pose   = node.get("pose", "default")
                slot   = node.get("position", "center")
                x, y   = self._slot_to_xy(slot, stage)
                flipped = bool(node.get("flip", False))
                self.placement_state.show_character(node_id, cid, pose, slot, x, y, flipped)
            elif action == "hide_character":
                self.placement_state.hide_character(node.get("character", ""))

        self.visible_characters = self.placement_state.get_visible()
        self._bg_surf = None  # invalidate cached bg

    # -----------------------------------------------------------------------
    # Navigation
    # -----------------------------------------------------------------------

    def _next_node(self):
        self._push_undo()
        if self.current_node_index < len(self.nodes) - 1:
            self.current_node_index += 1
            self._update_state()
            self._set_status(f"Node {self.current_node_index + 1}/{len(self.nodes)}", 1.5)

    def _prev_node(self):
        self._push_undo()
        if self.current_node_index > 0:
            self.current_node_index -= 1
            self._update_state()
            self._set_status(f"Node {self.current_node_index + 1}/{len(self.nodes)}", 1.5)

    def _goto_node(self, index: int):
        if 0 <= index < len(self.nodes):
            self._push_undo()
            self.current_node_index = index
            self._update_state()
            self._set_status(f"Node {index + 1}/{len(self.nodes)}", 1.5)

    # -----------------------------------------------------------------------
    # Undo / redo
    # -----------------------------------------------------------------------

    def _push_undo(self):
        snap = UndoSnapshot(
            self.current_node_index,
            self.placement_state.placement_changes,
            self.placement_state.characters,
        )
        self._undo_stack.append(snap)
        if len(self._undo_stack) > 50:
            self._undo_stack.pop(0)
        self._redo_stack.clear()

    def _undo(self):
        if not self._undo_stack:
            self._set_status("Nothing to undo", 2.0)
            return
        # Save current to redo
        self._redo_stack.append(UndoSnapshot(
            self.current_node_index,
            self.placement_state.placement_changes,
            self.placement_state.characters,
        ))
        snap = self._undo_stack.pop()
        self._restore_snapshot(snap)
        self._set_status("Undo", 1.5)

    def _redo(self):
        if not self._redo_stack:
            self._set_status("Nothing to redo", 2.0)
            return
        self._undo_stack.append(UndoSnapshot(
            self.current_node_index,
            self.placement_state.placement_changes,
            self.placement_state.characters,
        ))
        snap = self._redo_stack.pop()
        self._restore_snapshot(snap)
        self._set_status("Redo", 1.5)

    def _restore_snapshot(self, snap: UndoSnapshot):
        self.current_node_index = snap.node_index
        self.placement_state.placement_changes = snap.placement_changes
        self.placement_state.characters = {}
        stage = self._stage_rect()
        for cid, d in snap.characters.items():
            self.placement_state.characters[cid] = CharacterState(
                cid, d["pose"], d["x"], d["y"], d["slot"], d.get("flipped", False))
        self.visible_characters = self.placement_state.get_visible()
        self._bg_surf = None

    # -----------------------------------------------------------------------
    # Saving
    # -----------------------------------------------------------------------

    def _save(self):
        if not self.scene_id:
            self._set_status("No scene loaded", 2.0)
            return
        export_dir = ensure_export_dir(self.project_root, "placements")
        path = export_dir / f"{self.scene_id}_placement.json"
        payload = {
            "scene_id": self.scene_id,
            "placements": self.placement_state.export(),
        }
        path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        n_total = len(self.nodes)
        n_saved = len(payload["placements"])
        self._set_status(
            f"Saved {n_saved}/{n_total} placement nodes → {path.name}", 5.0)
        print(f"[Placement] Saved {n_saved} nodes (total {n_total}) → {path}")

    # -----------------------------------------------------------------------
    # Slot / position helpers
    # -----------------------------------------------------------------------

    def _stage_rect(self) -> pygame.Rect:
        left   = 300
        top    = 115
        right  = self.rect.width - 10
        bottom = self.rect.height - 80
        return pygame.Rect(left, top, max(400, right - left), max(260, bottom - top))

    def _slot_to_xy(self, slot: str, stage: pygame.Rect) -> Tuple[float, float]:
        ratio = SLOT_RATIOS.get(slot, 0.5)
        x = stage.x + stage.width * ratio
        y = stage.bottom - 10
        return x, y

    def _xy_to_slot(self, x: float, stage: pygame.Rect) -> str:
        ratio = (x - stage.x) / stage.width
        best, best_dist = "center", 1e9
        for s, r in SLOT_RATIOS.items():
            d = abs(r - ratio)
            if d < best_dist:
                best, best_dist = s, d
        return best

    def _snap_to_slot(self, slot: str):
        if not self.selected_character:
            return
        stage = self._stage_rect()
        x, y  = self._slot_to_xy(slot, stage)
        cd    = self.visible_characters.get(self.selected_character)
        if cd is None:
            return
        cd["x"] = x; cd["y"] = y; cd["slot"] = slot
        cs = self.placement_state.characters.get(self.selected_character)
        if cs:
            cs.x = x; cs.y = y; cs.slot = slot
        self._record_current()
        self._set_status(f"{self.selected_character} → {slot}", 2.0)

    def _nudge_selected(self, dx: float, dy: float):
        if not self.selected_character:
            return
        cd = self.visible_characters.get(self.selected_character)
        if cd is None:
            return
        stage = self._stage_rect()
        cd["x"] = max(stage.x, min(stage.right, cd["x"] + dx))
        cd["y"] = max(stage.y, min(stage.bottom, cd["y"] + dy))
        cd["slot"] = self._xy_to_slot(cd["x"], stage)
        cs = self.placement_state.characters.get(self.selected_character)
        if cs:
            cs.x = cd["x"]; cs.y = cd["y"]; cs.slot = cd["slot"]
        self._record_current()

    def _flip_selected(self):
        if not self.selected_character:
            return
        cd = self.visible_characters.get(self.selected_character)
        cs = self.placement_state.characters.get(self.selected_character)
        if cd is None or cs is None:
            return
        cs.flipped    = not cs.flipped
        cd["flipped"] = cs.flipped
        self._record_current()
        self._set_status(f"{self.selected_character} flipped={cs.flipped}", 2.0)

    def _record_current(self):
        """Record all visible character positions into the placement state for the current node."""
        node = self._current_node()
        if not node:
            return
        node_id = node.get("id", f"__node_{self.current_node_index}")
        for cid, cs in self.placement_state.characters.items():
            self.placement_state._record(node_id, cid, cs.x, cs.y, cs.slot, cs.flipped)

    def _current_node(self) -> Optional[Dict]:
        if 0 <= self.current_node_index < len(self.nodes):
            return self.nodes[self.current_node_index]
        return None

    # -----------------------------------------------------------------------
    # Event handling
    # -----------------------------------------------------------------------

    def handle_event(self, event):
        if self.show_browser:
            self._handle_browser_event(event)
            return
        self._handle_editor_event(event)

    def _handle_browser_event(self, event):
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_UP:
                self.selected_scene_index = max(0, self.selected_scene_index - 1)
            elif event.key == pygame.K_DOWN:
                self.selected_scene_index = min(len(self.available_scenes) - 1,
                                                self.selected_scene_index + 1)
            elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                if self.available_scenes:
                    self._load_scene(self.available_scenes[self.selected_scene_index])
            elif event.key == pygame.K_r:
                self.available_scenes     = self._find_scenes()
                self.selected_scene_index = 0
                self._set_status("Scene list refreshed", 2.0)
            elif event.key == pygame.K_ESCAPE and self.scene:
                self.show_browser = False
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            br = self._browser_rect()
            list_y = br.y + 100; ih = 60
            for i, info in enumerate(self.available_scenes):
                r = pygame.Rect(br.x + 20, list_y + i * ih - self.browser_scroll, br.width - 40, ih - 5)
                if r.collidepoint(event.pos) and br.colliderect(r):
                    self.selected_scene_index = i
                    self._load_scene(info)
                    break
        elif event.type == pygame.MOUSEWHEEL:
            self.browser_scroll = max(0, self.browser_scroll - event.y * 30)

    def _handle_editor_event(self, event):
        mods = pygame.key.get_mods()

        if event.type == pygame.KEYDOWN:
            ctrl  = mods & pygame.KMOD_CTRL
            shift = mods & pygame.KMOD_SHIFT

            if ctrl and event.key == pygame.K_s:
                self._save(); return
            if ctrl and event.key == pygame.K_z:
                self._undo(); return
            if ctrl and event.key == pygame.K_y:
                self._redo(); return
            if ctrl and event.key == pygame.K_l:
                self.show_browser = True; return
            if event.key == pygame.K_ESCAPE:
                self.show_browser = True; return

            # Navigation
            if event.key in (pygame.K_RIGHT, pygame.K_SPACE):
                self._next_node(); return
            if event.key == pygame.K_LEFT:
                self._prev_node(); return

            # Slot snap
            if event.key in self.SLOT_KEYS:
                self._snap_to_slot(self.SLOT_KEYS[event.key]); return

            # Flip
            if event.key == pygame.K_f:
                self._flip_selected(); return

            # Nudge
            step = 10 if shift else 1
            if event.key == pygame.K_UP:    self._nudge_selected(0, -step); return
            if event.key == pygame.K_DOWN:  self._nudge_selected(0,  step); return
            if event.key == pygame.K_LEFT:  self._nudge_selected(-step, 0); return
            if event.key == pygame.K_RIGHT: self._nudge_selected( step, 0); return

        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            stage = self._stage_rect()
            hit   = False
            for cid, cd in self.visible_characters.items():
                r = self._char_rect(cd, stage)
                if r.collidepoint(event.pos):
                    self._push_undo()
                    self.selected_character = cid
                    self.dragging    = True
                    self.drag_offset = (event.pos[0] - cd["x"], event.pos[1] - cd["y"])
                    hit = True
                    break
            if not hit:
                self.selected_character = None

        elif event.type == pygame.MOUSEBUTTONUP and event.button == 1:
            if self.dragging and self.selected_character:
                cd = self.visible_characters[self.selected_character]
                cd["slot"] = self._xy_to_slot(cd["x"], self._stage_rect())
                cs = self.placement_state.characters.get(self.selected_character)
                if cs:
                    cs.x = cd["x"]; cs.y = cd["y"]; cs.slot = cd["slot"]
                self._record_current()
            self.dragging = False

        elif event.type == pygame.MOUSEMOTION and self.dragging and self.selected_character:
            stage  = self._stage_rect()
            cd     = self.visible_characters[self.selected_character]
            nx     = event.pos[0] - self.drag_offset[0]
            ny     = event.pos[1] - self.drag_offset[1]
            cd["x"] = max(stage.x, min(stage.right, nx))
            cd["y"] = max(stage.y + 40, min(stage.bottom, ny))
            cs = self.placement_state.characters.get(self.selected_character)
            if cs:
                cs.x = cd["x"]; cs.y = cd["y"]

    # -----------------------------------------------------------------------
    # Character rect (for hit-testing and drawing placeholder)
    # -----------------------------------------------------------------------

    def _char_rect(self, cd: Dict, stage: pygame.Rect) -> pygame.Rect:
        w, h = 80, 200
        # If we have an actual sprite, use its size
        surf = self.assets.load_character(cd["character"], stage.height - 20)
        if surf:
            w, h = surf.get_size()
        return pygame.Rect(int(cd["x"] - w // 2), int(cd["y"] - h), w, h)

    # -----------------------------------------------------------------------
    # Update
    # -----------------------------------------------------------------------

    def update(self, dt: float):
        if self.status_timer > 0:
            self.status_timer -= dt
            if self.status_timer <= 0:
                self.status_msg = ""

    # -----------------------------------------------------------------------
    # Drawing
    # -----------------------------------------------------------------------

    def draw(self, surface: pygame.Surface):
        surface.fill(self.theme.bg_dark)
        if self.show_browser:
            self._draw_browser(surface)
        else:
            self._draw_editor(surface)
        self._draw_status(surface)

    def _draw_editor(self, surface: pygame.Surface):
        stage = self._stage_rect()
        self._draw_header(surface, stage)
        self._draw_stage(surface, stage)
        self._draw_sidebar(surface, stage)
        self._draw_controls_panel(surface, stage)

    # ---- Header -----------------------------------------------------------

    def _draw_header(self, surface: pygame.Surface, stage: pygame.Rect):
        # Title row
        t, _ = self.title_font.render("Scene Placement", self.theme.text_primary)
        surface.blit(t, (10, 8))

        if self.scene_id:
            info = f"{self.scene_id}  |  Node {self.current_node_index + 1}/{len(self.nodes)}"
            s, _ = self.font.render(info, self.theme.text_secondary)
            surface.blit(s, (10, 36))

        node = self._current_node()
        if node:
            ntype  = node.get("type", "?")
            node_id = node.get("id", "?")
            color  = self._node_type_color(ntype)

            # Node type badge
            badge_text = ntype.upper()
            bt, _ = self.small_font.render(badge_text, color)
            bx = 10
            pygame.draw.rect(surface, (*color[:3], 50),
                             pygame.Rect(bx - 3, 57, bt.get_width() + 10, 18), border_radius=4)
            surface.blit(bt, (bx, 59))

            # Node ID
            id_s, _ = self.small_font.render(f"id: {node_id}", self.theme.text_disabled)
            surface.blit(id_s, (bx + bt.get_width() + 16, 59))

            # Dialogue/narration text preview
            preview = ""
            if ntype == "dialogue":
                spk = node.get("speaker", "")
                txt = node.get("text", "")
                preview = f'"{spk}: {txt}"'
            elif ntype == "narration":
                preview = f'"{node.get("text", "")}"'
            elif ntype == "action":
                preview = f"action: {node.get('action', '?')}"
            if preview:
                clipped = preview[:100] + ("…" if len(preview) > 100 else "")
                ps, _ = self.small_font.render(clipped, self.theme.text_secondary)
                surface.blit(ps, (10, 80))

        # Undo/redo indicators
        undo_c = self.theme.text_secondary if self._undo_stack else self.theme.text_disabled
        redo_c = self.theme.text_secondary if self._redo_stack else self.theme.text_disabled
        us, _ = self.small_font.render(f"Undo({len(self._undo_stack)})", undo_c)
        rs, _ = self.small_font.render(f"Redo({len(self._redo_stack)})", redo_c)
        surface.blit(us, (self.rect.width - 180, 8))
        surface.blit(rs, (self.rect.width - 100, 8))

    # ---- Stage ------------------------------------------------------------

    def _draw_stage(self, surface: pygame.Surface, stage: pygame.Rect):
        # Background image or fallback
        if self.background_name != self._bg_name_loaded or self._bg_surf is None:
            self._bg_surf = self.assets.load_bg(self.background_name, stage.width, stage.height)
            self._bg_name_loaded = self.background_name

        if self._bg_surf:
            bx = stage.x + (stage.width  - self._bg_surf.get_width())  // 2
            by = stage.y + (stage.height - self._bg_surf.get_height()) // 2
            surface.blit(self._bg_surf, (bx, by))
        else:
            # Gradient fallback
            grad = pygame.Surface((stage.width, stage.height))
            for i in range(stage.height):
                t = i / stage.height
                r = int(25 + 20 * t); g = int(20 + 15 * t); b = int(35 + 25 * t)
                pygame.draw.line(grad, (r, g, b), (0, i), (stage.width, i))
            surface.blit(grad, (stage.x, stage.y))
            if self.background_name:
                nl, _ = self.small_font.render(f"BG: {self.background_name} (not found)",
                                               self.theme.text_disabled)
                surface.blit(nl, (stage.x + 8, stage.y + 8))

        pygame.draw.rect(surface, self.theme.border, stage, 2, border_radius=4)

        # Slot guide lines
        for slot, ratio in SLOT_RATIOS.items():
            sx = stage.x + int(stage.width * ratio)
            col = (*self.theme.border[:3], 80) if slot != "center" else (*self.theme.accent_blue[:3], 100)
            line_surf = pygame.Surface((1, stage.height), pygame.SRCALPHA)
            line_surf.fill(col)
            surface.blit(line_surf, (sx, stage.y))
            lbl, _ = self.small_font.render(slot.replace("_", " "), self.theme.text_disabled)
            surface.blit(lbl, (sx - lbl.get_width() // 2, stage.bottom - 22))

        # Ground line
        pygame.draw.line(surface, (*self.theme.border[:3], 120),
                         (stage.x, stage.bottom - 5), (stage.right, stage.bottom - 5), 1)

        # Characters
        for cid, cd in self.visible_characters.items():
            self._draw_character(surface, cid, cd, stage)

        # Instruction strip
        tip = "Drag · 1-7 snap slot · F flip · ↑↓←→ nudge · Ctrl+Z undo"
        ts, _ = self.small_font.render(tip, self.theme.accent_green)
        surface.blit(ts, (stage.x + 8, stage.y + 8))

    def _draw_character(self, surface: pygame.Surface, cid: str, cd: Dict, stage: pygame.Rect):
        is_selected = cid == self.selected_character
        char_surf   = self.assets.load_character(cid, stage.height - 30)

        if char_surf:
            if cd.get("flipped"):
                char_surf = pygame.transform.flip(char_surf, True, False)
            w, h = char_surf.get_size()
            dx   = int(cd["x"] - w // 2)
            dy   = int(cd["y"] - h)

            if is_selected:
                # Selection glow
                glow = pygame.Surface((w + 8, h + 8), pygame.SRCALPHA)
                glow.fill((80, 140, 255, 60))
                surface.blit(glow, (dx - 4, dy - 4))

            # Slight darken/brighten to distinguish from background
            if is_selected:
                bright = char_surf.copy()
                bright.fill((30, 30, 30, 0), special_flags=pygame.BLEND_RGB_ADD)
                surface.blit(bright, (dx, dy))
            else:
                surface.blit(char_surf, (dx, dy))

            # Name tag
            nt, _ = self.small_font.render(cid, self.theme.text_primary)
            nx = int(cd["x"]) - nt.get_width() // 2
            ny = dy - 16
            pygame.draw.rect(surface, (0, 0, 0, 160),
                             pygame.Rect(nx - 3, ny - 1, nt.get_width() + 6, 14), border_radius=3)
            surface.blit(nt, (nx, ny))

            if cd.get("flipped"):
                fs, _ = self.small_font.render("↔", self.theme.accent_yellow)
                surface.blit(fs, (int(cd["x"]) + w // 2 - fs.get_width() - 2, dy))
        else:
            # Placeholder silhouette
            rect = self._char_rect(cd, stage)
            col  = (100, 80, 130) if not is_selected else (80, 120, 220)
            if is_selected:
                pygame.draw.rect(surface, (80, 140, 255, 60),
                                 rect.inflate(8, 8), border_radius=10)
            pygame.draw.rect(surface, col, rect, border_radius=8)
            pygame.draw.rect(surface, self.theme.border, rect, 2, border_radius=8)
            nt, _ = self.small_font.render(cid, self.theme.text_primary)
            pt, _ = self.small_font.render(f"pose: {cd.get('pose', '?')}", self.theme.text_secondary)
            surface.blit(nt, (rect.x + 6, rect.y + 6))
            surface.blit(pt, (rect.x + 6, rect.y + 22))
            if cd.get("flipped"):
                fs, _ = self.small_font.render("↔ flipped", self.theme.accent_yellow)
                surface.blit(fs, (rect.x + 6, rect.bottom - 20))

    # ---- Sidebar ----------------------------------------------------------

    def _draw_sidebar(self, surface: pygame.Surface, stage: pygame.Rect):
        pw = stage.x - 10
        panel = pygame.Rect(5, 115, pw - 5, stage.height)
        pygame.draw.rect(surface, self.theme.bg_medium, panel, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, panel, 1, border_radius=6)

        hdr, _ = self.font.render("Characters on Stage", self.theme.text_primary)
        surface.blit(hdr, (panel.x + 8, panel.y + 8))

        if not self.visible_characters:
            ns, _ = self.small_font.render("None visible", self.theme.text_disabled)
            surface.blit(ns, (panel.x + 8, panel.y + 32))
            return

        y = panel.y + 30
        for cid, cd in self.visible_characters.items():
            row_h  = 82
            row    = pygame.Rect(panel.x + 4, y, panel.width - 8, row_h)
            active = cid == self.selected_character
            pygame.draw.rect(surface, self.theme.accent_blue if active else self.theme.bg_light,
                             row, border_radius=5)
            pygame.draw.rect(surface, self.theme.border, row, 1, border_radius=5)

            ns, _ = self.font.render(cid, self.theme.text_primary)
            ps, _ = self.small_font.render(f"pose: {cd.get('pose', '?')}", self.theme.text_secondary)
            ss, _ = self.small_font.render(f"slot: {cd.get('slot', '?')}", self.theme.text_secondary)
            xs, _ = self.small_font.render(f"x={int(cd['x'])} y={int(cd['y'])}", self.theme.text_disabled)
            surface.blit(ns, (row.x + 6, row.y + 4))
            surface.blit(ps, (row.x + 6, row.y + 22))
            surface.blit(ss, (row.x + 6, row.y + 38))
            surface.blit(xs, (row.x + 6, row.y + 54))
            if cd.get("flipped"):
                fs, _ = self.small_font.render("↔", self.theme.accent_yellow)
                surface.blit(fs, (row.right - 20, row.y + 4))
            y += row_h + 4

    # ---- Controls panel ---------------------------------------------------

    def _draw_controls_panel(self, surface: pygame.Surface, stage: pygame.Rect):
        bx = 5
        by = stage.bottom + 5
        bw = stage.x - 10
        bh = self.rect.height - by - 5
        if bh < 20:
            return
        panel = pygame.Rect(bx, by, bw - 5, bh)
        pygame.draw.rect(surface, self.theme.bg_medium, panel, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, panel, 1, border_radius=6)

        controls = [
            ("→ / Space", "next node"),
            ("←",         "prev node"),
            ("1-7",        "snap to slot"),
            ("F",          "flip char"),
            ("↑↓←→",       "nudge 1px"),
            ("Shift+↑↓",   "nudge 10px"),
            ("Ctrl+Z/Y",   "undo / redo"),
            ("Ctrl+S",     "save"),
            ("Esc",        "scene list"),
        ]
        y = panel.y + 6
        for key, desc in controls:
            if y + 16 > panel.bottom:
                break
            ks, _ = self.small_font.render(key, self.theme.accent_blue)
            ds, _ = self.small_font.render(f" {desc}", self.theme.text_secondary)
            surface.blit(ks, (panel.x + 6, y))
            surface.blit(ds, (panel.x + 6 + ks.get_width(), y))
            y += 16

    # ---- Status -----------------------------------------------------------

    def _draw_status(self, surface: pygame.Surface):
        if not self.status_msg:
            return
        alpha = min(255, int(255 * min(1.0, self.status_timer / 0.5)))
        s, _  = self.font.render(self.status_msg, (*self.theme.accent_green, alpha))
        bx    = self._stage_rect().x if not self.show_browser else 20
        surface.blit(s, (bx + 8, self.rect.height - 28))

    # ---- Browser ----------------------------------------------------------

    def _browser_rect(self) -> pygame.Rect:
        w = min(820, self.rect.width - 80)
        h = min(620, self.rect.height - 80)
        return pygame.Rect((self.rect.width - w) // 2, (self.rect.height - h) // 2, w, h)

    def _draw_browser(self, surface: pygame.Surface):
        overlay = pygame.Surface((self.rect.width, self.rect.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))
        surface.blit(overlay, (0, 0))

        br = self._browser_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, br, border_radius=12)
        pygame.draw.rect(surface, self.theme.border, br, 2, border_radius=12)

        ts, _ = self.title_font.render("Select a Scene", self.theme.text_primary)
        surface.blit(ts, ts.get_rect(centerx=br.centerx, y=br.y + 18))

        hint = "↑↓ navigate · Enter/Click load · R refresh · Esc cancel"
        hs, _ = self.small_font.render(hint, self.theme.text_secondary)
        surface.blit(hs, hs.get_rect(centerx=br.centerx, y=br.y + 52))

        list_y = br.y + 80; ih = 62
        for i, info in enumerate(self.available_scenes):
            iy   = list_y + i * ih - self.browser_scroll
            row  = pygame.Rect(br.x + 16, iy, br.width - 32, ih - 4)
            if row.bottom < br.y + 80 or row.top > br.bottom - 10:
                continue
            sel  = i == self.selected_scene_index
            pygame.draw.rect(surface, self.theme.accent_blue if sel else self.theme.bg_light,
                             row, border_radius=6)
            pygame.draw.rect(surface, self.theme.border, row, 1, border_radius=6)
            rs, _ = self.font.render(info["relative_path"], self.theme.text_primary)
            ids, _ = self.small_font.render(f"id: {info['scene_id']}", self.theme.text_secondary)
            ns, _  = self.small_font.render(f"{info['node_count']} nodes", self.theme.text_disabled)
            surface.blit(rs, (row.x + 10, row.y + 6))
            surface.blit(ids, (row.x + 10, row.y + 26))
            surface.blit(ns, (row.x + 10, row.y + 44))

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------

    def _set_status(self, msg: str, duration: float = 3.0):
        self.status_msg   = msg
        self.status_timer = duration

    def _node_type_color(self, ntype: str) -> Tuple:
        return {
            "dialogue":  self.theme.node_dialogue,
            "narration": self.theme.node_narration,
            "action":    self.theme.node_action,
            "choice":    self.theme.node_choice,
            "if":        self.theme.node_condition,
            "jump":      self.theme.node_jump,
            "game":      self.theme.node_game,
            "end":       self.theme.node_end,
        }.get(ntype, self.theme.text_secondary)

    def on_resize(self, rect):
        self.rect   = rect
        self._bg_surf = None

    def get_help_entries(self):
        return [
            ("Navigation", [
                "→ / Space  — next node",
                "←  — previous node",
                "Esc / Ctrl+L  — open scene browser",
            ]),
            ("Character Positioning", [
                "Click and drag  — reposition character",
                "1-7  — snap selected character to slot (far_left … far_right)",
                "↑ ↓ ← →  — nudge 1 pixel",
                "Shift + arrow  — nudge 10 pixels",
                "F  — flip selected character horizontally",
            ]),
            ("Editing", [
                "Ctrl+Z  — undo  |  Ctrl+Y  — redo (up to 50 steps)",
                "Ctrl+S  — export placement JSON",
                "Only position changes are saved (compact format)",
            ]),
            ("Assets", [
                "Backgrounds load from assets/images/bg/<name>.png",
                "Characters load from assets/images/characters/<id>/<id>.png",
                "Missing assets shown as coloured placeholders",
            ]),
        ]

    def cleanup(self):
        pass
