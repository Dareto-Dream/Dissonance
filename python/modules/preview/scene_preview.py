"""Scene Preview — full VN playback inside the editor

Renders scenes the way the game would: real background images, real character
sprites, a VN dialogue box with typewriter text, speaker name panel, and
branching choice support.  All scene logic (show/hide character, set_bg,
play actions) is simulated so you see exactly what the player will see.

Controls
--------
Space / Enter / LMB   advance dialogue / skip typewriter
← / →                 step back one history entry / forward
Click choice button   pick a branch
Ctrl+L / Esc          back to scene browser
R                     reload current scene from disk
"""
from __future__ import annotations

import json
import math
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pygame
import pygame.freetype
import pygame.transform

from modules.utils.data_loader import ensure_export_dir


# ---------------------------------------------------------------------------
# Slot → x-ratio (mirrors CharacterRenderer.hx)
# ---------------------------------------------------------------------------
SLOT_RATIOS = {
    "far_left":    0.05,
    "left":        0.18,
    "center_left": 0.33,
    "center":      0.50,
    "center_right":0.67,
    "right":       0.82,
    "far_right":   0.95,
}

CHAR_HEIGHT_RATIO = 0.82   # character height as fraction of stage height


# ---------------------------------------------------------------------------
# Asset cache
# ---------------------------------------------------------------------------

class _Cache:
    def __init__(self, root: Path):
        self.root = root
        self._raw:   Dict[str, Optional[pygame.Surface]] = {}
        self._scaled:Dict[str, Optional[pygame.Surface]] = {}

    def bg(self, name: str, w: int, h: int) -> Optional[pygame.Surface]:
        key = f"bg:{name}@{w}x{h}"
        if key in self._scaled:
            return self._scaled[key]
        surf = self._try_load_bg(name)
        if surf:
            surf = _fit(surf, w, h)
        self._scaled[key] = surf
        return surf

    def _try_load_bg(self, name: str) -> Optional[pygame.Surface]:
        if name in self._raw:
            return self._raw[name]
        for ext in (".png", ".jpg", ".jpeg"):
            p = self.root / "assets" / "images" / "bg" / f"{name}{ext}"
            if p.exists():
                try:
                    surf = pygame.image.load(str(p)).convert()
                    self._raw[name] = surf
                    return surf
                except Exception:
                    pass
        self._raw[name] = None
        return None

    def character(self, char_id: str, h: int) -> Optional[pygame.Surface]:
        key = f"char:{char_id}@h{h}"
        if key in self._scaled:
            return self._scaled[key]
        surf = self._try_load_char(char_id)
        if surf:
            w2  = int(surf.get_width() * h / surf.get_height())
            surf = pygame.transform.smoothscale(surf, (w2, h))
        self._scaled[key] = surf
        return surf

    def _try_load_char(self, char_id: str) -> Optional[pygame.Surface]:
        if char_id in self._raw:
            return self._raw[char_id]
        p = self.root / "assets" / "images" / "characters" / char_id / f"{char_id}.png"
        if p.exists():
            try:
                surf = pygame.image.load(str(p)).convert_alpha()
                self._raw[char_id] = surf
                return surf
            except Exception:
                pass
        self._raw[char_id] = None
        return None

    def load_placement(self, scene_id: str) -> Dict:
        """Try to load a placement file for this scene."""
        for base in [
            self.root / "assets" / "data" / "placements",
            self.root / "export_html5" / "bin" / "assets" / "data" / "placements",
        ]:
            p = base / f"{scene_id}_placement.json"
            if p.exists():
                try:
                    return json.loads(p.read_text(encoding="utf-8"))
                except Exception:
                    pass
        return {}


def _fit(surf: pygame.Surface, max_w: int, max_h: int) -> pygame.Surface:
    w, h = surf.get_size()
    scale = min(max_w / w, max_h / h)
    return pygame.transform.smoothscale(surf, (int(w * scale), int(h * scale)))


# ---------------------------------------------------------------------------
# Character display state
# ---------------------------------------------------------------------------

