"""Chart Editor — full overhaul.

Architecture
============
* Sections list (left panel): each section owns BPM, mustHitSection, singers, length.
* Multi-track grid (center): player track (lanes 0-3, positive) + one NPC track per
  additional singer (negative lanes -1..-4 per character, all 4 directions).
* Character preview (right panel): renders actual sprite sheets; animates when a note
  is placed or during playback.
* Undo / redo for all note edits (up to 100 steps).
* Import / export exactly matches the Haxe engine schema (singers array, no playerLaneCount).

Lane convention (matches ChartHandler.hx)
==========================================
  Positive lanes 0-3   → singers[0] (player), judged when mustHitSection=True
  Negative lanes -1..-4 → singers[-1] (last singer), animation-only
    -1=DOWN  -2=UP  -3=RIGHT  -4=LEFT
  Negative lanes -5..-8 → singers[-2], etc.

Snap grid
=========
  Divisions: 4 (quarter), 8 (eighth), 16 (sixteenth), 32 (thirty-second)
  Grid rows always represent 1/32 of a beat for maximum precision.
  Snap rounds to the chosen division.
"""
from __future__ import annotations

import json
import math
import struct
import wave
from copy import deepcopy
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pygame
import pygame.freetype
import pygame.transform

from modules.ui.widgets import TextInput

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DIVISIONS = [4, 8, 16, 32]          # selectable snap grids
ROWS_PER_BEAT = 32                   # internal resolution (1 row = 1/32 beat)
SECTION_BEATS = 16                   # beats per section (standard FNF)

DIR_NAMES  = ["LEFT", "DOWN", "UP", "RIGHT"]
DIR_COLORS = [
    (200, 80,  80),   # LEFT  – red
    (80,  180, 90),   # DOWN  – green
    (80,  120, 220),  # UP    – blue
    (220, 190, 70),   # RIGHT – yellow
]

# NPC lane encoding: lane index → (direction, display color shade factor)
# lane -1 → DOWN, -2 → UP, -3 → RIGHT, -4 → LEFT (matches ChartHandler.hx fix)
NPC_LANE_DIR = {-1: 1, -2: 2, -3: 3, -4: 0}   # negative lane → animDirection 0-3

NOTE_TYPE_COLORS = [
    (80,  140, 255),   # 0 Normal
    (255, 100, 255),   # 1 Special 1
    (100, 255, 100),   # 2 Special 2
    (255, 200, 80),    # 3 Special 3
]

CHAR_COLORS = [
    (80,  140, 255),
    (255, 100, 100),
    (100, 220, 140),
    (255, 200, 80),
    (180, 120, 255),
    (80,  200, 200),
]


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

class ChartNote:
    """A single note in the internal model."""
    __slots__ = ("row", "lane", "hold_rows", "note_type")

    def __init__(self, row: int, lane: int, hold_rows: int = 0, note_type: int = 0):
        self.row       = row
        self.lane      = lane
        self.hold_rows = hold_rows   # 0 = tap
        self.note_type = note_type

    def to_raw(self, bpm: float) -> list:
        """Convert to [time_ms, lane, hold_ms, note_type] Psych-style entry."""
        step_ms   = (60_000.0 / bpm) / ROWS_PER_BEAT
        time_ms   = int(self.row * step_ms)
        hold_ms   = int(self.hold_rows * step_ms)
        return [time_ms, self.lane, hold_ms, self.note_type]

    @staticmethod
    def from_raw(raw: list, bpm: float) -> "ChartNote":
        step_ms   = (60_000.0 / bpm) / ROWS_PER_BEAT
        row       = int(round(raw[0] / step_ms))
        lane      = int(raw[1])
        hold_ms   = float(raw[2]) if len(raw) > 2 else 0.0
        hold_rows = int(round(hold_ms / step_ms)) if hold_ms > 0 else 0
        note_type = int(raw[3]) if len(raw) > 3 else 0
        return ChartNote(row, lane, hold_rows, note_type)


class ChartSection:
    """One chart section."""
    def __init__(self, bpm: Optional[float] = None,
                 must_hit: bool = True,
                 singers: Optional[List[str]] = None,
                 length_beats: int = SECTION_BEATS):
        self.bpm          = bpm          # None = inherit song BPM
        self.must_hit     = must_hit
        self.singers      = singers or []
        self.length_beats = length_beats
        self.notes: List[ChartNote] = []

    def length_rows(self) -> int:
        return self.length_beats * ROWS_PER_BEAT

    def effective_bpm(self, song_bpm: float) -> float:
        return self.bpm if self.bpm is not None else song_bpm


# ---------------------------------------------------------------------------
# Asset cache (sprites for preview)
# ---------------------------------------------------------------------------

class SpriteCache:
    """Loads and caches character sprite sheets for the preview panel."""

    def __init__(self, project_root: Path):
        self.root   = project_root
        self._cache: Dict[str, Optional[pygame.Surface]] = {}

    def get(self, char_id: str, max_h: int = 260) -> Optional[pygame.Surface]:
        key = f"{char_id}@{max_h}"
        if key in self._cache:
            return self._cache[key]
        surf = self._load(char_id, max_h)
        self._cache[key] = surf
        return surf

    def _load(self, char_id: str, max_h: int) -> Optional[pygame.Surface]:
        for sub in (char_id, f"{char_id}_rhythm"):
            for ext in (".png",):
                p = self.root / "assets" / "images" / "characters" / char_id / f"{sub}{ext}"
                if p.exists():
                    try:
                        surf = pygame.image.load(str(p)).convert_alpha()
                        w, h = surf.get_size()
                        scale = max_h / h
                        surf = pygame.transform.smoothscale(
                            surf, (max(1, int(w * scale)), max_h))
                        return surf
                    except Exception:
                        pass
        return None


# ---------------------------------------------------------------------------
# Undo/Redo
# ---------------------------------------------------------------------------

class UndoStack:
    def __init__(self, limit: int = 100):
        self._limit  = limit
        self._undos: list = []
        self._redos: list = []

    def push(self, snapshot):
        self._undos.append(snapshot)
        if len(self._undos) > self._limit:
            self._undos.pop(0)
        self._redos.clear()

    def undo(self):
        if not self._undos:
            return None
        snap = self._undos.pop()
        self._redos.append(snap)
        return snap

    def redo(self):
        if not self._redos:
            return None
        snap = self._redos.pop()
        self._undos.append(snap)
        return snap

    def can_undo(self): return bool(self._undos)
    def can_redo(self): return bool(self._redos)


# ---------------------------------------------------------------------------
# Audio helper
# ---------------------------------------------------------------------------

