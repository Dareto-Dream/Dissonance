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

### Node Types

Every node has an `id` (string, unique within scene) and a `type` field.

#### 1.1 dialogue

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
| `id` | string | Yes | Unique node identifier |
| `type` | string | Yes | Must be `"dialogue"` |
| `speaker` | string | Yes | Display name in dialogue box |
| `text` | string | Yes | Dialogue text |
| `next` | string | Yes | Next node ID |
| `character` | string | No | Character ID for pose/emphasis |
| `pose` | string | No | Pose name to set before showing text |
| `text_effect` | string | No | One of: `shake`, `glitch`, `wave`, `rainbow`, `fade`, `typewriter` |
| `effect_speed` | float | No | Speed parameter for text effect |
| `effect_intensity` | float | No | Intensity parameter for text effect |
| `effect_amplitude` | float | No | Amplitude parameter for wave effect |

#### 1.2 narration

Narrator text with no character speaker.

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
| `id` | string | Yes | Unique node identifier |
| `type` | string | Yes | Must be `"narration"` |
| `text` | string | Yes | Narration text |
| `next` | string | Yes | Next node ID |
| `text_effect` | string | No | Same options as dialogue |
| `effect_speed` | float | No | Speed parameter for text effect |

#### 1.3 action

System operation. The `action` field selects which operation runs and what extra fields are expected.

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

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique node identifier |
| `type` | string | Yes | Must be `"action"` |
| `action` | string | Yes | Action name (see Action Types Reference below) |
| `next` | string | Yes | Next node ID (for most actions) |
| *(action-specific)* | varies | Varies | See Action Types Reference |

#### 1.4 choice

Player decision point branching to different nodes.

