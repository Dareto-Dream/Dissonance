# DISSONANCE — DATA STANDARDS & SCHEMA REFERENCE

This document defines all data models, schemas, and conventions used by the Dissonance engine.
Both the Haxe engine and Python editor reference these standards.

---

## 1. Scene JSON Schema

Scenes are stored in `assets/data/scenes/{act}/scene{N}.json`.

```json
{
  "scene_id": "act1_scene1_prologue",
  "start": "n1",
  "nodes": [ ... ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `scene_id` | string | Yes | Unique scene identifier |
| `start` | string | Yes | ID of the first node to execute |
| `nodes` | array | Yes | Array of node objects |

---

## 2. Node Types

Every node has an `id` (string, unique within scene) and a `type` field.

### 2.1 dialogue

Character speech with optional pose change and text effect.

```json
{
  "id": "n1",
  "type": "dialogue",
  "speaker": "Tiffany",
  "character": "tiffany",
  "pose": "default_smile",
  "text": "Welcome to the music club!",
  "text_effect": "typewriter",
  "effect_speed": 30.0,
  "effect_intensity": 2.0,
  "effect_amplitude": 5.0,
  "next": "n2"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `speaker` | string | Yes | Display name in dialogue box |
| `character` | string | No | Character ID for pose/emphasis |
| `pose` | string | No | Pose name to set before showing text |
| `text` | string | Yes | Dialogue text |
| `text_effect` | string | No | One of: shake, glitch, wave, rainbow, fade, typewriter |
| `effect_speed` | float | No | Speed parameter for effect |
| `effect_intensity` | float | No | Intensity parameter for effect |
| `effect_amplitude` | float | No | Amplitude parameter for wave effect |
| `next` | string | Yes | Next node ID |

### 2.2 narration

Narrator text (no character displayed as speaker).

```json
{
  "id": "n1",
  "type": "narration",
  "text": "The hallway was quiet.",
  "next": "n2"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | Yes | Narration text |
| `text_effect` | string | No | Same options as dialogue |
| `next` | string | Yes | Next node ID |

### 2.3 action

System operations. The `action` field determines which operation and what parameters are expected.

```json
{
  "id": "n1",
  "type": "action",
  "action": "set_bg",
  "background": "assets/images/bg/classroom1/day1.png",
  "transition": "fade",
  "duration": 1.0,
  "next": "n2"
}
```

#### Action Types Reference

| Action | Parameters | Description |
|--------|-----------|-------------|
| `set_bg` | `background`, `transition`, `duration` | Change background image |
| `show_character` | `character`, `pose`, `transition`, `duration` | Show a character |
| `hide_character` | `character`, `transition`, `duration` | Hide a character |
| `move_character` | `character`, `slot` or `x`+`y`, `duration` | Move character to slot or coordinates |
| `flip_character` | `character`, `flipped` (bool) | Mirror character horizontally |
| `bounce_character` | `character`, `height`, `duration` | Bounce animation |
| `shake_character` | `character`, `intensity`, `duration` | Shake animation |
| `set_tint` | `character` (optional), `color` | Apply color tint (#RRGGBB) |
| `clear_tint` | `character` (optional) | Remove color tint |
| `shake_screen` | `intensity`, `duration` | Screen shake effect |
| `flash` | `color`, `duration` | Screen flash |
| `glitch` | `intensity`, `duration` | Glitch screen effect |
| `play_sound` | `sound`, `volume` | Play sound effect |
| `play_music` | `track`, `volume`, `transition`, `duration` | Play music track |
| `stop_music` | — | Stop music immediately |
| `fade_out_music` | `duration` | Fade out current music |
| `set_default_bgm` | `track`, `volume` | Set default background music |
| `play_default_bgm` | `volume` | Play the default BGM |
| `set_text_effect` | `text_effect`, `effect_speed`, etc. | Set persistent text effect |
| `clear_text_effect` | — | Clear persistent text effect |
| `set_variable` | `variable`, `value`, `op` (optional) | Set/modify a game variable |
| `set_flag` | `flag`, `value` | Set a boolean flag |

#### set_variable

```json
{"action": "set_variable", "variable": "tiffany_rot", "value": 3}
{"action": "set_variable", "variable": "tiffany_rot", "op": "add", "value": 1}
{"action": "set_variable", "variable": "cassian_rot", "op": "subtract", "value": 2}
```

Operations: `set` (default), `add`, `subtract`, `multiply`

#### set_flag

```json
{"action": "set_flag", "flag": "flags.asked_tiffany", "value": true}
```

### 2.4 choice

Player decision point.

```json
{
  "id": "n1",
  "type": "choice",
  "choices": [
    {"text": "Help her practice", "target": "n2a"},
    {"text": "Let her figure it out", "target": "n2b"}
  ]
}
```

### 2.5 if

Conditional branching based on game state.

```json
{
  "id": "n1",
  "type": "if",
  "condition": "tiffany_rot <= 2 and flags.asked_tiffany == true",
  "trueNode": "n2a",
  "falseNode": "n2b"
}
```

**Condition syntax:**
- Variables: `tiffany_rot`, `cassian_rot`, `hanami_rot`, etc.
- Flags: `flags.asked_tiffany`, `player.flags.puppet_mode`, etc.
- Operators: `==`, `!=`, `<`, `<=`, `>`, `>=`
- Connectors: `and`, `or`
- Grouping: parentheses `()`
- Literals: numbers, `true`, `false`

### 2.6 jump

Unconditional jump to another node.

```json
{"id": "n1", "type": "jump", "target": "n5"}
```

### 2.7 game

Launch rhythm gameplay segment.

```json
{"id": "n1", "type": "game", "song": "gentle_start_duet", "next": "n2"}
```

### 2.8 end

Scene completion, transition to next scene.

```json
{"id": "n1", "type": "end", "next_scene": "scenes/act1/scene2.json"}
```

---

## 3. Character Definition Schema

Master registry: `assets/data/characters/characters.json`

```json
{
  "tiffany": {
    "id": "tiffany",
    "rhythm": {
      "png": "assets/images/characters/tiffany/tiffany_rhythm.png",
      "xml": "assets/images/characters/tiffany/tiffany_rhythm.xml"
    },
    "vn": {
      "png": "assets/images/characters/tiffany/tiffany.png",
      "xml": "assets/images/characters/tiffany/tiffany.xml",
      "defaultPose": "neutral"
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `id` | Character identifier (matches key) |
| `vn.png` | VN spritesheet image path |
| `vn.xml` | VN spritesheet XML atlas |
| `vn.defaultPose` | Default pose name |
| `rhythm.png` | Rhythm spritesheet image path |
| `rhythm.xml` | Rhythm spritesheet XML atlas |

### Characters

| ID | Name | Role | Default Pose |
|----|------|------|-------------|
| `mc` | Player | Protagonist | neutral |
| `tiffany` | Tiffany | Club president, needs control | neutral |
| `hanami` | Hanami | Emotional anchor | neutral |
| `cassian` | Cassian | Processes grief through anger | annoyed |
| `laura` | Laura | Energetic club member | happy |

---

## 4. Poses JSON Schema

Per-character: `assets/data/characters/{id}/poses.json`

```json
{
  "character": "tiffany",
  "config": {
    "scale": 1.0,
    "base_offset": {"x": 0, "y": 0}
  },
  "poses": {
    "neutral": {
      "layers": [
        {"frame": "base0001", "x": 0, "y": 0},
        {"frame": "eyes_neutral", "x": 10, "y": 20}
      ]
    },
    "smile": {
      "layers": [
        {"frame": "base0001", "x": 0, "y": 0},
        {"frame": "eyes_happy", "x": 10, "y": 20}
      ]
    }
  }
}
```

- `config.scale`: Global scale multiplier
- `config.base_offset`: Character centering offset
- Each pose has `layers`: array of `{frame, x, y}` referencing atlas frame names
- Rhythm poses: `singLEFT`, `singDOWN`, `singUP`, `singRIGHT`, `idle`, `miss`

---

## 5. Placement JSON Schema

Per-scene: `assets/data/placements/{scene_id}_placement.json`

```json
{
  "n5": {
    "tiffany": {"x": 1100.0, "y": 0, "slot": "right"}
  },
  "n10": {
    "tiffany": {"x": 400.0, "y": 0}
  }
}
```

Maps node IDs to character position overrides. Only stores changes, not full state.

---

## 6. Chart JSON Schema (Rhythm)

Charts: `assets/data/charts/{song_id}.json` (Psych Engine-compatible format)

```json
{
  "song": {
    "song": "gentle_start_duet",
    "bpm": 127,
    "offset": 0.0,
    "stage": "stage1",
    "player": "mc",
    "singers": ["mc", "hanami"],
    "notes": [
      {
        "sectionNotes": [[0, 0, 0, 0], [500, 1, 0, 0]],
        "singers": ["mc"],
        "mustHitSection": true,
        "lengthInSteps": 16
      }
    ]
  }
}
```

**Note format:** `[timeMs, lane, holdMs, noteType]`

- `timeMs`: Absolute timestamp in milliseconds
- `lane`: 0-3 positive (player judged), negative (animation only)
- `holdMs`: 0 for tap, >0 for hold duration
- `noteType`: 0=normal, 1=swing

**Lane decoding:**
- `mustHitSection=true`: lanes 0-3 = player input (judged), lanes 4+ = opponent
- `mustHitSection=false`: all lanes = opponent animation only
- Negative lanes: always animation only

---

## 7. Game State Variables

Managed by `GameState.hx`. All variables start at 0, all flags start at false.

### Numeric Variables (Float)

| Variable | Range | Description |
|----------|-------|-------------|
| `tiffany_rot` | 0-10 | Tiffany deterioration level |
| `cassian_rot` | 0-10 | Cassian deterioration level |
| `hanami_rot` | 0-10 | Hanami deterioration level |
| `harumi_rot` | 0-10 | Harumi deterioration level |
| `tiffany_trust` | 0-10 | Player trust with Tiffany |
| `cassian_trust` | 0-10 | Player trust with Cassian |
| `hanami_trust` | 0-10 | Player trust with Hanami |
| `harumi_trust` | 0-10 | Player trust with Harumi |

### Boolean Flags

| Flag | Description |
|------|-------------|
| `flags.asked_tiffany` | Asked Tiffany a key question |
| `flags.asked_cassian` | Asked Cassian a key question |
| `flags.met_hanami` | Met Hanami in the story |
| `flags.met_harumi` | Met Harumi in the story |
| `flags.first_rhythm_complete` | Completed first rhythm game |
| `flags.act1_complete` | Completed Act 1 |
| `flags.act2_complete` | Completed Act 2 |
| `flags.act3_complete` | Completed Act 3 |
| `player.flags.puppet_mode` | Act 4 system override active |
| `player.flags.aware` | Player has become "aware" |

---

## 8. Text Effects Reference

| Effect | Parameters | Description |
|--------|-----------|-------------|
| `shake` | `effect_intensity` (default 2.0) | Vibrating text |
| `glitch` | `effect_intensity` (default 5.0) | Random displacement + color flicker |
| `wave` | `effect_speed` (3.0), `effect_amplitude` (5.0) | Vertical sine wave |
| `rainbow` | `effect_speed` (default 2.0) | HSB color cycling |
| `fade` | `effect_speed` (default 2.0) | Alpha pulsing |
| `typewriter` | `effect_speed` (default 30.0 chars/sec) | Character-by-character reveal |

---

## 9. Background Transition Types

| Transition | Description |
|-----------|-------------|
| `cut` | Instant switch |
| `fade` | Alpha blend new over old |
| `crossfade` | Simultaneous fade out old + fade in new |
| `slide_left` | New slides in from left |
| `slide_right` | New slides in from right |
| `slide_up` | New slides in from below |
| `slide_down` | New slides in from above |

---

## 10. Character Transitions

| Transition | Description |
|-----------|-------------|
| `fade` | Alpha 0 to 1 |
| `fade_out` | Alpha 1 to 0 |
| `slide_left` | Slide in from left |
| `slide_right` | Slide in from right |
| `slide_up` | Slide in from below |
| `pop` | Scale 0.1x to 1x with backOut ease |
| `bounce` | Bounce up then settle |

---

## 11. Slot Positions

Based on 1280x720 resolution. Defined in `Constants.hx`.

| Slot | X Coordinate | Description |
|------|-------------|-------------|
| `far_left` | -200 | Off-screen left (for slide-in) |
| `left` | 100 | Left third |
| `center_left` | 240 | Left of center |
| `center` | 640 | Middle (default) |
| `center_right` | 1040 | Right of center |
| `right` | 1180 | Right third |
| `far_right` | 1480 | Off-screen right (for slide-in) |

---

## 12. Audio Transition Types

| Transition | Description |
|-----------|-------------|
| `cut` | Instant switch to new track |
| `fade` | Crossfade old out, new in (default 2.0s) |
| `wait_till_end` | Queue next track after current finishes |

---

## 13. File Path Conventions

```
assets/
  data/
    characters/
      characters.json           # Master character registry
      {id}/poses.json           # Per-character pose definitions
      {id}/{id}.json            # Rhythm character data (optional)
    scenes/
      {act}/scene{N}.json       # Scene files
      template/                 # Template scenes
    charts/
      {song_id}.json            # Rhythm chart data
    placements/
      {scene_id}_placement.json # Character positions
  images/
    characters/{id}/            # Character spritesheets
    bg/{location}/              # Background images (with time variants)
    stages/                     # Rhythm stage backgrounds
    ui/                         # UI elements
  music/                        # BGM tracks (.ogg)
  sounds/                       # Sound effects (.wav)
```
