"""Chart Editor Module - build rhythm charts with lanes, players, and characters."""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pygame
import pygame.freetype

from modules.ui.widgets import Dropdown, TextInput


COLOR_OPTIONS = [
    ("Blue", (80, 140, 255)),
    ("Red", (255, 100, 100)),
    ("Green", (100, 220, 140)),
    ("Yellow", (255, 200, 80)),
    ("Purple", (180, 120, 255)),
    ("Teal", (80, 200, 200)),
]

NOTE_TYPE_COLORS = [
    (80, 140, 255),   # Normal - Blue
    (255, 100, 255),  # Special 1 - Pink
    (100, 255, 100),  # Special 2 - Green  
    (255, 200, 80),   # Special 3 - Yellow
]


class ChartEditor:
    """Chart editor with audio loading, hold notes, special notes, and save/load functionality."""

    def __init__(self, workspace_rect, theme, project_root):
        self.rect = workspace_rect
        self.theme = theme
        self.project_root = project_root
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 22, bold=True)
        self.small_font = pygame.freetype.SysFont("Arial", 12)

        self.margin = 20
        self.left_panel_width = 320
        self.toolbar_height = 140

        self.song_input = TextInput(pygame.Rect(0, 0, 200, 28), self.font, placeholder="Song name", text="")
        self.bpm_input = TextInput(pygame.Rect(0, 0, 120, 28), self.font, placeholder="BPM", text="120")

        self.characters: List[Dict[str, str]] = [
            {"name": "Boyfriend", "color": "Blue"},
            {"name": "Opponent", "color": "Red"},
        ]
        self.selected_character_index = 0
        self.character_name_input = TextInput(pygame.Rect(0, 0, 140, 28), self.font, placeholder="Character name")
        self.character_color_dropdown = Dropdown(
            pygame.Rect(0, 0, 120, 28),
            self.font,
            [opt[0] for opt in COLOR_OPTIONS],
            value=COLOR_OPTIONS[0][0],
            placeholder="Color",
        )

        self.players: List[Dict[str, str]] = [
            {"name": "Player 1", "lanes": 4, "character": "Boyfriend"},
            {"name": "Player 2", "lanes": 4, "character": "Opponent"},
        ]
        self.selected_player_index = 0
        self.player_name_input = TextInput(pygame.Rect(0, 0, 140, 28), self.font, placeholder="Player name")
        self.player_lanes_input = TextInput(pygame.Rect(0, 0, 60, 28), self.font, placeholder="Lanes")
        self.player_character_dropdown = Dropdown(
            pygame.Rect(0, 0, 140, 28),
            self.font,
            self._character_names(),
            value=self.players[0]["character"],
            placeholder="Assign character",
        )
        self._load_player_inputs()

        self.grid_rows = 128
        self.grid_scroll = 0
        self.row_height = 24
        self.lane_width = 40
        self.header_height = 30
        self.notes = {}  # (row, lane) -> {"sustain": duration_ms, "type": 0-3}
        
        self.hold_note_start = None
        self.placing_hold = False
        self.current_note_type = 0  # 0=normal, 1-3=special

        self.audio_file: Optional[str] = None
        self.audio_loaded = False
        self.audio_playing = False
        self.audio_position = 0.0
        self.audio_length = 0.0
        self.waveform_data: List[float] = []
        self.metronome_enabled = True
        self.snap_to_beat = True
        
        self.playback_speed = 1.0
        self.last_beat_time = 0.0
        
        self.dragging_timeline = False
        self.placing_notes_mode = False

        self.status_message = "Load an audio file to begin charting. Hold Shift+Click for hold notes."
        self.status_color = self.theme.text_secondary
        self.status_timer = 0.0

    def _character_names(self) -> List[str]:
        return [char["name"] for char in self.characters]

    def _update_player_character_options(self):
        names = self._character_names()
        self.player_character_dropdown.set_options(names)
        if names and self.player_character_dropdown.get_value() not in names:
            self.player_character_dropdown.set_value(names[0])

    def _load_player_inputs(self):
        if not self.players:
            self.player_name_input.set_value("")
            self.player_lanes_input.set_value("")
            self.player_character_dropdown.set_options([])
            return
        player = self.players[self.selected_player_index]
        self.player_name_input.set_value(player["name"])
        self.player_lanes_input.set_value(str(player["lanes"]))
        self._update_player_character_options()
        self.player_character_dropdown.set_value(player.get("character", ""))

    def _commit_player_inputs(self):
        if not self.players:
            return
        player = self.players[self.selected_player_index]
        name = self.player_name_input.get_value() or player["name"]
        player["name"] = name
        lanes_raw = self.player_lanes_input.get_value()
        try:
            lanes = max(1, int(lanes_raw)) if lanes_raw else player["lanes"]
        except ValueError:
            lanes = player["lanes"]
        player["lanes"] = lanes
        player["character"] = self.player_character_dropdown.get_value()

    def _lane_layout(self) -> List[Tuple[int, int]]:
        layout = []
        for player_index, player in enumerate(self.players):
            for lane_index in range(player["lanes"]):
                layout.append((player_index, lane_index))
        return layout

    def _grid_rect(self) -> pygame.Rect:
        left_panel = self._left_panel_rect()
        return pygame.Rect(
            left_panel.right + self.margin,
            self.rect.y + self.margin + self.toolbar_height,
            self.rect.width - left_panel.width - self.margin * 3,
            self.rect.height - self.margin * 2 - self.toolbar_height,
        )

    def _left_panel_rect(self) -> pygame.Rect:
        return pygame.Rect(
            self.rect.x + self.margin,
            self.rect.y + self.margin,
            self.left_panel_width,
            self.rect.height - self.margin * 2,
        )

    def _load_audio_file(self, filepath: str):
        """Load an audio file for charting."""
        try:
            pygame.mixer.init()
            pygame.mixer.music.load(filepath)
            self.audio_file = filepath
            self.audio_loaded = True
            self.audio_position = 0.0
            
            try:
                import wave
                with wave.open(filepath, 'rb') as wav:
                    frames = wav.getnframes()
                    rate = wav.getframerate()
                    self.audio_length = frames / float(rate)
            except:
                self.audio_length = 180.0
            
            self._generate_waveform(filepath)
            self._set_status(f"Loaded: {Path(filepath).name}", self.theme.accent_green)
            
            try:
                bpm = float(self.bpm_input.get_value())
                beats_needed = int((self.audio_length / 60.0) * bpm * 1.5)
                self.grid_rows = max(128, beats_needed)
            except:
                pass
                
        except Exception as e:
            self._set_status(f"Failed to load audio: {e}", self.theme.accent_red)

    def _generate_waveform(self, filepath: str):
        """Generate simplified waveform data for visualization."""
        self.waveform_data = []
        try:
            import wave
            with wave.open(filepath, 'rb') as wav:
                frames = wav.readframes(wav.getnframes())
                import struct
                samples = struct.unpack(f"{len(frames)//2}h", frames)
                
                chunk_size = max(1, len(samples) // 500)
                for i in range(0, len(samples), chunk_size):
                    chunk = samples[i:i+chunk_size]
                    if chunk:
                        avg = sum(abs(s) for s in chunk) / len(chunk)
                        normalized = avg / 32768.0
                        self.waveform_data.append(normalized)
        except:
            self.waveform_data = [0.0] * 100

    def _browse_audio_file(self):
        """Open file browser to select audio file."""
        try:
            import tkinter as tk
            from tkinter import filedialog
            
            root = tk.Tk()
            root.withdraw()
            root.attributes('-topmost', True)
            
            filetypes = [
                ("Audio Files", "*.wav *.mp3 *.ogg"),
                ("WAV Files", "*.wav"),
                ("MP3 Files", "*.mp3"),
                ("OGG Files", "*.ogg"),
                ("All Files", "*.*")
            ]
            
            filepath = filedialog.askopenfilename(
                title="Select Audio File",
                filetypes=filetypes,
                initialdir=self.project_root / "assets" / "music" if self.project_root else None
            )
            
            root.destroy()
            
            if filepath:
                self._load_audio_file(filepath)
        except Exception as e:
            self._set_status(f"Error browsing files: {e}", self.theme.accent_red)

    def _load_chart_file(self):
        """Load a chart JSON file."""
        try:
            import tkinter as tk
            from tkinter import filedialog
            
            root = tk.Tk()
            root.withdraw()
            root.attributes('-topmost', True)
            
            filepath = filedialog.askopenfilename(
                title="Load Chart",
                filetypes=[("JSON Files", "*.json"), ("All Files", "*.*")],
                initialdir=self.project_root / "assets" / "data" if self.project_root else None
            )
            
            root.destroy()
            
            if filepath:
                with open(filepath, 'r') as f:
                    data = json.load(f)
                self._import_chart_data(data)
                self._set_status(f"Loaded chart: {Path(filepath).name}", self.theme.accent_green)
        except Exception as e:
            self._set_status(f"Error loading chart: {e}", self.theme.accent_red)

    def _import_chart_data(self, data: dict):
        """Import chart data from JSON."""
        song_data = data.get("song", {})
        
        self.song_input.set_value(song_data.get("song", ""))
        self.bpm_input.set_value(str(song_data.get("bpm", 120)))
        
        self.notes.clear()
        
        sections = song_data.get("notes", [])
        for section in sections:
            section_notes = section.get("sectionNotes", [])
            player_lane_count = section.get("playerLaneCount", 4)
            must_hit = section.get("mustHitSection", True)
            
            for note in section_notes:
                if len(note) < 2:
                    continue
                    
                time_ms = note[0]
                lane = note[1]
                sustain = note[2] if len(note) > 2 else 0
                note_type = note[3] if len(note) > 3 else 0
                
                try:
                    bpm = float(self.bpm_input.get_value())
                    beat_duration_ms = (60.0 / bpm) * 1000
                    row = int(time_ms / (beat_duration_ms / 4))
                    
                    if not must_hit:
                        lane += player_lane_count
                    
                    self.notes[(row, lane)] = {
                        "sustain": sustain,
                        "type": note_type
                    }
                except:
                    pass

    def _save_chart(self):
        """Save chart to JSON file."""
        try:
            import tkinter as tk
            from tkinter import filedialog
            
            root = tk.Tk()
            root.withdraw()
            root.attributes('-topmost', True)
            
            default_name = self.song_input.get_value() or "chart"
            filepath = filedialog.asksaveasfilename(
                title="Save Chart",
                defaultextension=".json",
                filetypes=[("JSON Files", "*.json"), ("All Files", "*.*")],
                initialfile=f"{default_name}.json",
                initialdir=self.project_root / "assets" / "data" if self.project_root else None
            )
            
            root.destroy()
            
            if filepath:
                chart_data = self._export_chart_data()
                with open(filepath, 'w') as f:
                    json.dump(chart_data, f, indent=2)
                self._set_status(f"Saved: {Path(filepath).name}", self.theme.accent_green)
        except Exception as e:
            self._set_status(f"Error saving: {e}", self.theme.accent_red)

    def _export_chart_data(self) -> dict:
        """Export current chart to JSON format."""
        try:
            bpm = float(self.bpm_input.get_value())
        except:
            bpm = 120
        
        beat_duration_ms = (60.0 / bpm) * 1000
        
        player1_lanes = self.players[0]["lanes"] if self.players else 4
        
        notes_by_section = {}
        for (row, lane), note_data in self.notes.items():
            time_ms = row * (beat_duration_ms / 4)
            section_index = int(time_ms // (beat_duration_ms * 16))
            
            if section_index not in notes_by_section:
                notes_by_section[section_index] = []
            
            must_hit = lane < player1_lanes
            actual_lane = lane if must_hit else lane - player1_lanes
            
            note_entry = [
                int(time_ms),
                actual_lane,
                note_data.get("sustain", 0),
                note_data.get("type", 0)
            ]
            
            notes_by_section[section_index].append({
                "note": note_entry,
                "mustHit": must_hit
            })
        
        sections = []
        if notes_by_section:
            max_section = max(notes_by_section.keys())
            for i in range(max_section + 1):
                section_notes = notes_by_section.get(i, [])
                
                must_hit = True
                if section_notes:
                    must_hit = section_notes[0]["mustHit"]
                
                formatted_notes = [n["note"] for n in section_notes]
                
                sections.append({
                    "sectionNotes": formatted_notes,
                    "mustHitSection": must_hit,
                    "playerLaneCount": player1_lanes,
                    "lengthInSteps": 16,
                    "bpm": bpm
                })
        
        return {
            "song": {
                "song": self.song_input.get_value() or "untitled",
                "bpm": bpm,
                "offset": 0.0,
                "stage": "stage1",
                "player": "player",
                "singers": [char["name"] for char in self.characters],
                "notes": sections
            }
        }

    def _play_audio(self):
        """Start or resume audio playback."""
        if not self.audio_loaded:
            self._set_status("No audio loaded", self.theme.accent_red)
            return
        
        try:
            if not self.audio_playing:
                pygame.mixer.music.play(start=self.audio_position)
                self.audio_playing = True
                self.placing_notes_mode = True
                self._set_status("Playing - Click lanes to chart", self.theme.accent_green)
        except Exception as e:
            self._set_status(f"Playback error: {e}", self.theme.accent_red)

    def _pause_audio(self):
        """Pause audio playback."""
        if self.audio_playing:
            pygame.mixer.music.pause()
            self.audio_playing = False
            self.placing_notes_mode = False
            self._set_status("Paused", self.theme.text_secondary)

    def _stop_audio(self):
        """Stop audio playback and reset position."""
        pygame.mixer.music.stop()
        self.audio_playing = False
        self.audio_position = 0.0
        self.placing_notes_mode = False
        self.grid_scroll = 0
        self._set_status("Stopped", self.theme.text_secondary)

    def _set_audio_position(self, position: float):
        """Set audio playback position."""
        if not self.audio_loaded:
            return
        
        self.audio_position = max(0.0, min(position, self.audio_length))
        
        if self.audio_playing:
            pygame.mixer.music.stop()
            pygame.mixer.music.play(start=self.audio_position)
        
        try:
            bpm = float(self.bpm_input.get_value())
            beat_duration = 60.0 / bpm
            current_beat = self.audio_position / beat_duration
            self.grid_scroll = current_beat * self.row_height
        except:
            pass

    def handle_event(self, event):
        self.song_input.handle_event(event)
        self.bpm_input.handle_event(event)
        self.character_name_input.handle_event(event)
        self.player_name_input.handle_event(event)
        self.player_lanes_input.handle_event(event)

        self.character_color_dropdown.handle_event(event)
        self.player_character_dropdown.handle_event(event)

        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                if self.audio_playing:
                    self._pause_audio()
                else:
                    self._play_audio()
                return
            elif event.key == pygame.K_l and (event.mod & pygame.KMOD_CTRL):
                self._browse_audio_file()
                return
            elif event.key == pygame.K_o and (event.mod & pygame.KMOD_CTRL):
                self._load_chart_file()
                return
            elif event.key == pygame.K_s and (event.mod & pygame.KMOD_CTRL):
                self._save_chart()
                return
            elif event.key == pygame.K_m:
                self.metronome_enabled = not self.metronome_enabled
                status = "enabled" if self.metronome_enabled else "disabled"
                self._set_status(f"Metronome {status}", self.theme.text_secondary)
                return
            elif event.key == pygame.K_s and not (event.mod & pygame.KMOD_CTRL):
                self.snap_to_beat = not self.snap_to_beat
                status = "enabled" if self.snap_to_beat else "disabled"
                self._set_status(f"Beat snap {status}", self.theme.text_secondary)
                return
            elif event.key == pygame.K_1:
                self.current_note_type = 0
                self._set_status("Normal notes", self.theme.text_secondary)
                return
            elif event.key == pygame.K_2:
                self.current_note_type = 1
                self._set_status("Special note type 1", self.theme.text_secondary)
                return
            elif event.key == pygame.K_3:
                self.current_note_type = 2
                self._set_status("Special note type 2", self.theme.text_secondary)
                return
            elif event.key == pygame.K_4:
                self.current_note_type = 3
                self._set_status("Special note type 3", self.theme.text_secondary)
                return

        if event.type == pygame.MOUSEWHEEL:
            if self._grid_rect().collidepoint(pygame.mouse.get_pos()):
                self._scroll_grid(-event.y * self.row_height)
            elif self._timeline_rect().collidepoint(pygame.mouse.get_pos()):
                self._scroll_grid(-event.y * self.row_height * 4)

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            pos = event.pos
            
            timeline_rect = self._timeline_rect()
            if timeline_rect.collidepoint(pos):
                self._handle_timeline_click(pos, timeline_rect)
                self.dragging_timeline = True
                return
            
            if self._load_audio_button().collidepoint(pos):
                self._browse_audio_file()
            elif self._play_button().collidepoint(pos):
                self._play_audio()
            elif self._pause_button().collidepoint(pos):
                self._pause_audio()
            elif self._stop_button().collidepoint(pos):
                self._stop_audio()
            elif self._load_chart_button().collidepoint(pos):
                self._load_chart_file()
            elif self._save_chart_button().collidepoint(pos):
                self._save_chart()
            elif self._add_character_button().collidepoint(pos):
                self._add_character()
            elif self._remove_character_button().collidepoint(pos):
                self._remove_character()
            elif self._add_player_button().collidepoint(pos):
                self._add_player()
            elif self._remove_player_button().collidepoint(pos):
                self._remove_player()
            elif self._add_rows_button().collidepoint(pos):
                self.grid_rows += 16
            else:
                self._handle_list_click(pos)
                if self._grid_rect().collidepoint(pos):
                    mods = pygame.key.get_mods()
                    if mods & pygame.KMOD_SHIFT:
                        self._start_hold_note(pos)
                    else:
                        self._toggle_grid_note(pos)

        if event.type == pygame.MOUSEMOTION:
            if self.dragging_timeline:
                timeline_rect = self._timeline_rect()
                self._handle_timeline_click(event.pos, timeline_rect)
            elif self.placing_hold:
                self._update_hold_note(event.pos)

        if event.type == pygame.MOUSEBUTTONUP and event.button == 1:
            self.dragging_timeline = False
            if self.placing_hold:
                self._finish_hold_note()
            self._commit_player_inputs()

    def _handle_timeline_click(self, pos, timeline_rect):
        """Handle clicking on the timeline to seek."""
        if not self.audio_loaded:
            return
        
        relative_x = pos[0] - timeline_rect.x
        progress = relative_x / timeline_rect.width
        new_position = progress * self.audio_length
        self._set_audio_position(new_position)

    def _timeline_rect(self) -> pygame.Rect:
        """Get rectangle for audio timeline."""
        grid_rect = self._grid_rect()
        return pygame.Rect(
            grid_rect.x,
            self.rect.y + self.margin + 78,
            grid_rect.width,
            40
        )

    def _load_audio_button(self) -> pygame.Rect:
        left_panel = self._left_panel_rect()
        x_start = left_panel.right + self.margin * 2
        return pygame.Rect(x_start, self.rect.y + self.margin + 10, 100, 28)

    def _play_button(self) -> pygame.Rect:
        left_panel = self._left_panel_rect()
        x_start = left_panel.right + self.margin * 2
        return pygame.Rect(x_start + 110, self.rect.y + self.margin + 10, 60, 28)

    def _pause_button(self) -> pygame.Rect:
        left_panel = self._left_panel_rect()
        x_start = left_panel.right + self.margin * 2
        return pygame.Rect(x_start + 180, self.rect.y + self.margin + 10, 60, 28)

    def _stop_button(self) -> pygame.Rect:
        left_panel = self._left_panel_rect()
        x_start = left_panel.right + self.margin * 2
        return pygame.Rect(x_start + 250, self.rect.y + self.margin + 10, 60, 28)

    def _load_chart_button(self) -> pygame.Rect:
        left_panel = self._left_panel_rect()
        x_start = left_panel.right + self.margin * 2
        return pygame.Rect(x_start, self.rect.y + self.margin + 43, 100, 28)

    def _save_chart_button(self) -> pygame.Rect:
        left_panel = self._left_panel_rect()
        x_start = left_panel.right + self.margin * 2
        return pygame.Rect(x_start + 110, self.rect.y + self.margin + 43, 100, 28)

    def _scroll_grid(self, delta):
        view_height = max(0, self._grid_rect().height - self.header_height)
        max_scroll = max(0, self.grid_rows * self.row_height - view_height)
        self.grid_scroll = max(0, min(self.grid_scroll + delta, max_scroll))

    def _handle_list_click(self, pos):
        char_list = self._character_list_rects()
        for idx, rect in enumerate(char_list):
            if rect.collidepoint(pos):
                self.selected_character_index = idx
                return

        player_list = self._player_list_rects()
        for idx, rect in enumerate(player_list):
            if rect.collidepoint(pos):
                self.selected_player_index = idx
                self._load_player_inputs()
                return

    def _start_hold_note(self, pos):
        """Start placing a hold note."""
        grid_rect = self._grid_rect()
        if not grid_rect.collidepoint(pos):
            return

        layout = self._lane_layout()
        lane_count = len(layout)
        if lane_count == 0:
            return

        lane_width = self._lane_width(grid_rect, lane_count)
        rel_x = pos[0] - grid_rect.x
        rel_y = pos[1] - (grid_rect.y + self.header_height)

        lane = int(rel_x // lane_width)
        row = int((rel_y + self.grid_scroll) // self.row_height)

        if 0 <= lane < lane_count and 0 <= row < self.grid_rows:
            if self.snap_to_beat:
                row = (row // 4) * 4
            
            self.hold_note_start = (row, lane)
            self.placing_hold = True
            self._set_status("Drag to set hold duration, release to place", self.theme.accent_blue)

    def _update_hold_note(self, pos):
        """Update hold note while dragging."""
        if not self.placing_hold or not self.hold_note_start:
            return
        
        grid_rect = self._grid_rect()
        if not grid_rect.collidepoint(pos):
            return
        
        rel_y = pos[1] - (grid_rect.y + self.header_height)
        end_row = int((rel_y + self.grid_scroll) // self.row_height)
        
        if self.snap_to_beat:
            end_row = (end_row // 4) * 4

    def _finish_hold_note(self):
        """Finish placing hold note."""
        if not self.placing_hold or not self.hold_note_start:
            return
        
        pos = pygame.mouse.get_pos()
        grid_rect = self._grid_rect()
        
        if grid_rect.collidepoint(pos):
            rel_y = pos[1] - (grid_rect.y + self.header_height)
            end_row = int((rel_y + self.grid_scroll) // self.row_height)
            
            if self.snap_to_beat:
                end_row = (end_row // 4) * 4
            
            start_row, lane = self.hold_note_start
            duration_rows = max(0, end_row - start_row)
            
            try:
                bpm = float(self.bpm_input.get_value())
                beat_duration_ms = (60.0 / bpm) * 1000
                sustain_ms = int(duration_rows * (beat_duration_ms / 4))
                
                self.notes[(start_row, lane)] = {
                    "sustain": sustain_ms,
                    "type": self.current_note_type
                }
                self._set_status(f"Added hold note: {sustain_ms}ms", self.theme.accent_green)
            except:
                self._set_status("Error creating hold note", self.theme.accent_red)
        
        self.hold_note_start = None
        self.placing_hold = False

    def _toggle_grid_note(self, pos):
        """Toggle a regular note."""
        grid_rect = self._grid_rect()
        if not grid_rect.collidepoint(pos):
            return

        layout = self._lane_layout()
        lane_count = len(layout)
        if lane_count == 0:
            return

        lane_width = self._lane_width(grid_rect, lane_count)
        rel_x = pos[0] - grid_rect.x
        rel_y = pos[1] - (grid_rect.y + self.header_height)

        lane = int(rel_x // lane_width)
        row = int((rel_y + self.grid_scroll) // self.row_height)

        if 0 <= lane < lane_count and 0 <= row < self.grid_rows:
            if self.snap_to_beat:
                row = (row // 4) * 4
            
            note = (row, lane)
            if note in self.notes:
                del self.notes[note]
                self._set_status(f"Removed note at beat {row + 1}, lane {lane + 1}", self.theme.text_secondary)
            else:
                self.notes[note] = {
                    "sustain": 0,
                    "type": self.current_note_type
                }
                type_name = "normal" if self.current_note_type == 0 else f"special {self.current_note_type}"
                self._set_status(f"Added {type_name} note at beat {row + 1}, lane {lane + 1}", self.theme.accent_green)

    def _add_character(self):
        name = self.character_name_input.get_value() or f"Character {len(self.characters) + 1}"
        color = self.character_color_dropdown.get_value()
        self.characters.append({"name": name, "color": color})
        self.character_name_input.set_value("")
        self._update_player_character_options()
        self._set_status(f"Added character: {name}", self.theme.accent_green)

    def _remove_character(self):
        if not self.characters:
            return
        removed = self.characters.pop(self.selected_character_index)
        if self.selected_character_index >= len(self.characters):
            self.selected_character_index = max(0, len(self.characters) - 1)
        self._update_player_character_options()
        self._set_status(f"Removed character: {removed['name']}", self.theme.accent_red)

    def _add_player(self):
        name = self.player_name_input.get_value() or f"Player {len(self.players) + 1}"
        char_names = self._character_names()
        assigned_char = char_names[0] if char_names else ""
        self.players.append({"name": name, "lanes": 4, "character": assigned_char})
        self.player_name_input.set_value("")
        self._set_status(f"Added player: {name}", self.theme.accent_green)

    def _remove_player(self):
        if not self.players:
            return
        removed = self.players.pop(self.selected_player_index)
        if self.selected_player_index >= len(self.players):
            self.selected_player_index = max(0, len(self.players) - 1)
        self._load_player_inputs()
        self._set_status(f"Removed player: {removed['name']}", self.theme.accent_red)

    def _set_status(self, message, color=None):
        self.status_message = message
        self.status_color = color or self.theme.text_secondary
        self.status_timer = 3.0

    def update(self, dt):
        if self.status_timer > 0:
            self.status_timer -= dt

        if self.audio_playing:
            self.audio_position += dt * self.playback_speed
            
            if self.audio_position >= self.audio_length:
                self._stop_audio()
                return
            
            try:
                bpm = float(self.bpm_input.get_value())
                beat_duration = 60.0 / bpm
                current_beat = self.audio_position / beat_duration
                
                if self.metronome_enabled:
                    beat_index = int(current_beat)
                    if beat_index != int(self.last_beat_time / beat_duration):
                        pass
                
                self.last_beat_time = self.audio_position
                
                target_scroll = current_beat * self.row_height - 200
                self.grid_scroll = max(0, target_scroll)
            except:
                pass

    def draw(self, surface):
        surface.fill(self.theme.bg_dark)
        self._draw_toolbar(surface)
        self._draw_left_panel(surface)
        self._draw_grid(surface)
        self._draw_status(surface)

    def _draw_toolbar(self, surface):
        left_panel = self._left_panel_rect()
        toolbar_bg = pygame.Rect(
            left_panel.right + self.margin,
            self.rect.y + self.margin,
            self.rect.width - left_panel.width - self.margin * 3,
            self.toolbar_height - self.margin
        )
        pygame.draw.rect(surface, self.theme.bg_medium, toolbar_bg, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, toolbar_bg, 1, border_radius=8)

        self._draw_button(surface, self._load_audio_button(), "Load Audio", self.theme.bg_light)
        self._draw_button(surface, self._play_button(), "Play", self.theme.accent_green if not self.audio_playing else self.theme.bg_light)
        self._draw_button(surface, self._pause_button(), "Pause", self.theme.accent_blue if self.audio_playing else self.theme.bg_light)
        self._draw_button(surface, self._stop_button(), "Stop", self.theme.accent_red)

        self._draw_button(surface, self._load_chart_button(), "Load Chart", self.theme.bg_light)
        self._draw_button(surface, self._save_chart_button(), "Save Chart", self.theme.accent_green)

        audio_info = "No audio loaded"
        if self.audio_loaded and self.audio_file:
            filename = Path(self.audio_file).name
            time_str = f"{self.audio_position:.1f}s / {self.audio_length:.1f}s"
            audio_info = f"{filename} - {time_str}"
        
        x_start = left_panel.right + self.margin * 2
        info_surf, _ = self.small_font.render(audio_info, self.theme.text_secondary)
        surface.blit(info_surf, (x_start + 320, self.rect.y + self.margin + 15))

        timeline_rect = self._timeline_rect()
        self._draw_timeline(surface, timeline_rect)

        note_type_names = ["Normal", "Special 1", "Special 2", "Special 3"]
        note_type_text = f"[1-4] Type: {note_type_names[self.current_note_type]}"
        note_type_surf, _ = self.small_font.render(note_type_text, NOTE_TYPE_COLORS[self.current_note_type])
        surface.blit(note_type_surf, (x_start + 320, self.rect.y + self.margin + 48))

    def _draw_timeline(self, surface, rect):
        """Draw audio timeline with waveform and playback position."""
        pygame.draw.rect(surface, self.theme.bg_dark, rect, border_radius=4)
        pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)

        if not self.audio_loaded or not self.waveform_data:
            no_audio_surf, _ = self.small_font.render("No audio loaded", self.theme.text_disabled)
            surface.blit(no_audio_surf, (rect.x + 10, rect.y + 14))
            return

        wave_height = rect.height - 4
        wave_y_center = rect.y + rect.height // 2
        
        for i, amplitude in enumerate(self.waveform_data):
            x = rect.x + 2 + int((i / len(self.waveform_data)) * (rect.width - 4))
            bar_height = int(amplitude * wave_height * 0.4)
            pygame.draw.line(
                surface,
                self.theme.accent_blue,
                (x, wave_y_center - bar_height),
                (x, wave_y_center + bar_height),
                1
            )

        if self.audio_length > 0:
            progress = self.audio_position / self.audio_length
            playhead_x = rect.x + int(progress * rect.width)
            pygame.draw.line(
                surface,
                self.theme.accent_red,
                (playhead_x, rect.y),
                (playhead_x, rect.bottom),
                2
            )

    def _draw_left_panel(self, surface):
        panel = self._left_panel_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, panel, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, panel, 1, border_radius=8)

        y = panel.y + 16

        title_surf, _ = self.title_font.render("Chart Editor", self.theme.text_primary)
        surface.blit(title_surf, (panel.x + 16, y))
        y += 40

        self._draw_label(surface, panel.x + 16, y, "Song Name")
        y += 18
        self.song_input.rect.topleft = (panel.x + 16, y)
        self.song_input.draw(surface, self.theme)
        y += 40

        self._draw_label(surface, panel.x + 16, y, "BPM")
        y += 18
        self.bpm_input.rect.topleft = (panel.x + 16, y)
        self.bpm_input.draw(surface, self.theme)
        y += 50

        y = self._draw_section_header(surface, panel.x + 16, y, "Characters")
        self._draw_label(surface, panel.x + 16, y, "Name")
        y += 18
        self.character_name_input.rect.topleft = (panel.x + 16, y)
        self.character_name_input.draw(surface, self.theme)
        
        self._draw_label(surface, panel.x + 166, y - 18, "Color")
        self.character_color_dropdown.rect.topleft = (panel.x + 166, y)
        self.character_color_dropdown.draw(surface, self.theme)
        y += 40

        self._draw_button(surface, self._add_character_button(), "+Add", self.theme.accent_green)
        self._draw_button(surface, self._remove_character_button(), "Remove", self.theme.accent_red)
        y += 40

        y = self._draw_character_list(surface, panel.x + 16, y, panel.width - 32)
        y += 30

        y = self._draw_section_header(surface, panel.x + 16, y, "Players")
        self._draw_label(surface, panel.x + 16, y, "Name")
        y += 18
        self.player_name_input.rect.topleft = (panel.x + 16, y)
        self.player_name_input.draw(surface, self.theme)
        y += 40

        self._draw_label(surface, panel.x + 16, y, "Lanes")
        self.player_lanes_input.rect.topleft = (panel.x + 16, y + 18)
        self.player_lanes_input.draw(surface, self.theme)

        self._draw_label(surface, panel.x + 90, y, "Character")
        self.player_character_dropdown.rect.topleft = (panel.x + 90, y + 18)
        self.player_character_dropdown.draw(surface, self.theme)
        y += 58

        self._draw_button(surface, self._add_player_button(), "+Add Player", self.theme.accent_green)
        self._draw_button(surface, self._remove_player_button(), "Remove", self.theme.accent_red)
        y += 40

        self._draw_player_list(surface, panel.x + 16, y, panel.width - 32)

    def _draw_grid(self, surface):
        grid_rect = self._grid_rect()
        pygame.draw.rect(surface, self.theme.bg_medium, grid_rect, border_radius=8)
        pygame.draw.rect(surface, self.theme.border, grid_rect, 1, border_radius=8)

        layout = self._lane_layout()
        lane_count = len(layout)
        if lane_count == 0:
            empty_surf, _ = self.font.render("Add a player to start charting.", self.theme.text_secondary)
            surface.blit(empty_surf, (grid_rect.x + 16, grid_rect.y + 16))
            return
        lane_width = self._lane_width(grid_rect, lane_count)

        header_rect = pygame.Rect(grid_rect.x, grid_rect.y, grid_rect.width, self.header_height)
        pygame.draw.rect(surface, self.theme.bg_light, header_rect, border_radius=8)
        pygame.draw.line(surface, self.theme.border, (grid_rect.x, header_rect.bottom), (grid_rect.right, header_rect.bottom), 1)

        for lane_idx, (player_idx, lane_offset) in enumerate(layout):
            x = grid_rect.x + lane_idx * lane_width
            label = f"P{player_idx + 1}-{lane_offset + 1}"
            label_surf, _ = self.small_font.render(label, self.theme.text_secondary)
            surface.blit(label_surf, (x + 6, grid_rect.y + 8))
            pygame.draw.line(surface, self.theme.border, (x, grid_rect.y), (x, grid_rect.bottom), 1)

        scroll_y = self.grid_scroll
        visible_rows = int((grid_rect.height - self.header_height) // self.row_height) + 2
        start_row = int(scroll_y // self.row_height)
        end_row = min(self.grid_rows, start_row + visible_rows)

        for row in range(start_row, end_row):
            y = grid_rect.y + (row * self.row_height - scroll_y) + self.header_height
            row_rect = pygame.Rect(grid_rect.x, y, grid_rect.width, self.row_height)
            if row % 4 == 0:
                pygame.draw.rect(surface, self.theme.bg_light, row_rect)
            pygame.draw.line(surface, self.theme.grid_line, (grid_rect.x, y), (grid_rect.right, y), 1)

            beat_label = f"{row + 1}" if row % 4 == 0 else ""
            if beat_label:
                label_surf, _ = self.small_font.render(beat_label, self.theme.text_disabled)
                surface.blit(label_surf, (grid_rect.x + 4, y + 6))

            for lane in range(lane_count):
                cell_rect = pygame.Rect(
                    grid_rect.x + lane * lane_width,
                    y,
                    lane_width,
                    self.row_height,
                )
                note_data = self.notes.get((row, lane))
                if note_data:
                    note_type = note_data.get("type", 0)
                    note_color = NOTE_TYPE_COLORS[note_type] if note_type < len(NOTE_TYPE_COLORS) else NOTE_TYPE_COLORS[0]
                    
                    pygame.draw.rect(surface, note_color, cell_rect.inflate(-6, -6), border_radius=4)
                    
                    sustain = note_data.get("sustain", 0)
                    if sustain > 0:
                        try:
                            bpm = float(self.bpm_input.get_value())
                            beat_duration_ms = (60.0 / bpm) * 1000
                            sustain_rows = sustain / (beat_duration_ms / 4)
                            sustain_height = int(sustain_rows * self.row_height)
                            
                            hold_rect = pygame.Rect(
                                cell_rect.x + cell_rect.width // 2 - 3,
                                cell_rect.y,
                                6,
                                min(sustain_height, grid_rect.bottom - cell_rect.y)
                            )
                            pygame.draw.rect(surface, note_color, hold_rect)
                        except:
                            pass

        if self.placing_hold and self.hold_note_start:
            start_row, lane = self.hold_note_start
            pos = pygame.mouse.get_pos()
            if grid_rect.collidepoint(pos):
                rel_y = pos[1] - (grid_rect.y + self.header_height)
                end_row = int((rel_y + self.grid_scroll) // self.row_height)
                
                start_y = grid_rect.y + self.header_height + (start_row * self.row_height - scroll_y)
                end_y = grid_rect.y + self.header_height + (end_row * self.row_height - scroll_y)
                
                if end_y > start_y:
                    preview_rect = pygame.Rect(
                        grid_rect.x + lane * lane_width + lane_width // 2 - 3,
                        start_y,
                        6,
                        end_y - start_y
                    )
                    note_color = NOTE_TYPE_COLORS[self.current_note_type]
                    pygame.draw.rect(surface, note_color + (128,), preview_rect)

        if self.audio_playing and self.audio_loaded:
            try:
                bpm = float(self.bpm_input.get_value())
                beat_duration = 60.0 / bpm
                current_beat = self.audio_position / beat_duration
                playhead_y = grid_rect.y + self.header_height + (current_beat * self.row_height - scroll_y)
                
                if grid_rect.y + self.header_height <= playhead_y <= grid_rect.bottom:
                    pygame.draw.line(
                        surface,
                        self.theme.accent_red,
                        (grid_rect.x, playhead_y),
                        (grid_rect.right, playhead_y),
                        3
                    )
            except:
                pass

        pygame.draw.line(surface, self.theme.border, (grid_rect.x, grid_rect.y + self.header_height), (grid_rect.right, grid_rect.y + self.header_height), 1)

    def _draw_status(self, surface):
        if not self.status_message:
            return
        color = self.status_color if self.status_timer > 0 else self.theme.text_secondary
        status_surf, _ = self.font.render(self.status_message, color)
        surface.blit(status_surf, (self.rect.x + self.margin, self.rect.bottom - self.margin - 24))

    def _draw_section_header(self, surface, x, y, text):
        header_surf, _ = self.font.render(text, self.theme.text_primary)
        surface.blit(header_surf, (x, y))
        return y + 24

    def _draw_label(self, surface, x, y, text):
        label_surf, _ = self.small_font.render(text, self.theme.text_disabled)
        surface.blit(label_surf, (x, y))

    def _draw_button(self, surface, rect, text, color):
        pygame.draw.rect(surface, color, rect, border_radius=6)
        pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=6)
        label_surf, _ = self.font.render(text, self.theme.text_primary)
        surface.blit(label_surf, (rect.x + 10, rect.y + 6))

    def _draw_character_list(self, surface, x, y, width):
        if not self.characters:
            empty_surf, _ = self.small_font.render("No characters defined.", self.theme.text_secondary)
            surface.blit(empty_surf, (x, y))
            return y + 24
        for idx, character in enumerate(self.characters):
            rect = pygame.Rect(x, y, width, 26)
            bg = self.theme.bg_light if idx == self.selected_character_index else self.theme.bg_medium
            pygame.draw.rect(surface, bg, rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)
            color = self._color_for_name(character["color"])
            pygame.draw.rect(surface, color, pygame.Rect(rect.x + 6, rect.y + 6, 12, 12), border_radius=3)
            label, _ = self.small_font.render(character["name"], self.theme.text_primary)
            surface.blit(label, (rect.x + 24, rect.y + 5))
            y += 30
        return y

    def _draw_player_list(self, surface, x, y, width):
        if not self.players:
            empty_surf, _ = self.small_font.render("No players defined.", self.theme.text_secondary)
            surface.blit(empty_surf, (x, y))
            return
        for idx, player in enumerate(self.players):
            rect = pygame.Rect(x, y, width, 26)
            bg = self.theme.bg_light if idx == self.selected_player_index else self.theme.bg_medium
            pygame.draw.rect(surface, bg, rect, border_radius=4)
            pygame.draw.rect(surface, self.theme.border, rect, 1, border_radius=4)
            label_text = f"{player['name']} ({player['lanes']} lanes)"
            label, _ = self.small_font.render(label_text, self.theme.text_primary)
            surface.blit(label, (rect.x + 8, rect.y + 5))
            char_label = player.get("character", "")
            if char_label:
                char_surf, _ = self.small_font.render(char_label, self.theme.text_secondary)
                surface.blit(char_surf, (rect.right - char_surf.get_width() - 8, rect.y + 5))
            y += 30

    def _character_list_rects(self):
        panel = self._left_panel_rect()
        start_y = panel.y + 16
        start_y += 24 + 58 + 70
        start_y += 24 + 58 + 44
        rects = []
        y = start_y
        for _ in self.characters:
            rects.append(pygame.Rect(panel.x + 16, y, panel.width - 32, 26))
            y += 30
        return rects

    def _player_list_rects(self):
        panel = self._left_panel_rect()
        start_y = panel.y + 16
        start_y += 24 + 58 + 70
        start_y += 24 + 58 + 44
        start_y += self._character_list_height()
        start_y += 24 + 58 + 58 + 44
        rects = []
        y = start_y
        for _ in self.players:
            rects.append(pygame.Rect(panel.x + 16, y, panel.width - 32, 26))
            y += 30
        return rects

    def _add_character_button(self):
        panel = self._left_panel_rect()
        y = panel.y + 16
        y += 24 + 58
        return pygame.Rect(panel.x + 16, y, 90, 28)

    def _remove_character_button(self):
        panel = self._left_panel_rect()
        y = panel.y + 16
        y += 24 + 58
        return pygame.Rect(panel.x + 116, y, 90, 28)

    def _add_player_button(self):
        panel = self._left_panel_rect()
        y = self._player_buttons_y()
        return pygame.Rect(panel.x + 16, y, 120, 28)

    def _remove_player_button(self):
        panel = self._left_panel_rect()
        y = self._player_buttons_y()
        return pygame.Rect(panel.x + 146, y, 100, 28)

    def _player_buttons_y(self):
        panel = self._left_panel_rect()
        y = panel.y + 16
        y += 24 + 58 + 70
        y += 24 + 58 + 44
        y += self._character_list_height()
        y += 24 + 58 + 58
        return y

    def _character_list_height(self):
        if not self.characters:
            return 24
        return len(self.characters) * 30

    def _add_rows_button(self):
        panel = self._left_panel_rect()
        y = panel.y + 16 + 24 + 58
        return pygame.Rect(panel.x + 150, y, 120, 28)

    def _color_for_name(self, name):
        for option_name, color in COLOR_OPTIONS:
            if option_name == name:
                return color
        return self.theme.text_secondary

    def _lane_width(self, grid_rect, lane_count):
        if lane_count <= 0:
            return self.lane_width
        return max(24, grid_rect.width // lane_count)

    def get_help_entries(self):
        """Return help information for this module."""
        return [
            (
                "Audio Controls",
                [
                    "Ctrl+L - Load audio file",
                    "Space - Play/Pause audio",
                    "Click timeline - Seek to position",
                    "Mouse wheel on timeline - Scroll through song"
                ]
            ),
            (
                "Chart Management",
                [
                    "Ctrl+O - Load chart JSON",
                    "Ctrl+S - Save chart to JSON",
                    "Charts use Psych Engine format"
                ]
            ),
            (
                "Charting",
                [
                    "Click grid - Toggle notes",
                    "Shift+Click+Drag - Create hold notes",
                    "1-4 - Select note type (normal/special)",
                    "M - Toggle metronome",
                    "S - Toggle beat snap",
                    "Mouse wheel on grid - Scroll vertically"
                ]
            ),
            (
                "Note Types",
                [
                    "Normal notes (blue) - Standard notes",
                    "Special notes (pink/green/yellow) - Custom mechanics",
                    "Hold notes - Drag to set duration"
                ]
            )
        ]

    def cleanup(self):
        """Cleanup resources when switching modules."""
        if self.audio_loaded:
            pygame.mixer.music.stop()