```json
{
  "id": "n1",
  "type": "choice",
  "choices": [
    {"text": "Help her practice", "next": "n2a"},
    {"text": "Let her figure it out", "next": "n2b"},
    {"text": "Ask about the competition", "next": "n2c", "condition": "tiffany_trust >= 3"}
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique node identifier |
| `type` | string | Yes | Must be `"choice"` |
| `choices` | array | Yes | Array of choice objects |
| `choices[].text` | string | Yes | Display text for option |
| `choices[].next` | string | Yes | Node ID to jump to if selected |
| `choices[].condition` | string | No | Condition expression; hides option if false |

#### 1.5 if

Conditional branch based on game state expression.

```json
{
  "id": "n1",
  "type": "if",
  "condition": "tiffany_rot <= 2 and flags.asked_tiffany == true",
  "trueNode": "n2a",
  "falseNode": "n2b"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique node identifier |
| `type` | string | Yes | Must be `"if"` |
| `condition` | string | Yes | Boolean expression using variables and flags |
| `trueNode` | string | Yes | Node ID if condition is true |
| `falseNode` | string | Yes | Node ID if condition is false |

**Condition syntax:** Variables (`tiffany_rot`), flags (`flags.asked_tiffany`), operators (`==`, `!=`, `<`, `<=`, `>`, `>=`), connectors (`and`, `or`), grouping (`()`), literals (numbers, `true`, `false`).

#### 1.6 jump

Unconditional jump to another node.

```json
{
  "id": "n1",
  "type": "jump",
  "target": "n5"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique node identifier |
| `type` | string | Yes | Must be `"jump"` |
| `target` | string | Yes | Node ID to jump to |

#### 1.7 game

Launch a rhythm gameplay segment and resume the VN after completion.

```json
{
  "id": "n1",
  "type": "game",
  "song": "gentle_start_duet",
  "next": "n2"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique node identifier |
| `type` | string | Yes | Must be `"game"` |
| `song` | string | Yes | Song ID matching a file in `assets/data/charts/` |
| `next` | string | Yes | Node ID to resume at after rhythm game ends |

#### 1.8 end

Scene completion, transitions to the next scene.

```json
{
  "id": "n1",
  "type": "end",
  "next_scene": "scenes/act1/scene2.json"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique node identifier |
| `type` | string | Yes | Must be `"end"` |
| `next_scene` | string | Yes | Relative path to next scene file |

---

## 2. Action Types Reference

All actions appear as `{"type": "action", "action": "<name>", ...fields, "next": "..."}`.

### show_character

Show a character on screen with optional entrance transition.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `character` | Yes | string | Character ID |
| `pose` | No | string | Pose name (default: `"default"`) |
| `transition` | No | string | Entrance transition type |
| `duration` | No | float | Transition duration in seconds (default: `0.4`) |

```json
{"action": "show_character", "character": "tiffany", "pose": "smile", "transition": "fade", "duration": 0.4}
```

### hide_character

Hide a character from screen.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `character` | Yes | string | Character ID |
| `transition` | No | string | Exit transition type |
| `duration` | No | float | Transition duration in seconds (default: `0.4`) |

```json
{"action": "hide_character", "character": "tiffany", "transition": "fade", "duration": 0.3}
```

### move_character

Slide a character to a new slot position.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `character` | Yes | string | Character ID |
| `slot` | Yes | string | Target slot name (see Slot Reference) |
| `duration` | No | float | Slide duration in seconds (default: `0.45`) |

```json
{"action": "move_character", "character": "tiffany", "slot": "left", "duration": 0.5}
```

### set_background

Change the background image.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `background` | Yes | string | Path to background image |
| `transition` | No | string | Transition type (default: `"cut"`) |
| `duration` | No | float | Transition duration in seconds |

```json
{"action": "set_bg", "background": "assets/images/bg/classroom1/day1.png", "transition": "fade", "duration": 1.0}
```

### play_music

Start playing a music track.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `track` | Yes | string | Path to music file |
| `volume` | No | float | Volume 0.0–1.0 |
| `transition` | No | string | Audio transition type |
| `duration` | No | float | Transition duration in seconds |

```json
{"action": "play_music", "track": "assets/music/theme_melancholy.ogg", "volume": 0.8}
```

### stop_music

Stop music immediately with no fade.

```json
{"action": "stop_music"}
```

### play_sound

Play a one-shot sound effect.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `sound` | Yes | string | Path to sound file |
| `volume` | No | float | Volume 0.0–1.0 |

```json
{"action": "play_sound", "sound": "assets/sounds/door_creak.wav", "volume": 0.6}
```

### fade_in

Fade the screen in from black.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `duration` | No | float | Fade duration in seconds (default: `1.0`) |

```json
{"action": "fade_in", "duration": 0.8}
```

### fade_out

Fade the screen out to black.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `duration` | No | float | Fade duration in seconds (default: `1.0`) |

```json
{"action": "fade_out", "duration": 1.0}
```

### shake_screen

Apply a screen shake effect.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `intensity` | No | float | Shake magnitude in pixels |
| `duration` | No | float | Duration in seconds |

```json
{"action": "shake_screen", "intensity": 8.0, "duration": 0.5}
```

### flash_screen

Flash the screen to a color.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `color` | No | string | Hex color `#RRGGBB` (default: `#FFFFFF`) |
| `duration` | No | float | Flash duration in seconds |

```json
{"action": "flash", "color": "#FFFFFF", "duration": 0.3}
```

### tint_character

Apply a color tint to one or all characters.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `color` | Yes | string | Hex color `#RRGGBB` or `#AARRGGBB` |
| `character` | No | string | Character ID; omit to tint all characters |

```json
{"action": "set_tint", "character": "tiffany", "color": "#888888"}
{"action": "set_tint", "color": "#666666"}
```

### clear_tint

Remove color tint from one or all characters.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `character` | No | string | Character ID; omit to clear all |

```json
{"action": "clear_tint", "character": "tiffany"}
{"action": "clear_tint"}
```

### bounce_character

Play a bounce animation on a character.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `character` | Yes | string | Character ID |
| `height` | No | float | Bounce height in pixels (default: `30.0`) |
| `duration` | No | float | Animation duration in seconds (default: `0.5`) |

```json
{"action": "bounce_character", "character": "laura", "height": 40, "duration": 0.5}
```

### shake_character

Play a shake animation on a character.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `character` | Yes | string | Character ID |
| `intensity` | No | float | Shake magnitude in pixels (default: `15.0`) |
| `duration` | No | float | Animation duration in seconds (default: `0.5`) |

```json
{"action": "shake_character", "character": "cassian", "intensity": 20, "duration": 0.4}
```

### set_variable

Set or modify a numeric game variable.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `variable` | Yes | string | Variable name |
| `value` | Yes | float | Numeric value |
| `op` | No | string | Operation: `set` (default), `add`, `subtract`, `multiply` |

```json
{"action": "set_variable", "variable": "tiffany_rot", "value": 3}
{"action": "set_variable", "variable": "tiffany_rot", "op": "add", "value": 1}
{"action": "set_variable", "variable": "cassian_trust", "op": "subtract", "value": 2}
```

### set_flag

Set a boolean game flag.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `flag` | Yes | string | Flag name |
| `value` | No | bool | Value to set (default: `true`) |

```json
{"action": "set_flag", "flag": "flags.asked_tiffany", "value": true}
{"action": "set_flag", "flag": "player.flags.puppet_mode", "value": false}
```

### next_scene

Transition to a different scene file immediately.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `scene` | Yes | string | Relative path to scene file |

```json
{"action": "next_scene", "scene": "scenes/act2/scene1.json"}
```

---

## 3. Placement File Format

### File Location

```
assets/data/placements/{scene_id}_placement.json
```

### Format Specification

The placement file is a flat JSON object mapping node IDs to character position snapshots. Each entry specifies where one or more characters should be repositioned when the engine reaches that node. Characters not listed in a node's entry keep their previous position.

```json
{
  "node_id": { "char_id": "slot_name" },
  "node_id2": { "char_id": "slot_name", "other_char": "hidden" }
}
```

- Keys at the top level are **node IDs** from the scene file.
- Values are objects mapping **character IDs** to **slot name strings**.
- There is no outer `scene_id` or `placements` wrapper.
- There are no `x`, `y`, or coordinate fields — slot names only.

### Valid Slot Names

| Slot | X Coordinate | Description |
|------|-------------|-------------|
| `far_left` | -200 | Off-screen left (slide-in from left) |
| `left` | 100 | Left area of screen |
| `center_left` | 240 | Left of center |
| `center` | 640 | Screen center |
| `center_right` | 1040 | Right of center |
| `right` | 1180 | Right area of screen |
| `far_right` | 1480 | Off-screen right (slide-in from right) |
| `hidden` | — | Character is off-screen / not visible |

X coordinates are reference values at 1280×720 resolution (defined in `Constants.hx`).

### X-Coordinate Derivation Rule

If a placement entry has no `slot` field, the slot is derived from the `x` coordinate:

| x range | Derived slot |
|---------|-------------|
| `x < 0` | `far_left` |
| `x < 200` | `left` |
| `x < 450` | `center_left` |
| `x < 850` | `center` |
| `x < 1120` | `center_right` |
| `x < 1350` | `right` |
| `x >= 1350` | `far_right` |

### `hidden` Slot Semantics

A character in the `hidden` slot is positioned off-screen and not rendered. This is distinct from `hide_character`, which removes a character from the scene entirely. `hidden` in a placement file reserves the character's state while keeping it invisible, so it can be revealed without a full `show_character` action.

### Persistence Between Nodes

Placement entries are sparse — they only record changes. A character's position persists unchanged from node to node until a new placement entry overrides it. The engine reads the most recent placement entry at or before the current node.

### Example File

```json
{
  "scene_start": { "tiffany": "center" },
  "hanami_enters": { "hanami": "far_left" },
  "n10": {
    "tiffany": "right",
    "hanami": "center_left"
  },
  "n25": {
    "tiffany": "center",
    "hanami": "left",
    "cassian": "center_right",
    "laura": "far_right"
  }
}
```

---

## 4. Slot Position Reference Table

Based on 1280×720 resolution. Defined in `Constants.hx`.

| Slot | X Coord | Description |
|------|---------|-------------|
| `far_left` | -200 | Off-screen left (slide-in) |
| `left` | 100 | Left of screen |
| `center_left` | 240 | Left of center |
| `center` | 640 | Screen center |
| `center_right` | 1040 | Right of center |
| `right` | 1180 | Right of screen |
| `far_right` | 1480 | Off-screen right (slide-in) |

---

## 5. Character Definition Schema

### Master Registry

`assets/data/characters/characters.json`

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

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Character identifier (matches object key) |
| `vn.png` | Yes | VN spritesheet image path |
| `vn.xml` | Yes | VN spritesheet XML atlas path |
| `vn.defaultPose` | Yes | Default pose name used on show |
| `rhythm.png` | No | Rhythm mode spritesheet image path |
| `rhythm.xml` | No | Rhythm mode spritesheet XML atlas path |

### Per-Character Poses

`assets/data/characters/{id}/poses.json`

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
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `character` | Character ID |
| `config.scale` | Global scale multiplier for VN display |
| `config.base_offset` | Centering offset applied to all poses |
| `poses` | Map of pose name to layer stack |
| `poses[name].layers` | Array of `{frame, x, y}` referencing atlas frame names |

**Standard rhythm pose names:** `singLEFT`, `singDOWN`, `singUP`, `singRIGHT`, `idle`, `miss`

### Character Registry

| ID | Display Name | Role | Default Pose |
|----|-------------|------|-------------|
| `mc` | (Player) | Protagonist | `neutral` |
| `tiffany` | Tiffany | Club president | `neutral` |
| `hanami` | Hanami | Emotional anchor | `neutral` |
| `cassian` | Cassian | Processes grief through anger | `annoyed` |
| `laura` | Laura | Energetic club member | `happy` |

---

## 6. Rhythm Chart Schema

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

### Song Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `song` | string | Song identifier |
| `bpm` | float | Beats per minute |
| `offset` | float | Audio offset in milliseconds |
| `stage` | string | Stage background ID |
| `player` | string | Player character ID |
| `singers` | array | All character IDs performing in the song |
| `notes` | array | Array of section objects |

### Section Fields

| Field | Type | Description |
|-------|------|-------------|
| `sectionNotes` | array | Array of note arrays (see below) |
| `singers` | array | Character IDs singing this section |
| `mustHitSection` | bool | If true, lanes 0-3 are player-judged input |
| `lengthInSteps` | int | Section length in steps (typically 16) |

### Note Array Format

Each note is `[timeMs, lane, holdMs, noteType]`

| Index | Field | Type | Description |
|-------|-------|------|-------------|
| 0 | `timeMs` | float | Absolute timestamp in milliseconds |
| 1 | `lane` | int | Lane index; negative = animation only |
| 2 | `holdMs` | float | Hold duration: `0` for tap, `>0` for hold |
| 3 | `noteType` | int | `0` = normal, `1` = swing |

**Lane decoding:**
- `mustHitSection = true`: lanes `0–3` = player input (judged); lanes `4+` = opponent animation
- `mustHitSection = false`: all lanes = opponent animation only
- Negative lanes: always animation only, never judged

---

## 7. Game State Variables

Managed by `GameState.hx`. All variables default to `0`; all flags default to `false`.

### Numeric Variables (Float)

| Variable | Range | Description |
|----------|-------|-------------|
| `tiffany_rot` | 0–10 | Tiffany deterioration level |
| `cassian_rot` | 0–10 | Cassian deterioration level |
| `hanami_rot` | 0–10 | Hanami deterioration level |
| `harumi_rot` | 0–10 | Harumi deterioration level |
| `tiffany_trust` | 0–10 | Player trust level with Tiffany |
| `cassian_trust` | 0–10 | Player trust level with Cassian |
| `hanami_trust` | 0–10 | Player trust level with Hanami |
| `harumi_trust` | 0–10 | Player trust level with Harumi |

### Boolean Flags

| Flag | Description |
|------|-------------|
| `flags.asked_tiffany` | Player has asked Tiffany a key question |
| `flags.asked_cassian` | Player has asked Cassian a key question |
| `flags.met_hanami` | Player has met Hanami in the story |
| `flags.met_harumi` | Player has met Harumi in the story |
| `flags.first_rhythm_complete` | First rhythm game segment completed |
| `flags.act1_complete` | Act 1 completed |
| `flags.act2_complete` | Act 2 completed |
| `flags.act3_complete` | Act 3 completed |
| `player.flags.puppet_mode` | Act 4 system override is active |
| `player.flags.aware` | Player character has become "aware" |

---

## 8. Text Effects Reference

| Effect | Parameters | Description |
|--------|-----------|-------------|
| `shake` | `effect_intensity` (default: `2.0`) | Vibrating text displacement |
| `glitch` | `effect_intensity` (default: `5.0`) | Random displacement and color flicker |
| `wave` | `effect_speed` (default: `3.0`), `effect_amplitude` (default: `5.0`) | Vertical sine wave |
| `rainbow` | `effect_speed` (default: `2.0`) | HSB color cycling through all hues |
| `fade` | `effect_speed` (default: `2.0`) | Alpha pulsing in and out |
| `typewriter` | `effect_speed` (default: `30.0` chars/sec) | Character-by-character reveal |

---

## 9. Background Transition Types

| Transition | Description |
|-----------|-------------|
| `cut` | Instant switch, no animation |
| `fade` | Alpha blend new image over old |
| `crossfade` | Simultaneous fade out old and fade in new |
| `slide_left` | New image slides in from the left |
| `slide_right` | New image slides in from the right |
| `slide_up` | New image slides in from below |
| `slide_down` | New image slides in from above |

---

## 10. Character Transition Types

| Transition | Description |
|-----------|-------------|
| `fade` | Alpha 0 → 1 (show) or 1 → 0 (hide) |
| `fade_out` | Explicit alpha 1 → 0 |
| `slide_left` | Slide in from left |
| `slide_right` | Slide in from right |
| `slide_up` | Slide in from below |
| `pop` | Scale from 0.1× to 1× with backOut easing |
| `bounce` | Bounce up then settle to final position |

---

## 11. Audio Transition Types

| Transition | Description |
|-----------|-------------|
| `cut` | Instant switch to new track |
| `fade` | Crossfade old track out, new track in (default: `2.0s`) |
| `wait_till_end` | Queue next track to start after current finishes |

---

## 12. File Path Conventions

```
assets/
  data/
    characters/
      characters.json             # Master character registry
      {id}/poses.json             # Per-character pose definitions
      {id}/{id}.json              # Rhythm character data (optional)
    scenes/
      {act}/scene{N}.json         # Scene files (act1/, act2/, etc.)
      template/                   # Template scenes for editor
    charts/
      {song_id}.json              # Rhythm chart data
    placements/
      {scene_id}_placement.json   # Character slot positions per scene
  images/
    characters/{id}/              # Character spritesheets (.png + .xml)
    bg/{location}/                # Background images (with time-of-day variants)
    stages/                       # Rhythm stage backgrounds
    ui/                           # UI element images
  music/                          # BGM tracks (.ogg)
  sounds/                         # Sound effects (.wav)

source/
  core/
    audio/                        # AudioSystem
    dialogue/                     # DialogueSystem, ChoiceSystem
    effects/                      # EffectSystem
    rendering/                    # BackgroundSystem, CharacterSystem
    scene/                        # SceneRunner
    state/                        # GameState, SaveSystem
  rhythm/                         # Rhythm game systems
  vn/                             # VNCommands, VNReturnContext
  states/                         # HaxeFlixel game states
  ui/                             # UI components
  util/                           # SceneManager, utilities

python/
  modules/
    story/                        # Story editor module
    ui/                           # Widget library
```