class CharDisplay:
    """Runtime state for one character visible on stage."""

    def __init__(self, char_id: str, pose: str, x: float, y: float,
                 flipped: bool = False):
        self.char_id = char_id
        self.pose    = pose
        self.x       = x        # centre-x in stage coords
        self.y       = y        # bottom-y in stage coords
        self.flipped = flipped
        self.alpha   = 255      # 0-255
        self.scale   = 1.0

    @property
    def is_speaking(self) -> bool:
        return self._speaking

    def set_speaking(self, v: bool):
        self._speaking = v
        self.scale = 1.06 if v else 0.92
        self.alpha = 255  if v else 140

    _speaking: bool = False


# ---------------------------------------------------------------------------
# VN engine state machine
# ---------------------------------------------------------------------------

class VNEngine:
    """Simulates the VN scene: processes nodes, tracks character state."""

    def __init__(self, scene: Dict, placement_data: Dict):
        self.nodes: Dict[str, Dict] = {n["id"]: n for n in scene.get("nodes", [])}
        self.node_order: List[str]  = [n["id"] for n in scene.get("nodes", [])]
        self.start_id: str          = scene.get("start", self.node_order[0] if self.node_order else "")
        self.placement_data         = placement_data.get("placements", {})

        # Scene state
        self.characters: Dict[str, CharDisplay] = {}
        self.background: str = ""
        self.current_id: str = self.start_id

        # Display output set by next_display_node()
        self.speaker:   Optional[str]       = None
        self.text:      str                 = ""
        self.is_narration: bool             = False
        self.choices:   List[Dict]          = []
        self.at_end:    bool                = False

        # History for back-stepping
        self._history: List[str] = []

    # ---- Navigation -------------------------------------------------------

    def advance(self) -> bool:
        """Process non-display nodes until we reach one that needs rendering."""
        node = self.nodes.get(self.current_id)
        if node is None:
            self.at_end = True
            return False

        ntype = node.get("type", "")

        if ntype == "action":
            self._do_action(node)
            self.current_id = node.get("next", "")
            return self.advance()

        if ntype == "jump":
            self.current_id = node.get("target", "")
            return self.advance()

        if ntype == "end":
            self.at_end = True
            return False

        if ntype == "dialogue":
            self._apply_placement(self.current_id)
            self.speaker      = node.get("speaker", "")
            self.text         = node.get("text", "")
            self.is_narration = False
            self.choices      = []
            # Pose update
            char_id = node.get("character")
            pose    = node.get("pose")
            if char_id and pose and char_id in self.characters:
                self.characters[char_id].pose = pose
            # Emphasize speaker
            for cid, cd in self.characters.items():
                cd.set_speaking(cid == char_id)
            self._history.append(self.current_id)
            return True

        if ntype == "narration":
            self._apply_placement(self.current_id)
            self.speaker      = None
            self.text         = node.get("text", "")
            self.is_narration = True
            self.choices      = []
            for cd in self.characters.values():
                cd.set_speaking(False)
            self._history.append(self.current_id)
            return True

        if ntype == "choice":
            self._apply_placement(self.current_id)
            self.speaker      = None
            self.text         = "— Choose —"
            self.is_narration = True
            self.choices      = node.get("choices", [])
            self._history.append(self.current_id)
            return True

        if ntype == "if":
            # Always take trueNode for preview purposes
            self.current_id = node.get("trueNode", node.get("falseNode", ""))
            return self.advance()

        if ntype == "game":
            self.text         = f"[Rhythm game: {node.get('song', '?')}]"
            self.is_narration = True
            self.speaker      = None
            self.choices      = []
            self._history.append(self.current_id)
            return True

        # Unknown node type — skip
        self.current_id = node.get("next", "")
        return self.advance()

    def step_next(self):
        node = self.nodes.get(self.current_id)
        if node is None:
            return
        ntype = node.get("type", "")
        if ntype in ("dialogue", "narration", "game"):
            self.current_id = node.get("next", "")
        # choices handled separately via pick_choice

    def pick_choice(self, index: int):
        choices = self.choices
        if 0 <= index < len(choices):
            self.current_id = choices[index].get("target", "")

    def step_back(self) -> bool:
        if len(self._history) < 2:
            return False
        self._history.pop()  # remove current
        target = self._history[-1]
        # Rebuild state up to that node
        engine = VNEngine.__new__(VNEngine)
        engine.nodes        = self.nodes
        engine.node_order   = self.node_order
        engine.start_id     = self.start_id
        engine.placement_data = self.placement_data
        engine.characters   = {}
        engine.background   = ""
        engine.current_id   = self.start_id
        engine.speaker      = None
        engine.text         = ""
        engine.is_narration = False
        engine.choices      = []
        engine.at_end       = False
        engine._history     = []

        # Fast-forward until we reach target
        safety = 0
        while engine.current_id != target and safety < 2000:
            safety += 1
            if not engine.advance():
                break
            if engine.current_id != target:
                engine.step_next()
            else:
                break

        # Copy rebuilt state back
        self.characters   = engine.characters
        self.background   = engine.background
        self.current_id   = engine.current_id
        self.speaker      = engine.speaker
        self.text         = engine.text
        self.is_narration = engine.is_narration
        self.choices      = engine.choices
        self.at_end       = engine.at_end
        self._history     = engine._history
        return True

    # ---- Action processing ------------------------------------------------

    def _do_action(self, node: Dict):
        action = node.get("action", "")
        if action == "set_bg":
            self.background = node.get("background", "")
        elif action == "show_character":
            cid   = node.get("character", "")
            pose  = node.get("pose", "default")
            slot  = node.get("position", "center")
            flip  = bool(node.get("flip", False))
            x, y  = self._slot_to_xy(slot)
            if cid in self.characters:
                self.characters[cid].pose    = pose
                self.characters[cid].flipped = flip
            else:
                self.characters[cid] = CharDisplay(cid, pose, x, y, flip)
        elif action == "hide_character":
            self.characters.pop(node.get("character", ""), None)
        elif action in ("move_character",):
            cid  = node.get("character", "")
            if cid in self.characters:
                if node.get("slot"):
                    x, y = self._slot_to_xy(node["slot"])
                    self.characters[cid].x = x
                    self.characters[cid].y = y
                elif node.get("x") is not None:
                    self.characters[cid].x = node["x"]
                    self.characters[cid].y = node.get("y", self.characters[cid].y)
        elif action == "flip_character":
            cid = node.get("character", "")
            if cid in self.characters:
                flipped = node.get("flipped", True)
                self.characters[cid].flipped = flipped

    def _apply_placement(self, node_id: str):
        """Apply placement overrides from the placement file for this node."""
        pd = self.placement_data.get(node_id)
        if not pd:
            return
        for cid, pos in pd.items():
            if cid not in self.characters:
                continue
            cd = self.characters[cid]
            if pos.get("x") is not None:
                cd.x = pos["x"]
            if pos.get("y") is not None:
                cd.y = pos["y"]
            if pos.get("flip") is not None:
                cd.flipped = pos["flip"]

    def _slot_to_xy(self, slot: str, stage_w: float = 1.0) -> Tuple[float, float]:
        ratio = SLOT_RATIOS.get(slot, 0.5)
        return ratio, 1.0   # normalised coords; renderer will scale