class AudioPlayer:
    """Thin wrapper around pygame.mixer.music with position tracking."""

    def __init__(self):
        self.loaded       = False
        self.playing      = False
        self.position_sec = 0.0   # tracked manually
        self.length_sec   = 0.0
        self.filepath: Optional[str] = None
        self.waveform: List[float]   = []
        self._play_start_ticks       = 0
        self._play_start_pos         = 0.0

    def load(self, path: str) -> bool:
        try:
            pygame.mixer.init()
            pygame.mixer.music.load(path)
            self.filepath    = path
            self.loaded      = True
            self.position_sec = 0.0
            self.length_sec  = self._probe_length(path)
            self.waveform    = self._make_waveform(path)
            return True
        except Exception:
            return False

    def play(self):
        if not self.loaded:
            return
        pygame.mixer.music.play(start=self.position_sec)
        self._play_start_ticks = pygame.time.get_ticks()
        self._play_start_pos   = self.position_sec
        self.playing = True

    def pause(self):
        if self.playing:
            pygame.mixer.music.pause()
            self.playing = False

    def stop(self):
        pygame.mixer.music.stop()
        self.playing      = False
        self.position_sec = 0.0

    def seek(self, seconds: float):
        self.position_sec = max(0.0, min(seconds, self.length_sec))
        if self.playing:
            pygame.mixer.music.play(start=self.position_sec)
            self._play_start_ticks = pygame.time.get_ticks()
            self._play_start_pos   = self.position_sec

    def update(self, dt: float):
        if self.playing:
            if not pygame.mixer.music.get_busy():
                self.playing      = False
                self.position_sec = self.length_sec
            else:
                elapsed = (pygame.time.get_ticks() - self._play_start_ticks) / 1000.0
                self.position_sec = min(self._play_start_pos + elapsed, self.length_sec)

    # ---- helpers ----

    @staticmethod
    def _probe_length(path: str) -> float:
        try:
            with wave.open(path, "rb") as wf:
                return wf.getnframes() / float(wf.getframerate())
        except Exception:
            pass
        return 180.0

    @staticmethod
    def _make_waveform(path: str, buckets: int = 600) -> List[float]:
        try:
            with wave.open(path, "rb") as wf:
                raw    = wf.readframes(wf.getnframes())
                ch     = wf.getnchannels()
                sw     = wf.getsampwidth()
                fmt    = {1: "b", 2: "h", 4: "i"}.get(sw, "h")
                samps  = struct.unpack(f"{len(raw)//sw}{fmt}", raw)
                # Mix to mono
                if ch > 1:
                    samps = [sum(samps[i:i+ch])//ch for i in range(0, len(samps), ch)]
                peak   = max(abs(s) for s in samps) or 1
                chunk  = max(1, len(samps) // buckets)
                return [
                    max(abs(s) for s in samps[i:i+chunk]) / peak
                    for i in range(0, len(samps), chunk)
                ][:buckets]
        except Exception:
            return [0.0] * buckets


# ---------------------------------------------------------------------------
# Layout constants for the editor
# ---------------------------------------------------------------------------

LEFT_W   = 260   # section/song panel
RIGHT_W  = 220   # character preview panel
TOOLBAR_H = 90   # top toolbar height
SNAP_H    = 24   # row height in grid
LANE_W    = 38   # pixels per lane column
HEADER_H  = 28   # column header height


# ---------------------------------------------------------------------------
# Main editor class
# ---------------------------------------------------------------------------

class ChartEditor:
    """Fully overhauled chart editor with multi-lane animation and live preview."""

    def __init__(self, workspace_rect: pygame.Rect, theme, project_root: Path):
        self.rect         = workspace_rect
        self.theme        = theme
        self.project_root = project_root

        self.font       = pygame.freetype.SysFont("Arial", 13)
        self.title_font = pygame.freetype.SysFont("Arial", 20, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 11)
        self.mono_font  = pygame.freetype.SysFont("Courier New", 11)

        # ---- Song metadata ----
        self.song_id      = ""
        self.song_bpm     = 120.0
        self.song_offset  = 0.0
        self.song_player  = ""
        self.song_stage   = ""
        # All unique singer IDs across the whole chart
        self.all_singers: List[str] = []

        # ---- Sections ----
        self.sections: List[ChartSection] = [
            ChartSection(must_hit=True, singers=[], length_beats=SECTION_BEATS)
        ]
        self.current_section = 0

        # ---- Inputs ----
        self.input_song    = TextInput(pygame.Rect(0,0,150,24), self.font, placeholder="song_id",  text="")
        self.input_bpm     = TextInput(pygame.Rect(0,0,80,24),  self.font, placeholder="BPM",      text="120")
        self.input_offset  = TextInput(pygame.Rect(0,0,70,24),  self.font, placeholder="offset",   text="0")
        self.input_player  = TextInput(pygame.Rect(0,0,120,24), self.font, placeholder="player id",text="")
        self.input_stage   = TextInput(pygame.Rect(0,0,120,24), self.font, placeholder="stage id", text="")
        self.input_singer  = TextInput(pygame.Rect(0,0,120,24), self.font, placeholder="singer id",text="")

        # ---- Grid state ----
        self.grid_scroll    = 0          # px from top
        self.snap_div       = 16         # current snap (rows per beat)
        self.snap_idx       = 2          # index into DIVISIONS
        self.row_height     = 14         # px per 1/32 beat row

        # ---- Note editing ----
        self.current_note_type = 0
        self.tool           = "tap"      # "tap", "hold", "erase"
        self.hold_start: Optional[Tuple[int,int]] = None   # (row, lane)
        self.hold_end_row   = 0

        # ---- Undo / redo ----
        self.undo           = UndoStack()

        # ---- Audio ----
        self.audio          = AudioPlayer()

        # ---- Preview ----
        self.sprites        = SpriteCache(project_root)
        # Which animation each character is showing in the preview: charID → animDir index
        self._preview_anim: Dict[str, int] = {}
        self._preview_timer: Dict[str, float] = {}

        # ---- UI state ----
        self.status_msg     = "Welcome! Ctrl+O load chart, Ctrl+S save, Ctrl+L load audio."
        self.status_color   = theme.text_secondary
        self.status_timer   = 0.0

        self._dragging_tl   = False      # dragging timeline
        self._section_scroll = 0         # section list scroll

    # =========================================================================
    # Public interface (called by main.py)
    # =========================================================================

    def handle_event(self, event):
        # Route to focused text inputs first
        for inp in (self.input_song, self.input_bpm, self.input_offset,
                    self.input_player, self.input_stage, self.input_singer):
            inp.handle_event(event)

        if event.type == pygame.KEYDOWN:
            self._handle_keydown(event)
            return

        if event.type == pygame.MOUSEWHEEL:
            grid = self._grid_rect()
            mp   = pygame.mouse.get_pos()
            if grid.collidepoint(mp):
                self._scroll(event.y * -self.row_height * 4)
            return

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            self._handle_click(event.pos)

        if event.type == pygame.MOUSEMOTION:
            self._handle_motion(event.pos)

        if event.type == pygame.MOUSEBUTTONUP and event.button == 1:
            self._handle_release(event.pos)

    def update(self, dt: float):
        self.audio.update(dt)
        if self.status_timer > 0:
            self.status_timer = max(0, self.status_timer - dt)
        # Auto-scroll grid to follow playhead
        if self.audio.playing:
            row = self._time_to_row_global(self.audio.position_sec * 1000)
            target = row * self.row_height - self._grid_rect().height // 2
            self.grid_scroll = max(0, target)
        # Decay preview animations
        for cid in list(self._preview_timer):
            self._preview_timer[cid] = max(0, self._preview_timer[cid] - dt)

    def draw(self, surface: pygame.Surface):
        surface.fill(self.theme.bg_dark)
        self._draw_toolbar(surface)
        self._draw_left_panel(surface)
        self._draw_grid(surface)
        self._draw_right_panel(surface)
        self._draw_status(surface)

    def on_resize(self, rect: pygame.Rect):
        self.rect = rect

    def cleanup(self):
        self.audio.stop()

    # =========================================================================
    # Keyboard
    # =========================================================================

    def _handle_keydown(self, event):
        ctrl  = event.mod & pygame.KMOD_CTRL
        shift = event.mod & pygame.KMOD_SHIFT

        if ctrl and event.key == pygame.K_s:
            self._save_chart(); return
        if ctrl and event.key == pygame.K_o:
            self._load_chart(); return
        if ctrl and event.key == pygame.K_l:
            self._browse_audio(); return
        if ctrl and event.key == pygame.K_z:
            self._do_undo(); return
        if ctrl and event.key == pygame.K_y:
            self._do_redo(); return

        if event.key == pygame.K_SPACE:
            if self.audio.playing: self.audio.pause()
            else:                  self.audio.play()
            return

        # Snap division cycling
        if event.key == pygame.K_TAB:
            self.snap_idx   = (self.snap_idx + (1 if not shift else -1)) % len(DIVISIONS)
            self.snap_div   = DIVISIONS[self.snap_idx]
            self._status(f"Snap: 1/{self.snap_div} beat", self.theme.text_secondary); return

        # Note type
        for i, k in enumerate([pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4]):
            if event.key == k:
                self.current_note_type = i
                self._status(f"Note type {i}", NOTE_TYPE_COLORS[i]); return

        # Tool
        if event.key == pygame.K_t: self.tool = "tap";   self._status("Tool: tap",   self.theme.text_secondary)
        if event.key == pygame.K_h: self.tool = "hold";  self._status("Tool: hold",  self.theme.text_secondary)
        if event.key == pygame.K_e: self.tool = "erase"; self._status("Tool: erase", self.theme.text_secondary)

        # Section navigation
        if event.key == pygame.K_PAGEDOWN:
            self.current_section = min(len(self.sections)-1, self.current_section+1)
            self._jump_to_section(self.current_section)
        if event.key == pygame.K_PAGEUP:
            self.current_section = max(0, self.current_section-1)
            self._jump_to_section(self.current_section)

        # mustHitSection toggle
        if ctrl and event.key == pygame.K_h:
            sec = self.sections[self.current_section]
            sec.must_hit = not sec.must_hit
            self._status(f"Section mustHit = {sec.must_hit}", self.theme.accent_blue)

    # =========================================================================
    # Mouse
    # =========================================================================

    def _handle_click(self, pos):
        # ---- toolbar buttons ----
        for label, rect, cb in self._toolbar_buttons():
            if rect.collidepoint(pos):
                cb(); return

        # ---- timeline ----
        tl = self._timeline_rect()
        if tl.collidepoint(pos):
            self._seek_from_timeline(pos, tl)
            self._dragging_tl = True; return

        # ---- section list ----
        sl = self._section_list_rect()
        if sl.collidepoint(pos):
            self._handle_section_click(pos, sl); return

        # ---- add singer button (left panel) ----
        asb = self._add_singer_btn()
        if asb.collidepoint(pos):
            self._add_singer_to_section(); return

        # ---- snap buttons ----
        for i, rect in enumerate(self._snap_rects()):
            if rect.collidepoint(pos):
                self.snap_idx = i
                self.snap_div = DIVISIONS[i]
                return

        # ---- grid ----
        grid = self._grid_rect()
        if grid.collidepoint(pos):
            self._handle_grid_click(pos, grid)

    def _handle_motion(self, pos):
        if self._dragging_tl:
            tl = self._timeline_rect()
            self._seek_from_timeline(pos, tl)
        if self.hold_start is not None:
            grid = self._grid_rect()
            if grid.collidepoint(pos):
                rel_y = pos[1] - (grid.top + HEADER_H)
                raw_row = (rel_y + self.grid_scroll) // self.row_height
                self.hold_end_row = int(self._snap_row(raw_row))

    def _handle_release(self, pos):
        self._dragging_tl = False
        if self.hold_start is not None:
            self._finish_hold(pos)

    # =========================================================================
    # Grid interaction
    # =========================================================================

    def _handle_grid_click(self, pos, grid: pygame.Rect):
        lane_map, total_lanes = self._section_lane_map()
        if total_lanes == 0:
            return

        col_w     = self._col_width(grid, total_lanes)
        rel_x     = pos[0] - grid.left
        rel_y     = pos[1] - (grid.top + HEADER_H)
        col_idx   = int(rel_x // col_w)
        raw_row   = (rel_y + self.grid_scroll) // self.row_height

        if col_idx < 0 or col_idx >= total_lanes:
            return

        lane      = lane_map[col_idx]
        row       = int(self._snap_row(raw_row))
        sec_row   = self._global_row_to_section_row(row)

        if sec_row < 0:
            return

        if self.tool == "erase":
            self._push_undo()
            self.sections[self.current_section].notes = [
                n for n in self.sections[self.current_section].notes
                if not (n.row == sec_row and n.lane == lane)
            ]
            self._trigger_preview(lane)
            return

        if self.tool == "hold":
            self.hold_start   = (sec_row, lane)
            self.hold_end_row = sec_row
            return

        # tap
        self._push_undo()
        self._place_note(sec_row, lane, 0)
        self._trigger_preview(lane)

    def _finish_hold(self, _):
        if self.hold_start is None:
            return
        start_row, lane = self.hold_start
        end_row = self.hold_end_row

        if end_row > start_row:
            self._push_undo()
            hold_rows = end_row - start_row
            self._place_note(start_row, lane, hold_rows)
            self._trigger_preview(lane)

        self.hold_start   = None
        self.hold_end_row = 0

    def _place_note(self, sec_row: int, lane: int, hold_rows: int):
        sec   = self.sections[self.current_section]
        # Remove any note already at this position
        sec.notes = [n for n in sec.notes if not (n.row == sec_row and n.lane == lane)]
        sec.notes.append(ChartNote(sec_row, lane, hold_rows, self.current_note_type))

    # =========================================================================
    # Section helpers
    # =========================================================================

    def _jump_to_section(self, idx: int):
        """Scroll grid to the start of section idx."""
        sec_start = sum(s.length_rows() for s in self.sections[:idx])
        self.grid_scroll = sec_start * self.row_height

    def _section_start_row(self, idx: int) -> int:
        return sum(self.sections[i].length_rows() for i in range(idx))

    def _global_row_to_section_row(self, global_row: int) -> int:
        """Convert a global grid row to a section-local row. Returns -1 if outside current section."""
        sec_start = self._section_start_row(self.current_section)
        sec_end   = sec_start + self.sections[self.current_section].length_rows()
        if global_row < sec_start or global_row >= sec_end:
            return -1
        return global_row - sec_start

    def _snap_row(self, raw: float) -> int:
        step = ROWS_PER_BEAT // self.snap_div
        return int(raw // step) * step

    def _total_rows(self) -> int:
        return sum(s.length_rows() for s in self.sections)

    def _time_to_row_global(self, time_ms: float) -> int:
        """Convert absolute time_ms to a global grid row."""
        accumulated_ms  = 0.0
        accumulated_row = 0
        for sec in self.sections:
            bpm        = sec.effective_bpm(self.song_bpm)
            step_ms    = (60_000.0 / bpm) / ROWS_PER_BEAT
            sec_ms     = sec.length_rows() * step_ms
            if time_ms <= accumulated_ms + sec_ms:
                local_ms  = time_ms - accumulated_ms
                return accumulated_row + int(local_ms / step_ms)
            accumulated_ms  += sec_ms
            accumulated_row += sec.length_rows()
        return accumulated_row

    # =========================================================================
    # Lane layout
    # =========================================================================

    def _section_lane_map(self) -> Tuple[List[int], int]:
        """
        Returns (lane_map, count).
        lane_map[col] = the actual chart lane value.
        Player: cols 0-3 → lanes 0-3.
        NPC i (index into extra singers): cols (4 + i*4) .. (4 + i*4 + 3) → lanes -(1..4) offset.
        """
        sec = self.sections[self.current_section]
        singers = sec.singers if sec.singers else self.all_singers

        lane_map: List[int] = list(range(4))   # player lanes 0-3

        if len(singers) >= 2:
            # Extra singers use negative lanes
            extra = singers[1:]
            for gi, _ in enumerate(extra):
                # lanes -1..-4 for gi=0, -5..-8 for gi=1, etc.
                base = -(gi * 4 + 1)
                # DOWN=-1, UP=-2, RIGHT=-3, LEFT=-4
                for di in range(4):
                    lane_map.append(base - di)

        return lane_map, len(lane_map)

    def _col_width(self, grid: pygame.Rect, total_lanes: int) -> int:
        return max(LANE_W, grid.width // total_lanes)

    # =========================================================================
    # Singer management
    # =========================================================================

    def _add_singer_to_section(self):
        sid = self.input_singer.get_value().strip()
        if not sid:
            self._status("Enter a singer ID first", self.theme.accent_red); return
        sec = self.sections[self.current_section]
        if sid not in sec.singers:
            sec.singers.append(sid)
        if sid not in self.all_singers:
            self.all_singers.append(sid)
        self.input_singer.set_value("")
        self._status(f"Added singer '{sid}' to section {self.current_section+1}", self.theme.accent_green)

    def _section_add(self):
        sec = self.sections[self.current_section]
        new_sec = ChartSection(
            bpm       = sec.bpm,
            must_hit  = sec.must_hit,
            singers   = list(sec.singers),
            length_beats = SECTION_BEATS
        )
        insert_at = self.current_section + 1
        self.sections.insert(insert_at, new_sec)
        self.current_section = insert_at
        self._jump_to_section(insert_at)
        self._status("Section added", self.theme.accent_green)

    def _section_remove(self):
        if len(self.sections) <= 1:
            self._status("Cannot remove the only section", self.theme.accent_red); return
        self.sections.pop(self.current_section)
        self.current_section = min(self.current_section, len(self.sections)-1)
        self._jump_to_section(self.current_section)
        self._status("Section removed", self.theme.accent_red)

    def _toggle_must_hit(self):
        sec = self.sections[self.current_section]
        sec.must_hit = not sec.must_hit
        self._status(f"mustHit = {sec.must_hit}", self.theme.accent_blue)

    # =========================================================================
    # Preview trigger
    # =========================================================================

    def _trigger_preview(self, lane: int):
        """Flash the character animation in the preview panel for the given lane."""
        sec     = self.sections[self.current_section]
        singers = sec.singers if sec.singers else self.all_singers
        if not singers:
            return

        if lane >= 0:
            anim_dir = lane % 4
            char_id  = singers[0] if singers else ""
        else:
            abs_lane  = abs(lane)
            group_idx = (abs_lane - 1) // 4
            anim_dir  = (abs_lane - 1) % 4   # 0=LEFT,1=DOWN,2=UP,3=RIGHT mapped as index
            # animDirection in engine: abs(lane)%4, but -1→1,-2→2,-3→3,-4→0
            anim_dir  = abs_lane % 4          # matches engine formula
            singer_idx = len(singers) - 1 - group_idx
            char_id    = singers[singer_idx] if 0 <= singer_idx < len(singers) else ""

        if char_id:
            self._preview_anim[char_id]  = anim_dir
            self._preview_timer[char_id] = 0.6    # seconds to show anim

    # =========================================================================
    # Timeline
    # =========================================================================

    def _seek_from_timeline(self, pos, tl: pygame.Rect):
        if self.audio.length_sec <= 0:
            return
        t = max(0.0, min(1.0, (pos[0] - tl.left) / tl.width))
        self.audio.seek(t * self.audio.length_sec)

    # =========================================================================
    # Section list click
    # =========================================================================

    def _handle_section_click(self, pos, sl: pygame.Rect):
        row_h  = 52
        rel_y  = pos[1] - sl.top + self._section_scroll
        idx    = rel_y // row_h
        if 0 <= idx < len(self.sections):
            self.current_section = idx
            self._jump_to_section(idx)

    # =========================================================================
    # Undo / redo
    # =========================================================================

    def _push_undo(self):
        snapshot = {
            "sections": deepcopy(self.sections),
            "current": self.current_section
        }
        self.undo.push(snapshot)

    def _do_undo(self):
        snap = self.undo.undo()
        if snap:
            self.sections        = snap["sections"]
            self.current_section = snap["current"]
            self._status("Undo", self.theme.text_secondary)
        else:
            self._status("Nothing to undo", self.theme.text_disabled)

    def _do_redo(self):
        snap = self.undo.redo()
        if snap:
            self.sections        = snap["sections"]
            self.current_section = snap["current"]
            self._status("Redo", self.theme.text_secondary)
        else:
            self._status("Nothing to redo", self.theme.text_disabled)

    # =========================================================================
    # Import / Export
    # =========================================================================

    def _export_chart(self) -> dict:
        # Rebuild all_singers from section singers
        all_singers: List[str] = []
        for sec in self.sections:
            for s in sec.singers:
                if s not in all_singers:
                    all_singers.append(s)
        if not all_singers and self.all_singers:
            all_singers = list(self.all_singers)

        raw_sections = []
        for sec in self.sections:
            bpm = sec.effective_bpm(self.song_bpm)
            raw_notes = [n.to_raw(bpm) for n in sec.notes]
            entry: dict = {
                "sectionNotes": raw_notes,
                "mustHitSection": sec.must_hit,
                "lengthInSteps": sec.length_beats * 4,
                "singers": sec.singers if sec.singers else all_singers,
            }
            if sec.bpm is not None:
                entry["bpm"] = sec.bpm
            raw_sections.append(entry)

        return {
            "song": {
                "song":    self.song_id or "untitled",
                "bpm":     self.song_bpm,
                "offset":  self.song_offset,
                "player":  self.song_player,
                "singers": all_singers,
                "stage":   self.song_stage,
                "notes":   raw_sections,
            }
        }

    def _import_chart(self, data: dict):
        song = data.get("song", {})

        self.song_id     = song.get("song", "")
        self.song_bpm    = float(song.get("bpm", 120))
        self.song_offset = float(song.get("offset", 0))
        self.song_player = song.get("player", "")
        self.song_stage  = song.get("stage", "")
        self.all_singers = song.get("singers", [])

        self.input_song.set_value(self.song_id)
        self.input_bpm.set_value(str(self.song_bpm))
        self.input_offset.set_value(str(self.song_offset))
        self.input_player.set_value(self.song_player)
        self.input_stage.set_value(self.song_stage)

        self.sections = []
        for raw_sec in song.get("notes", []):
            bpm_override = raw_sec.get("bpm")
            sec = ChartSection(
                bpm          = float(bpm_override) if bpm_override else None,
                must_hit     = raw_sec.get("mustHitSection", True),
                singers      = raw_sec.get("singers", list(self.all_singers)),
                length_beats = raw_sec.get("lengthInSteps", 64) // 4,
            )
            bpm = sec.effective_bpm(self.song_bpm)
            for raw_note in raw_sec.get("sectionNotes", []):
                sec.notes.append(ChartNote.from_raw(raw_note, bpm))
            self.sections.append(sec)

        if not self.sections:
            self.sections = [ChartSection(singers=list(self.all_singers))]
        self.current_section = 0
        self.grid_scroll     = 0

    # =========================================================================
    # File dialogs
    # =========================================================================

    def _save_chart(self):
        try:
            import tkinter as tk
            from tkinter import filedialog
            root = tk.Tk(); root.withdraw(); root.attributes("-topmost", True)
            default = (self.song_id or "chart") + ".json"
            path = filedialog.asksaveasfilename(
                title="Save Chart", defaultextension=".json",
                filetypes=[("JSON","*.json"),("All","*.*")],
                initialfile=default,
                initialdir=str(self.project_root / "assets" / "data" / "charts")
            )
            root.destroy()
            if path:
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(self._export_chart(), f, indent=2)
                self._status(f"Saved: {Path(path).name}", self.theme.accent_green)
        except Exception as ex:
            self._status(f"Save error: {ex}", self.theme.accent_red)

    def _load_chart(self):
        try:
            import tkinter as tk
            from tkinter import filedialog
            root = tk.Tk(); root.withdraw(); root.attributes("-topmost", True)
            path = filedialog.askopenfilename(
                title="Load Chart",
                filetypes=[("JSON","*.json"),("All","*.*")],
                initialdir=str(self.project_root / "assets" / "data" / "charts")
            )
            root.destroy()
            if path:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self._import_chart(data)
                self._status(f"Loaded: {Path(path).name}", self.theme.accent_green)
        except Exception as ex:
            self._status(f"Load error: {ex}", self.theme.accent_red)

    def _browse_audio(self):
        try:
            import tkinter as tk
            from tkinter import filedialog
            root = tk.Tk(); root.withdraw(); root.attributes("-topmost", True)
            path = filedialog.askopenfilename(
                title="Load Audio",
                filetypes=[("Audio","*.wav *.ogg *.mp3"),("All","*.*")],
                initialdir=str(self.project_root / "assets" / "music")
            )
            root.destroy()
            if path:
                ok = self.audio.load(path)
                if ok:
                    self._status(f"Audio: {Path(path).name}", self.theme.accent_green)
                    # Auto-size sections to match audio length
                    total_beats = int(math.ceil(
                        self.audio.length_sec * (self.song_bpm / 60.0)))
                    total_needed = max(1, math.ceil(total_beats / SECTION_BEATS))
                    while len(self.sections) < total_needed:
                        ref = self.sections[-1]
                        self.sections.append(ChartSection(
                            bpm=ref.bpm, must_hit=ref.must_hit,
                            singers=list(ref.singers)
                        ))
                else:
                    self._status(f"Failed to load audio (OGG not supported by wave; use WAV)",
                                 self.theme.accent_red)
        except Exception as ex:
            self._status(f"Audio error: {ex}", self.theme.accent_red)

    # =========================================================================
    # Rect helpers
    # =========================================================================

    def _toolbar_rect(self) -> pygame.Rect:
        return pygame.Rect(self.rect.x, self.rect.y, self.rect.width, TOOLBAR_H)

    def _left_panel_rect(self) -> pygame.Rect:
        return pygame.Rect(self.rect.x, self.rect.y + TOOLBAR_H,
                           LEFT_W, self.rect.height - TOOLBAR_H)

    def _right_panel_rect(self) -> pygame.Rect:
        return pygame.Rect(self.rect.right - RIGHT_W, self.rect.y + TOOLBAR_H,
                           RIGHT_W, self.rect.height - TOOLBAR_H)

    def _grid_rect(self) -> pygame.Rect:
        lp = self._left_panel_rect()
        rp = self._right_panel_rect()
        return pygame.Rect(lp.right, self.rect.y + TOOLBAR_H,
                           rp.left - lp.right, self.rect.height - TOOLBAR_H)

    def _timeline_rect(self) -> pygame.Rect:
        tb = self._toolbar_rect()
        return pygame.Rect(tb.x + 450, tb.y + 8, tb.width - 460, 30)

    def _section_list_rect(self) -> pygame.Rect:
        lp = self._left_panel_rect()
        return pygame.Rect(lp.x, lp.y + 310, lp.width, lp.height - 310)

    def _add_singer_btn(self) -> pygame.Rect:
        lp = self._left_panel_rect()
        return pygame.Rect(lp.x + 8, lp.y + 280, 80, 22)

    def _snap_rects(self) -> List[pygame.Rect]:
        tb = self._toolbar_rect()
        rects = []
        x = tb.x + 8
        for d in DIVISIONS:
            rects.append(pygame.Rect(x, tb.y + 56, 46, 22))
            x += 52
        return rects

    # =========================================================================
    # Toolbar buttons
    # =========================================================================

    def _toolbar_buttons(self):
        tb = self._toolbar_rect()
        x = tb.x + 8
        y = tb.y + 8
        bw, bh = 88, 26

        def btn(lbl, cb):
            nonlocal x
            r = pygame.Rect(x, y, bw, bh)
            x += bw + 6
            return lbl, r, cb

        return [
            btn("Load Audio",  self._browse_audio),
            btn("Load Chart",  self._load_chart),
            btn("Save Chart",  self._save_chart),
            btn("▶ Play",      self.audio.play),
            btn("⏸ Pause",     self.audio.pause),
            btn("⏹ Stop",      self.audio.stop),
            btn("+ Section",   self._section_add),
            btn("- Section",   self._section_remove),
            btn("Flip Hit",    self._toggle_must_hit),
        ]

    # =========================================================================
    # Drawing
    # =========================================================================

    # ---- Toolbar ----

    def _draw_toolbar(self, surface: pygame.Surface):
        tb = self._toolbar_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, tb)
        pygame.draw.line(surface, self.theme.border, tb.bottomleft, tb.bottomright, 1)

        # Buttons
        for label, rect, _ in self._toolbar_buttons():
            active = (label == "▶ Play" and self.audio.playing) or \
                     (label == "⏸ Pause" and not self.audio.playing)
            col = self.theme.accent_blue if active else self.theme.bg_light
            pygame.draw.rect(surface, col, rect, border_radius=5)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=5)
            ls, _ = self.font.render(label, self.theme.text_primary)
            surface.blit(ls, (rect.x + 6, rect.y + 5))

        # Audio info
        if self.audio.loaded:
            pos_s  = f"{self.audio.position_sec:.1f}s / {self.audio.length_sec:.1f}s"
            name   = Path(self.audio.filepath).stem if self.audio.filepath else ""
            info   = f"{name}  {pos_s}"
        else:
            info = "No audio"
        is_, _ = self.small_font.render(info, self.theme.text_secondary)
        surface.blit(is_, (tb.x + 8, tb.bottom - 22))

        # Snap buttons
        snap_rects = self._snap_rects()
        for i, rect in enumerate(snap_rects):
            div = DIVISIONS[i]
            sel = i == self.snap_idx
            col = self.theme.accent_blue if sel else self.theme.bg_light
            pygame.draw.rect(surface, col, rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)
            ls, _ = self.small_font.render(f"1/{div}", self.theme.text_primary)
            surface.blit(ls, (rect.x + 6, rect.y + 4))

        snap_lbl, _ = self.small_font.render("Snap:", self.theme.text_disabled)
        sr0 = snap_rects[0]
        surface.blit(snap_lbl, (sr0.x - 38, sr0.y + 4))

        # Tool indicator
        tool_col = {
            "tap":   self.theme.accent_green,
            "hold":  self.theme.accent_blue,
            "erase": self.theme.accent_red,
        }.get(self.tool, self.theme.text_secondary)
        tls, _ = self.font.render(f"Tool: {self.tool.upper()}  [T/H/E]", tool_col)
        surface.blit(tls, (tb.x + 280, tb.y + 57))

        # Timeline
        self._draw_timeline(surface)

    def _draw_timeline(self, surface: pygame.Surface):
        tl = self._timeline_rect()
        pygame.draw.rect(surface, self.theme.bg_dark, tl, border_radius=3)
        pygame.draw.rect(surface, self.theme.border, tl, 1, border_radius=3)

        if not self.audio.loaded:
            nl, _ = self.small_font.render("No audio", self.theme.text_disabled)
            surface.blit(nl, (tl.x + 6, tl.y + 8))
            return

        # Waveform
        wf     = self.audio.waveform
        n      = len(wf)
        cx     = tl.y + tl.height // 2
        if n:
            for i, amp in enumerate(wf):
                x  = tl.x + int(i / n * tl.width)
                bh = max(1, int(amp * (tl.height - 4) * 0.45))
                pygame.draw.line(surface, self.theme.accent_blue,
                                 (x, cx - bh), (x, cx + bh), 1)

        # Playhead
        if self.audio.length_sec > 0:
            px = tl.x + int(self.audio.position_sec / self.audio.length_sec * tl.width)
            pygame.draw.line(surface, self.theme.accent_red,
                             (px, tl.y), (px, tl.bottom), 2)

    # ---- Left panel ----

    def _draw_left_panel(self, surface: pygame.Surface):
        lp = self._left_panel_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, lp)
        pygame.draw.line(surface, self.theme.border, lp.topright, lp.bottomright, 1)

        y = lp.y + 8
        x = lp.x + 8

        # Song metadata
        t, _ = self.title_font.render("Chart Editor", self.theme.text_primary)
        surface.blit(t, (x, y)); y += 28

        def labeled_input(inp, label, iy):
            ls, _ = self.small_font.render(label, self.theme.text_disabled)
            surface.blit(ls, (x, iy))
            inp.rect.topleft = (x, iy + 14)
            inp.draw(surface, self.theme)
            return iy + 14 + inp.rect.height + 6

        y = labeled_input(self.input_song,   "Song ID",  y)
        y = labeled_input(self.input_bpm,    "BPM",      y)
        y = labeled_input(self.input_offset, "Offset ms",y)
        y = labeled_input(self.input_player, "Player ID",y)
        y = labeled_input(self.input_stage,  "Stage ID", y)

        y += 4
        # Current section info
        sec = self.sections[self.current_section]
        eff_bpm = sec.effective_bpm(self.song_bpm)
        mh_col  = self.theme.accent_green if sec.must_hit else self.theme.accent_red

        sh, _ = self.font.render(f"Section {self.current_section+1}/{len(self.sections)}", self.theme.text_primary)
        surface.blit(sh, (x, y)); y += 20

        mhl, _ = self.small_font.render(f"mustHit: {'YES' if sec.must_hit else 'NO'}  [Ctrl+H]", mh_col)
        surface.blit(mhl, (x, y)); y += 18

        bml, _ = self.small_font.render(f"BPM: {eff_bpm:.1f}  Notes: {len(sec.notes)}", self.theme.text_secondary)
        surface.blit(bml, (x, y)); y += 18

        # Singers in this section
        sl, _ = self.small_font.render("Singers:", self.theme.text_disabled)
        surface.blit(sl, (x, y)); y += 16
        for i, sid in enumerate(sec.singers):
            col = CHAR_COLORS[i % len(CHAR_COLORS)]
            ss, _ = self.small_font.render(f"  [{i}] {sid}", col)
            surface.blit(ss, (x, y)); y += 14

        # Add singer row
        y += 4
        self.input_singer.rect.topleft = (x, y)
        self.input_singer.draw(surface, self.theme)

        ab = self._add_singer_btn()
        ab.topleft = (x + self.input_singer.rect.width + 4, y)
        pygame.draw.rect(surface, self.theme.accent_green, ab, border_radius=4)
        pygame.draw.rect(surface, self.theme.border, ab, 1, border_radius=4)
        als, _ = self.small_font.render("+ Add", self.theme.text_primary)
        surface.blit(als, (ab.x + 4, ab.y + 4))
        y += 30

        # Note type
        y += 2
        ntl, _ = self.small_font.render(f"Note type [1-4]: {self.current_note_type}", NOTE_TYPE_COLORS[self.current_note_type])
        surface.blit(ntl, (x, y)); y += 16

        # Section list
        sl_rect = self._section_list_rect()
        sl_rect.y = y + 4
        sl_rect.height = lp.bottom - y - 8
        self._draw_section_list(surface, sl_rect)

    def _draw_section_list(self, surface: pygame.Surface, rect: pygame.Rect):
        pygame.draw.rect(surface, self.theme.bg_dark, rect, border_radius=4)
        pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)

        hl, _ = self.small_font.render("Sections (PgUp/PgDn)", self.theme.text_disabled)
        surface.blit(hl, (rect.x + 4, rect.y + 4))

        row_h = 44
        y = rect.y + 18
        for i, sec in enumerate(self.sections):
            ry = y + i * row_h - self._section_scroll
            if ry + row_h < rect.y or ry > rect.bottom:
                continue
            row = pygame.Rect(rect.x + 2, ry, rect.width - 4, row_h - 2)
            sel = i == self.current_section
            pygame.draw.rect(surface, self.theme.accent_blue if sel else self.theme.bg_light,
                             row, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, row, 1, border_radius=4)

            mh_col = self.theme.accent_green if sec.must_hit else self.theme.accent_red
            nl, _ = self.small_font.render(f"§{i+1}  {'HIT' if sec.must_hit else 'auto'}", mh_col)
            surface.blit(nl, (row.x + 4, row.y + 4))

            bpm_eff = sec.effective_bpm(self.song_bpm)
            bl, _ = self.small_font.render(f"BPM {bpm_eff:.0f}  {len(sec.notes)} notes", self.theme.text_secondary)
            surface.blit(bl, (row.x + 4, row.y + 20))

    # ---- Grid ----

    def _draw_grid(self, surface: pygame.Surface):
        grid = self._grid_rect()
        pygame.draw.rect(surface, self.theme.bg_dark, grid)

        lane_map, total_lanes = self._section_lane_map()
        if total_lanes == 0:
            empty, _ = self.font.render("Add singers to this section to chart.", self.theme.text_disabled)
            surface.blit(empty, (grid.centerx - empty.get_width()//2, grid.centery))
            return

        col_w = self._col_width(grid, total_lanes)

        # Column headers
        self._draw_grid_headers(surface, grid, lane_map, col_w)

        # Clip area for notes
        clip = pygame.Rect(grid.x, grid.y + HEADER_H, grid.width, grid.height - HEADER_H)

        total_rows = self._total_rows()
        sec        = self.sections[self.current_section]
        sec_start  = self._section_start_row(self.current_section)
        sec_end    = sec_start + sec.length_rows()

        visible_start = self.grid_scroll // self.row_height
        visible_end   = min(total_rows, visible_start + clip.height // self.row_height + 2)

        # Draw rows
        for row in range(visible_start, visible_end):
            ry = clip.y + row * self.row_height - self.grid_scroll
            if ry > clip.bottom:
                break

            # Section highlight
            in_cur = sec_start <= row < sec_end
            if in_cur:
                pygame.draw.rect(surface, (30, 35, 50),
                                 pygame.Rect(grid.x, ry, grid.width, self.row_height))

            # Beat / bar lines
            local_row = row % ROWS_PER_BEAT
            if row % (ROWS_PER_BEAT * 4) == 0:           # bar line
                pygame.draw.line(surface, self.theme.border,
                                 (grid.x, ry), (grid.right, ry), 2)
                bl, _ = self.small_font.render(
                    f"bar {row // (ROWS_PER_BEAT * 4) + 1}",
                    self.theme.text_disabled)
                surface.blit(bl, (grid.x + 2, ry + 1))
            elif row % ROWS_PER_BEAT == 0:                # beat line
                pygame.draw.line(surface, (50, 55, 70),
                                 (grid.x, ry), (grid.right, ry), 1)
            elif local_row % (ROWS_PER_BEAT // 4) == 0:  # quarter-beat
                pygame.draw.line(surface, (35, 38, 52),
                                 (grid.x, ry), (grid.right, ry), 1)

        # Section boundary markers
        acc = 0
        for si, s in enumerate(self.sections):
            boundary_y = clip.y + acc * self.row_height - self.grid_scroll
            if clip.y <= boundary_y <= clip.bottom:
                pygame.draw.line(surface, self.theme.accent_blue,
                                 (grid.x, boundary_y), (grid.right, boundary_y), 2)
                lbl, _ = self.small_font.render(f"§{si+1}", self.theme.accent_blue)
                surface.blit(lbl, (grid.right - lbl.get_width() - 2, boundary_y + 1))
            acc += s.length_rows()

        # Column dividers
        for col in range(total_lanes + 1):
            cx = grid.x + col * col_w
            pygame.draw.line(surface, self.theme.border,
                             (cx, grid.y + HEADER_H), (cx, grid.bottom), 1)

        # Player/NPC separator
        sep_x = grid.x + 4 * col_w
        if sep_x < grid.right:
            pygame.draw.line(surface, (80, 100, 160),
                             (sep_x, grid.y + HEADER_H), (sep_x, grid.bottom), 2)

        # Notes (all sections)
        acc_row = 0
        for si, s in enumerate(self.sections):
            self._draw_section_notes(surface, clip, grid, s, lane_map, col_w, acc_row)
            acc_row += s.length_rows()

        # Hold preview while dragging
        if self.hold_start is not None and self.tool == "hold":
            start_sec_row, lane = self.hold_start
            start_global = self._section_start_row(self.current_section) + start_sec_row
            end_global   = self._section_start_row(self.current_section) + self.hold_end_row

            if lane in lane_map:
                col = lane_map.index(lane)
                x = grid.x + col * col_w
                sy = clip.y + start_global * self.row_height - self.grid_scroll
                ey = clip.y + end_global   * self.row_height - self.grid_scroll
                if ey > sy:
                    preview_surf = pygame.Surface((col_w - 2, ey - sy), pygame.SRCALPHA)
                    preview_surf.fill((*NOTE_TYPE_COLORS[self.current_note_type], 100))
                    surface.blit(preview_surf, (x + 1, sy))

        # Playhead
        if self.audio.playing or self.audio.position_sec > 0:
            ph_row = self._time_to_row_global(self.audio.position_sec * 1000)
            ph_y   = clip.y + ph_row * self.row_height - self.grid_scroll
            if clip.y <= ph_y <= clip.bottom:
                pygame.draw.line(surface, self.theme.accent_red,
                                 (grid.x, ph_y), (grid.right, ph_y), 2)

        pygame.draw.rect(surface, self.theme.border, grid, 1)

    def _draw_grid_headers(self, surface, grid, lane_map, col_w):
        header = pygame.Rect(grid.x, grid.y, grid.width, HEADER_H)
        pygame.draw.rect(surface, self.theme.bg_light, header)
        pygame.draw.line(surface, self.theme.border, header.bottomleft, header.bottomright, 1)

        sec = self.sections[self.current_section]
        singers = sec.singers if sec.singers else self.all_singers

        for col, lane in enumerate(lane_map):
            x = grid.x + col * col_w
            # Colour band
            if lane >= 0:
                band_col = (*DIR_COLORS[lane % 4], 80)
            else:
                abs_l    = abs(lane)
                anim_dir = abs_l % 4
                gi       = (abs_l - 1) // 4
                si       = len(singers) - 1 - gi
                char_col = CHAR_COLORS[si % len(CHAR_COLORS)] if 0 <= si < len(singers) else (100,100,100)
                band_col = (*char_col, 60)

            band_surf = pygame.Surface((col_w - 1, HEADER_H - 1), pygame.SRCALPHA)
            band_surf.fill(band_col)
            surface.blit(band_surf, (x + 1, grid.y + 1))

            # Label
            if lane >= 0:
                label = DIR_NAMES[lane % 4]
                col_txt = DIR_COLORS[lane % 4]
            else:
                abs_l    = abs(lane)
                anim_dir = abs_l % 4
                gi       = (abs_l - 1) // 4
                si       = len(singers) - 1 - gi
                name     = singers[si] if 0 <= si < len(singers) else "?"
                label    = f"{name[:6]}\n{DIR_NAMES[anim_dir]}"
                col_txt  = CHAR_COLORS[si % len(CHAR_COLORS)] if 0 <= si < len(singers) else (180,180,180)

            # Multi-line label
            lines = label.split("\n")
            ly = grid.y + 2
            for line in lines:
                ls, _ = self.small_font.render(line, col_txt)
                surface.blit(ls, (x + 2, ly))
                ly += 12

    def _draw_section_notes(self, surface, clip, grid, sec, lane_map, col_w, acc_row):
        for note in sec.notes:
            global_row = acc_row + note.row
            if note.lane not in lane_map:
                continue
            col = lane_map.index(note.lane)

            x  = grid.x + col * col_w
            ny = clip.y + global_row * self.row_height - self.grid_scroll

            if ny + note.hold_rows * self.row_height < clip.y:
                continue
            if ny > clip.bottom:
                continue

            note_col = NOTE_TYPE_COLORS[note.note_type % len(NOTE_TYPE_COLORS)]

            # Hold body
            if note.hold_rows > 0:
                body_h = max(2, note.hold_rows * self.row_height)
                body = pygame.Rect(x + col_w // 2 - 4, ny, 8,
                                   min(body_h, clip.bottom - ny))
                if body.height > 0:
                    pygame.draw.rect(surface, note_col, body, border_radius=3)

            # Note head
            head = pygame.Rect(x + 2, ny - self.row_height // 2 + 1,
                               col_w - 4, self.row_height - 2)
            if clip.y - self.row_height <= ny <= clip.bottom:
                pygame.draw.rect(surface, note_col, head, border_radius=3)
                pygame.draw.rect(surface, (255,255,255,60), head, 1, border_radius=3)

    # ---- Right panel (character preview) ----

    def _draw_right_panel(self, surface: pygame.Surface):
        rp = self._right_panel_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, rp)
        pygame.draw.line(surface, self.theme.border, rp.topleft, rp.bottomleft, 1)

        y = rp.y + 8
        x = rp.x + 8

        th, _ = self.font.render("Preview", self.theme.text_primary)
        surface.blit(th, (x, y)); y += 24

        sec     = self.sections[self.current_section]
        singers = sec.singers if sec.singers else self.all_singers

        if not singers:
            ns, _ = self.small_font.render("No singers in section.", self.theme.text_disabled)
            surface.blit(ns, (x, y))
            return

        # Divide available height among singers
        avail_h = rp.height - 40
        thumb_h = max(60, avail_h // max(1, len(singers)))

        for i, char_id in enumerate(singers):
            cy   = y + i * thumb_h
            crect = pygame.Rect(rp.x + 2, cy, rp.width - 4, thumb_h - 4)

            char_col = CHAR_COLORS[i % len(CHAR_COLORS)]

            # Background
            pygame.draw.rect(surface, self.theme.bg_dark, crect, border_radius=6)
            pygame.draw.rect(surface, char_col, crect, 1, border_radius=6)

            # Name
            nl, _ = self.small_font.render(char_id, char_col)
            surface.blit(nl, (crect.x + 4, crect.y + 4))

            # Sprite
            sprite = self.sprites.get(char_id, thumb_h - 20)
            if sprite:
                sw, sh = sprite.get_size()
                # Flip if this is not the first singer (convention)
                if i > 0:
                    sprite = pygame.transform.flip(sprite, True, False)
                sx = crect.centerx - sw // 2
                sy = crect.bottom - sh - 2
                surface.blit(sprite, (sx, sy))
            else:
                # Placeholder silhouette
                ph = pygame.Rect(crect.centerx - 20, crect.y + 20, 40, thumb_h - 30)
                pygame.draw.rect(surface, (80, 80, 100), ph, border_radius=4)
                pl, _ = self.small_font.render("?", self.theme.text_disabled)
                surface.blit(pl, (ph.centerx - pl.get_width()//2,
                                  ph.centery - pl.get_height()//2))

            # Anim indicator
            anim_dir = self._preview_anim.get(char_id)
            if anim_dir is not None and self._preview_timer.get(char_id, 0) > 0:
                dir_name = DIR_NAMES[anim_dir % 4]
                dir_col  = DIR_COLORS[anim_dir % 4]
                al, _    = self.font.render(f"sing{dir_name}", dir_col)
                surface.blit(al, (crect.x + 4, crect.bottom - 18))
            else:
                il, _ = self.small_font.render("idle", self.theme.text_disabled)
                surface.blit(il, (crect.x + 4, crect.bottom - 14))

        # Key legend
        ky = rp.bottom - 80
        lg, _ = self.small_font.render("Keys:", self.theme.text_disabled)
        surface.blit(lg, (rp.x + 4, ky)); ky += 14
        for line in ["T = tap  H = hold  E = erase",
                     "Tab = cycle snap",
                     "1-4 = note type",
                     "PgUp/Dn = section"]:
            ls, _ = self.small_font.render(line, self.theme.text_secondary)
            surface.blit(ls, (rp.x + 4, ky)); ky += 13

    # ---- Status bar ----

    def _draw_status(self, surface: pygame.Surface):
        if not self.status_msg:
            return
        col = self.status_color
        s, _ = self.font.render(self.status_msg, col)
        y    = self.rect.bottom - 20
        surface.blit(s, (self.rect.x + 8, y))

    # =========================================================================
    # Helpers
    # =========================================================================

    def _status(self, msg: str, color=None, duration: float = 4.0):
        self.status_msg   = msg
        self.status_color = color or self.theme.text_secondary
        self.status_timer = duration

    def _scroll(self, delta: int):
        max_scroll = max(0, self._total_rows() * self.row_height - self._grid_rect().height)
        self.grid_scroll = max(0, min(self.grid_scroll + delta, max_scroll))

    # =========================================================================
    # Help entries
    # =========================================================================

    def get_help_entries(self):
        return [
            ("Chart Editor", [
                "Ctrl+O — load chart JSON",
                "Ctrl+S — save chart JSON",
                "Ctrl+L — load audio (WAV)",
                "Ctrl+Z / Ctrl+Y — undo / redo",
                "Space — play / pause audio",
            ]),
            ("Note Placement", [
                "T — tap tool  |  H — hold tool  |  E — erase tool",
                "Click grid to place/remove notes",
                "Hold drag to set hold note duration",
                "Tab — cycle snap (1/4, 1/8, 1/16, 1/32)",
                "1-4 — select note type",
            ]),
            ("Sections & Lanes", [
                "PgUp / PgDn — navigate sections",
                "Ctrl+H — toggle mustHitSection for current section",
                "+ Section / - Section — add/remove sections",
                "Player lanes (0-3) = left side of grid (ASDF input)",
                "NPC lanes (-1..-4 per extra singer) = right side",
                "  -1=DOWN, -2=UP, -3=RIGHT, -4=LEFT",
                "Add singers via the 'Singer ID' field in left panel",
            ]),
            ("Preview Panel", [
                "Right panel shows sprites for section's singers",
                "Anim indicator flashes when you place a note",
                "Sprites load from assets/images/characters/<id>/<id>.png",
            ]),
        ]