# ---------------------------------------------------------------------------
# Scene browser (reused from placement editor pattern)
# ---------------------------------------------------------------------------

class _Browser:
    def __init__(self, project_root: Path, font, small_font, theme):
        self.root        = project_root
        self.font        = font
        self.small_font  = small_font
        self.theme       = theme
        self.scenes      = self._find()
        self.selected    = 0
        self.scroll      = 0

    def _find(self) -> List[Dict]:
        scenes = []
        for base in [self.root / "assets" / "data" / "scenes"]:
            if not base.exists():
                continue
            for p in sorted(base.rglob("*.json")):
                try:
                    data = json.loads(p.read_text(encoding="utf-8"))
                    if "scene_id" in data and "nodes" in data:
                        scenes.append({
                            "path": p,
                            "label": str(p.relative_to(self.root)),
                            "scene_id": data.get("scene_id", "?"),
                            "node_count": len(data.get("nodes", [])),
                        })
                except Exception:
                    continue
        if not scenes:
            scenes.append({"path": None, "label": "No scenes found",
                           "scene_id": "", "node_count": 0})
        return scenes

    def handle_event(self, event) -> Optional[Dict]:
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_UP:
                self.selected = max(0, self.selected - 1)
            elif event.key == pygame.K_DOWN:
                self.selected = min(len(self.scenes) - 1, self.selected + 1)
            elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                return self.scenes[self.selected] if self.scenes else None
            elif event.key == pygame.K_r:
                self.scenes = self._find()
                self.selected = 0
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            r = self._rect(event.pos[0], event.pos[1])
            if r is not None:
                return self.scenes[r]
        elif event.type == pygame.MOUSEWHEEL:
            self.scroll = max(0, self.scroll - event.y * 30)
        return None

    def _rect(self, mx: int, my: int) -> Optional[int]:
        br = self._browser_rect(800, 600)
        ly = br.y + 80; ih = 58
        for i, info in enumerate(self.scenes):
            iy = ly + i * ih - self.scroll
            row = pygame.Rect(br.x + 14, iy, br.width - 28, ih - 4)
            if row.collidepoint(mx, my):
                self.selected = i
                return i
        return None

    def _browser_rect(self, sw: int, sh: int) -> pygame.Rect:
        w = min(820, sw - 80); h = min(620, sh - 80)
        return pygame.Rect((sw - w) // 2, (sh - h) // 2, w, h)

    def draw(self, surface: pygame.Surface):
        sw, sh = surface.get_size()
        overlay = pygame.Surface((sw, sh), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 210))
        surface.blit(overlay, (0, 0))
        br = self._browser_rect(sw, sh)
        pygame.draw.rect(surface, self.theme.bg_medium, br, border_radius=12)
        pygame.draw.rect(surface, self.theme.border, br, 2, border_radius=12)

        ts, _ = self.font.render("Scene Preview — Select Scene", self.theme.text_primary)
        surface.blit(ts, ts.get_rect(centerx=br.centerx, y=br.y + 16))
        hs, _ = self.small_font.render("↑↓ navigate · Enter load · R refresh · Esc back", self.theme.text_secondary)
        surface.blit(hs, hs.get_rect(centerx=br.centerx, y=br.y + 50))

        ly = br.y + 78; ih = 58
        for i, info in enumerate(self.scenes):
            iy  = ly + i * ih - self.scroll
            row = pygame.Rect(br.x + 14, iy, br.width - 28, ih - 4)
            if row.bottom < br.y + 70 or row.top > br.bottom - 8:
                continue
            sel = i == self.selected
            pygame.draw.rect(surface, self.theme.accent_blue if sel else self.theme.bg_light,
                             row, border_radius=6)
            pygame.draw.rect(surface, self.theme.border, row, 1, border_radius=6)
            rs, _  = self.font.render(info["label"], self.theme.text_primary)
            ids, _ = self.small_font.render(f"id: {info['scene_id']}  ·  {info['node_count']} nodes",
                                            self.theme.text_secondary)
            surface.blit(rs,  (row.x + 10, row.y + 6))
            surface.blit(ids, (row.x + 10, row.y + 28))


# ---------------------------------------------------------------------------
# Main module
# ---------------------------------------------------------------------------

class ScenePreview:
    """Full VN scene playback inside the editor."""

    # Dialogue box proportions
    BOX_HEIGHT_RATIO  = 0.26   # fraction of total height
    TYPEWRITER_SPEED  = 40     # chars per second

    def __init__(self, workspace_rect, theme, project_root: Path):
        self.rect         = workspace_rect
        self.theme        = theme
        self.project_root = project_root

        self.font        = pygame.freetype.SysFont("Arial", 16)
        self.title_font  = pygame.freetype.SysFont("Arial", 20, bold=True)
        self.small_font  = pygame.freetype.SysFont("Arial", 13)
        self.speaker_font= pygame.freetype.SysFont("Arial", 18, bold=True)
        self.dialogue_font = pygame.freetype.SysFont("Arial", 17)
        self.mono_font   = pygame.freetype.SysFont("Courier New", 13)

        self.cache   = _Cache(project_root)
        self.browser = _Browser(project_root, self.title_font, self.small_font, theme)

        self.show_browser = True
        self.engine: Optional[VNEngine] = None
        self.scene_label = ""
        self.scene_path: Optional[Path] = None

        # Typewriter state
        self._full_text   = ""
        self._shown_chars = 0.0
        self._typing      = False
        self._type_speed  = self.TYPEWRITER_SPEED

        # HUD
        self.status_msg   = ""
        self.status_timer = 0.0

        # History nav
        self._at_start = True

        # Auto-dimmed background for dialogue box
        self._box_surf: Optional[pygame.Surface] = None
        self._box_size = (0, 0)

    # -----------------------------------------------------------------------
    # Scene loading
    # -----------------------------------------------------------------------

    def _load_scene(self, info: Dict):
        if not info.get("path") or not info["path"].exists():
            self._status("Invalid scene path", 3.0)
            return
        try:
            scene_data   = json.loads(info["path"].read_text(encoding="utf-8"))
            scene_id     = scene_data.get("scene_id", "unknown")
            placement    = self.cache.load_placement(scene_id)
            self.engine  = VNEngine(scene_data, placement)
            self.scene_label = info["label"]
            self.scene_path  = info["path"]
            self.show_browser = False
            self._at_start    = True
            self._advance_to_display()
            self._status(f"Loaded: {info['label']}", 3.0)
        except Exception as e:
            self._status(f"Error loading scene: {e}", 4.0)

    def _reload(self):
        if self.scene_path and self.scene_path.exists():
            info = {"path": self.scene_path, "label": self.scene_label}
            self._load_scene(info)

    def _advance_to_display(self):
        if self.engine:
            self.engine.advance()
            self._start_typewriter(self.engine.text)

    # -----------------------------------------------------------------------
    # Typewriter
    # -----------------------------------------------------------------------

    def _start_typewriter(self, text: str):
        self._full_text   = text
        self._shown_chars = 0.0
        self._typing      = len(text) > 0

    def _skip_typewriter(self):
        self._shown_chars = float(len(self._full_text))
        self._typing      = False

    def _displayed_text(self) -> str:
        return self._full_text[:int(self._shown_chars)]

    # -----------------------------------------------------------------------
    # Event handling
    # -----------------------------------------------------------------------

    def handle_event(self, event):
        if self.show_browser:
            result = self.browser.handle_event(event)
            if result:
                self._load_scene(result)
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                if self.engine:
                    self.show_browser = False
            return

        if event.type == pygame.KEYDOWN:
            mods = pygame.key.get_mods()
            ctrl = mods & pygame.KMOD_CTRL

            if ctrl and event.key == pygame.K_l:
                self.show_browser = True; return
            if event.key == pygame.K_ESCAPE:
                self.show_browser = True; return
            if event.key == pygame.K_r:
                self._reload(); return

            if event.key in (pygame.K_SPACE, pygame.K_RETURN):
                self._on_advance(); return
            if event.key == pygame.K_BACKSPACE or event.key == pygame.K_LEFT:
                self._on_back(); return
            if event.key == pygame.K_RIGHT:
                self._on_advance(); return

            # Choice keyboard shortcuts
            if self.engine and self.engine.choices:
                if event.key == pygame.K_1: self._pick(0); return
                if event.key == pygame.K_2: self._pick(1); return
                if event.key == pygame.K_3: self._pick(2); return
                if event.key == pygame.K_4: self._pick(3); return
                if event.key == pygame.K_5: self._pick(4); return

        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.engine and self.engine.choices:
                # Check choice buttons
                buttons = self._choice_buttons()
                for i, rect in enumerate(buttons):
                    if rect.collidepoint(event.pos):
                        self._pick(i)
                        return
            self._on_advance()

    def _on_advance(self):
        if not self.engine:
            return
        if self._typing:
            self._skip_typewriter()
            return
        if self.engine.at_end:
            return
        if self.engine.choices:
            return   # must click a button
        self.engine.step_next()
        self.engine.advance()
        self._start_typewriter(self.engine.text)

    def _on_back(self):
        if not self.engine:
            return
        if self.engine.step_back():
            self._skip_typewriter()

    def _pick(self, index: int):
        if not self.engine or not self.engine.choices:
            return
        self.engine.pick_choice(index)
        self.engine.advance()
        self._start_typewriter(self.engine.text)

    # -----------------------------------------------------------------------
    # Update
    # -----------------------------------------------------------------------

    def update(self, dt: float):
        if self.status_timer > 0:
            self.status_timer -= dt
            if self.status_timer <= 0:
                self.status_msg = ""

        if self._typing:
            self._shown_chars = min(
                len(self._full_text),
                self._shown_chars + self._type_speed * dt
            )
            if self._shown_chars >= len(self._full_text):
                self._typing = False

    # -----------------------------------------------------------------------
    # Drawing
    # -----------------------------------------------------------------------

    def draw(self, surface: pygame.Surface):
        surface.fill(self.theme.bg_dark)

        if self.show_browser:
            self.browser.draw(surface)
            return

        if not self.engine:
            ms, _ = self.title_font.render("No scene loaded — press Ctrl+L", self.theme.text_disabled)
            surface.blit(ms, ms.get_rect(center=(self.rect.width // 2, self.rect.height // 2)))
            return

        w, h = surface.get_size()
        box_h = int(h * self.BOX_HEIGHT_RATIO)
        stage_h = h - box_h - 38  # 38px for top HUD bar

        self._draw_hud(surface, w)
        self._draw_stage(surface, w, 38, stage_h)
        self._draw_dialogue_box(surface, w, h, stage_h + 38, box_h)
        self._draw_status(surface, w, h)

    def _draw_hud(self, surface: pygame.Surface, w: int):
        pygame.draw.rect(surface, self.theme.bg_medium, pygame.Rect(0, 0, w, 36))
        pygame.draw.line(surface, self.theme.border, (0, 36), (w, 36), 1)

        lbl, _ = self.small_font.render(
            f"Scene Preview  ·  {self.scene_label}", self.theme.text_secondary)
        surface.blit(lbl, (10, 10))

        hints = "Space/Enter advance · ← back · 1-5 choose · R reload · Ctrl+L scene list"
        hs, _ = self.small_font.render(hints, self.theme.text_disabled)
        surface.blit(hs, (w - hs.get_width() - 10, 11))

    def _draw_stage(self, surface: pygame.Surface, w: int, top: int, h: int):
        stage = pygame.Rect(0, top, w, h)

        # Background
        bg_surf = self.cache.bg(self.engine.background, w, h) if self.engine.background else None
        if bg_surf:
            bx = (w - bg_surf.get_width()) // 2
            by = top + (h - bg_surf.get_height()) // 2
            surface.blit(bg_surf, (bx, by))
        else:
            # Gradient fallback
            for i in range(h):
                t  = i / h
                cr = int(18 + 25 * t); cg = int(14 + 18 * t); cb = int(30 + 35 * t)
                pygame.draw.line(surface, (cr, cg, cb), (0, top + i), (w, top + i))

        if not self.engine:
            return

        # Characters (sorted by speaking status so speaker renders last = on top)
        chars = sorted(self.engine.characters.values(),
                       key=lambda c: 1 if c.is_speaking else 0)
        char_h = int(h * CHAR_HEIGHT_RATIO)

        for cd in chars:
            surf = self.cache.character(cd.char_id, char_h)
            if surf:
                if cd.flipped:
                    surf = pygame.transform.flip(surf, True, False)
                # Scale
                sw_orig, sh_orig = surf.get_size()
                sw2 = int(sw_orig * cd.scale)
                sh2 = int(sh_orig * cd.scale)
                if sw2 != sw_orig or sh2 != sh_orig:
                    surf = pygame.transform.smoothscale(surf, (sw2, sh2))
                # Alpha
                if cd.alpha < 255:
                    surf = surf.copy()
                    surf.set_alpha(cd.alpha)
                # Position: cd.x/y are 0..1 ratios
                cx  = int(cd.x * w) if cd.x <= 1.0 else int(cd.x)
                cy  = top + h      # draw from bottom of stage
                dx  = cx - sw2 // 2
                dy  = cy - sh2
                surface.blit(surf, (dx, dy))
            else:
                # Silhouette placeholder
                cx  = int(cd.x * w) if cd.x <= 1.0 else int(cd.x)
                ph  = int(char_h * cd.scale)
                pw  = int(ph * 0.45)
                prect = pygame.Rect(cx - pw // 2, top + h - ph, pw, ph)
                col  = (100, 80, 140) if not cd.is_speaking else (80, 120, 220)
                palpha = cd.alpha
                ps   = pygame.Surface((pw, ph), pygame.SRCALPHA)
                ps.fill((*col, palpha))
                surface.blit(ps, prect)
                nt, _ = self.small_font.render(cd.char_id, self.theme.text_primary)
                surface.blit(nt, (prect.centerx - nt.get_width() // 2, prect.y + 6))

    def _draw_dialogue_box(self, surface: pygame.Surface, w: int, total_h: int,
                            box_top: int, box_h: int):
        # Semi-transparent box
        key = (w, box_h)
        if self._box_surf is None or self._box_size != key:
            self._box_surf = pygame.Surface((w, box_h), pygame.SRCALPHA)
            self._box_surf.fill((12, 10, 20, 210))
            # Top border line
            pygame.draw.line(self._box_surf, (80, 80, 120, 180), (0, 0), (w, 0), 2)
            self._box_size = key
        surface.blit(self._box_surf, (0, box_top))

        if not self.engine:
            return

        pad = 28
        inner_x = pad
        inner_y = box_top + 10

        # Speaker name
        if self.engine.speaker:
            # Name backing
            sn, _ = self.speaker_font.render(self.engine.speaker, (255, 255, 255))
            name_rect = pygame.Rect(inner_x - 6, inner_y - 4, sn.get_width() + 16, sn.get_height() + 8)
            pygame.draw.rect(surface, (50, 40, 80, 220), name_rect, border_radius=4)
            pygame.draw.rect(surface, (120, 90, 200, 180), name_rect, 1, border_radius=4)
            surface.blit(sn, (inner_x + 2, inner_y))
            inner_y += sn.get_height() + 10

        # Dialogue text (word-wrapped)
        text = self._displayed_text()
        max_text_w = w - pad * 2
        self._draw_wrapped(surface, text, inner_x, inner_y, max_text_w,
                           box_top + box_h - pad, self.dialogue_font,
                           (220, 220, 225) if not self.engine.is_narration else (180, 190, 210))

        # Typing cursor blink
        if self._typing:
            t      = time.time()
            blink  = int(t * 4) % 2 == 0
            if blink:
                cur, _ = self.dialogue_font.render("█", (150, 140, 200))
                surface.blit(cur, (inner_x + 2, inner_y + 2))

        # Advance arrow
        if not self._typing and not self.engine.at_end and not self.engine.choices:
            t = time.time()
            bounce = int((math.sin(t * 4) + 1) * 4)
            arr, _ = self.font.render("▼", (160, 140, 220))
            surface.blit(arr, (w - pad, box_top + box_h - arr.get_height() - 8 - bounce))

        # End marker
        if self.engine.at_end:
            es, _ = self.font.render("— End of scene —", (120, 100, 160))
            surface.blit(es, (w // 2 - es.get_width() // 2, box_top + box_h - es.get_height() - 10))

        # Choices
        if self.engine.choices and not self._typing:
            self._draw_choices(surface, w, box_top, box_h)

    def _draw_wrapped(self, surface: pygame.Surface, text: str, x: int, y: int,
                      max_w: int, max_y: int, font, color):
        """Render word-wrapped text, returns final y."""
        words    = text.split(" ")
        line     = ""
        line_h   = font.get_sized_height() + 4
        cur_y    = y
        for word in words:
            test = (line + " " + word).strip() if line else word
            ts, _ = font.render(test, color)
            if ts.get_width() > max_w and line:
                ls, _ = font.render(line, color)
                surface.blit(ls, (x, cur_y))
                cur_y += line_h
                line   = word
                if cur_y + line_h > max_y:
                    break
            else:
                line = test
        if line and cur_y + line_h <= max_y:
            ls, _ = font.render(line, color)
            surface.blit(ls, (x, cur_y))

    def _choice_buttons(self) -> List[pygame.Rect]:
        if not self.engine or not self.engine.choices:
            return []
        w, h = self.rect.width, self.rect.height
        box_h = int(h * self.BOX_HEIGHT_RATIO)
        box_top = h - box_h
        n     = len(self.engine.choices)
        bw    = int(w * 0.55)
        bh    = 36
        gap   = 8
        total = n * bh + (n - 1) * gap
        start_y = box_top + (box_h - total) // 2
        cx    = (w - bw) // 2
        return [pygame.Rect(cx, start_y + i * (bh + gap), bw, bh)
                for i in range(n)]

    def _draw_choices(self, surface: pygame.Surface, w: int, box_top: int, box_h: int):
        buttons = self._choice_buttons()
        mx, my  = pygame.mouse.get_pos()
        for i, (rect, choice) in enumerate(zip(buttons, self.engine.choices)):
            hovered = rect.collidepoint(mx, my)
            bg_col  = (90, 70, 130, 220) if hovered else (45, 35, 75, 200)
            bd_col  = (180, 140, 255) if hovered else (100, 80, 160)
            bs = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
            bs.fill(bg_col)
            surface.blit(bs, rect)
            pygame.draw.rect(surface, bd_col, rect, 2, border_radius=6)
            lbl  = f"{i + 1}. {choice.get('text', '?')}"
            ls, _ = self.font.render(lbl, (230, 220, 255) if hovered else (190, 180, 220))
            surface.blit(ls, (rect.x + 12, rect.y + (rect.height - ls.get_height()) // 2))

    def _draw_status(self, surface: pygame.Surface, w: int, h: int):
        if not self.status_msg:
            return
        ss, _ = self.small_font.render(self.status_msg, self.theme.accent_green)
        surface.blit(ss, (10, h - ss.get_height() - 6))

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------

    def _status(self, msg: str, dur: float = 3.0):
        self.status_msg   = msg
        self.status_timer = dur

    def on_resize(self, rect):
        self.rect      = rect
        self._box_surf = None
        self.browser   = _Browser(self.project_root, self.title_font, self.small_font, self.theme)

    def get_help_entries(self):
        return [
            ("Playback", [
                "Space / Enter / LMB  — advance dialogue (or skip typewriter)",
                "Backspace / ←  — step back one dialogue entry",
                "1-5  — keyboard shortcut for choice buttons",
                "R  — reload current scene from disk",
            ]),
            ("Navigation", [
                "Ctrl+L / Esc  — open scene browser",
            ]),
            ("Features", [
                "Loads real background images from assets/images/bg/",
                "Loads real character sprites from assets/images/characters/",
                "Speaker name, emphasis (DDLC-style), typewriter text",
                "Branching choices rendered as clickable buttons",
                "show/hide_character, move_character, flip_character all simulated",
                "Reads placement files for precise character positions",
            ]),
        ]

    def cleanup(self):
        pass
