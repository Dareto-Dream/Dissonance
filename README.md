# Dissonance Visual Novel Engine (HaxeFlixel 2025)

A modular visual novel framework built on HaxeFlixel 5.x with node-based JSON scripting, advanced audio transitions, and rhythm game integration.

---

## Core Features

* **Node-based JSON scripting** - Lightweight, readable scene format
* **Advanced audio system** - Music transitions with fade, cut, and wait_till_end modes
* **Text effects** - Six animation types (shake, glitch, wave, rainbow, fade, typewriter)
* **Character system** - Multi-layer sprites with poses, emphasis, and custom positioning
* **Background transitions** - Seven transition modes including slides and crossfades
* **Screen effects** - Shake, flash, and glitch effects
* **Conditional branching** - Dynamic story paths based on game state
* **Rhythm game integration** - Seamless transitions between VN and gameplay

---

## Project Structure

```
source/
├── Main.hx
├── states/
│   ├── TitleState.hx          Title screen and main menu
│   └── VNState.hx             VN rendering and scene management
│
├── core/
│   ├── audio/
│   │   └── AudioSystem.hx     Music transitions and sound effects
│   ├── dialogue/
│   │   ├── DialogueSystem.hx  Text display with effects
│   │   ├── ChoiceSystem.hx    Player choices
│   │   └── TextEffectSystem.hx Animation effects
│   ├── effects/
│   │   └── EffectSystem.hx    Screen effects
│   ├── rendering/
│   │   ├── BackgroundSystem.hx Background transitions
│   │   ├── CharacterSystem.hx  Character management
│   │   └── CharacterRenderer.hx Sprite layering
│   └── scene/
│       ├── SceneParser.hx     JSON loading and validation
│       ├── SceneRunner.hx     Node execution
│       └── PlacementManager.hx Custom positioning
│
├── vn/
│   ├── VNCommands.hx          Action routing
│   ├── VNConditions.hx        Expression evaluation
│   ├── VNConfig.hx            Configuration
│   └── RhythmBridge.hx        Gameplay integration
│
├── rhythm/
│   ├── RhythmState.hx          Gameplay state lifecycle
│   ├── Conductor.hx            Authoritative timing source
│   ├── ChartData.hx            Psych-style chart schema
│   ├── ChartHandler.hx         Chart expansion + lane decoding
│   ├── NoteHandler.hx          Spawning + hit/miss logic
│   ├── JudgementSystem.hx      Timing windows + ratings
│   ├── Note.hx                 Runtime note model
│   ├── ArrowRenderer.hx        Receptor UI rendering
│   ├── NoteRenderer.hx         Note visual rendering
│   ├── CharacterSpriteManager.hx Data-driven character sprites
│   ├── CharacterAnimationBridge.hx Gameplay → animation router
│   └── RhythmCompletionBridge.hx Deferred VN callback executor
│
└── util/
    └── SceneManager.hx        Scene transitions
```

---

# Scene Format

Scenes are JSON files stored in `assets/data/scenes/<act>/<scene>.json`.

## Basic Structure

```json
{
  "scene_id": "example_scene",
  "start": "n1",
  "nodes": [
    {
      "id": "n1",
      "type": "dialogue",
      "speaker": "Character",
      "text": "Welcome.",
      "next": "n2"
    }
  ]
}
```

---

# Node Types

## Dialogue

Displays character dialogue with optional text effects.

```json
{
  "id": "n1",
  "type": "dialogue",
  "speaker": "Tiffany",
  "character": "tiffany",
  "pose": "smile",
  "text": "Welcome to the music club.",
  "text_effect": "wave",
  "effect_speed": 3.0,
  "next": "n2"
}
```

**Parameters:**
- `speaker` - Name displayed in dialogue box
- `character` - Character ID for sprite display
- `pose` - Character pose/expression
- `text` - Dialogue text
- `text_effect` - Optional: shake, glitch, wave, rainbow, fade, typewriter
- `effect_intensity` - For shake/glitch (default: 2.0/5.0)
- `effect_speed` - For wave/rainbow/fade/typewriter
- `effect_amplitude` - For wave effect (default: 5.0)
- `next` - Next node ID

## Narration

Displays narrator text without character.

```json
{
  "id": "n2",
  "type": "narration",
  "text": "The room falls quiet.",
  "text_effect": "fade",
  "next": "n3"
}
```

## Action

Performs actions like background changes, character display, effects, and audio.

### Background

```json
{
  "id": "n3",
  "type": "action",
  "action": "set_bg",
  "background": "assets/images/bg/classroom.png",
  "transition": "fade",
  "duration": 0.6,
  "next": "n4"
}
```

**Transitions:** cut, fade, crossfade, slide_left, slide_right, slide_up, slide_down

### Show Character

```json
{
  "id": "n4",
  "type": "action",
  "action": "show_character",
  "character": "tiffany",
  "pose": "smile",
  "position": "center",
  "transition": "fade",
  "duration": 0.4,
  "next": "n5"
}
```

### Hide Character

```json
{
  "id": "n5",
  "type": "action",
  "action": "hide_character",
  "character": "tiffany",
  "transition": "fade",
  "duration": 0.3,
  "next": "n6"
}
```

### Play Music

```json
{
  "id": "n6",
  "type": "action",
  "action": "play_music",
  "track": "assets/music/theme.ogg",
  "volume": 0.7,
  "transition": "fade",
  "duration": 2.0,
  "next": "n7"
}
```

**Transition types:**
- `fade` - Smooth crossfade between tracks
- `cut` - Instant change
- `wait_till_end` - Wait for current track to finish

### Other Audio Actions

```json
// Stop music
{"action": "stop_music"}

// Fade out music
{"action": "fade_out_music", "duration": 1.5}

// Play sound effect
{"action": "play_sound", "sound": "assets/sounds/door.wav", "volume": 0.7}

// Set default BGM
{"action": "set_default_bgm", "track": "assets/music/main.ogg", "volume": 0.8}

// Play default BGM
{"action": "play_default_bgm", "volume": 0.8}
```

### Screen Effects

```json
// Shake screen
{"action": "shake_screen", "intensity": 0.03, "duration": 2.0}

// Flash screen
{"action": "flash", "color": "white", "duration": 0.5}

// Glitch effect
{"action": "glitch", "intensity": 2.0, "duration": 0.8}
```

### Text Effects

```json
// Set persistent text effect
{
  "action": "set_text_effect",
  "text_effect": "glitch",
  "effect_intensity": 8.0
}

// Clear text effect
{"action": "clear_text_effect"}
```

## Choice

Presents player choices.

```json
{
  "id": "n7",
  "type": "choice",
  "choices": [
    {"text": "Comfort her", "target": "n8a"},
    {"text": "Stay silent", "target": "n8b"}
  ]
}
```

## Conditional

Branches based on game state.

```json
{
  "id": "n9",
  "type": "if",
  "condition": "tiffany_rot <= 2",
  "trueNode": "n10a",
  "falseNode": "n10b"
}
```

## Jump

Jumps to another node.

```json
{
  "id": "n11",
  "type": "jump",
  "target": "n1"
}
```

## Game

Starts rhythm gameplay.

```json
{
  "id": "n12",
  "type": "game",
  "song": "gentle_start_duet",
  "next": "n13"
}
```

## End

Ends scene and loads next.

```json
{
  "id": "n14",
  "type": "end",
  "next_scene": "scenes/act2/intro.json"
}
```

---

# Audio System

## Overview

AudioSystem manages all music and sound effects with transition support. All states must use AudioSystem rather than FlxG.sound directly to prevent audio overlap.

## Music Playback

### In Code

```haxe
// Basic playback
AudioSystem.playMusic("assets/music/track.ogg", 0.7);

// With fade transition
AudioSystem.playMusic("assets/music/track.ogg", 0.7, "fade", 2.0);

// Instant change
AudioSystem.playMusic("assets/music/track.ogg", 0.7, "cut");

// Wait for current track to end
AudioSystem.playMusic("assets/music/track.ogg", 0.7, "wait_till_end");
```

### In JSON Scenes

```json
{
  "type": "action",
  "action": "play_music",
  "track": "assets/music/scene_theme.ogg",
  "volume": 0.7,
  "transition": "fade",
  "duration": 2.0
}
```

## Music Control

```haxe
// Stop all music
AudioSystem.stopMusic();

// Fade out
AudioSystem.fadeOutMusic(1.5);

// Check if playing
if (AudioSystem.isMusicPlaying()) { }

// Get current track
var track = AudioSystem.getCurrentTrack();

// Set volume
AudioSystem.setVolume(0.5);
```

## Default BGM

```haxe
// Set default background music
AudioSystem.setDefaultBGM("assets/music/main_theme.ogg", 0.8);

// Play default BGM
AudioSystem.playDefaultBGM(0.8);
```

## Sound Effects

```haxe
AudioSystem.playSound("assets/sounds/door_knock.wav", 0.7);
```

## TitleState Integration

```haxe
class TitleState extends FlxState
{
    override public function create():Void
    {
        super.create();
        
        // Use AudioSystem, not FlxG.sound
        AudioSystem.playMusic("assets/music/title.ogg", 0.7);
    }
    
    private function startGame():Void
    {
        // Fade out before transition
        AudioSystem.fadeOutMusic(0.5);
        
        FlxG.camera.fade(FlxColor.BLACK, 0.5, false, function() {
            FlxG.switchState(() -> new VNState("scenes/act1/scene1.json"));
        });
    }
}
```

## Transition Duration Guidelines

- **0.5-1.0s** - Quick scene changes within same mood
- **1.5-2.0s** - Standard scene-to-scene transitions
- **2.5-4.0s** - Act changes, dramatic moments
- **4.0s+** - Special dramatic sequences

---

# Text Effects

## Available Effects

### Shake
Random jitter for nervousness, earthquakes, fear.
```json
{"text_effect": "shake", "effect_intensity": 3.0}
```

### Glitch
Position jumps and color corruption for system errors, horror.
```json
{"text_effect": "glitch", "effect_intensity": 5.0}
```

### Wave
Sine wave motion for ghosts, magic, floating.
```json
{"text_effect": "wave", "effect_speed": 3.0, "effect_amplitude": 5.0}
```

### Rainbow
Color cycling for magical effects, celebrations.
```json
{"text_effect": "rainbow", "effect_speed": 2.0}
```

### Fade
Alpha pulsing for mysterious, ethereal effects.
```json
{"text_effect": "fade", "effect_speed": 2.0}
```

### Typewriter
Character-by-character reveal for dramatic reveals.
```json
{"text_effect": "typewriter", "effect_speed": 40.0}
```

## Effect Parameters

| Effect | Primary Parameter | Secondary Parameter | Default |
|--------|------------------|---------------------|---------|
| shake | effect_intensity | - | 2.0 |
| glitch | effect_intensity | - | 5.0 |
| wave | effect_speed | effect_amplitude | 3.0, 5.0 |
| rainbow | effect_speed | - | 2.0 |
| fade | effect_speed | - | 2.0 |
| typewriter | effect_speed (chars/sec) | - | 30.0 |

## Combining Effects

```json
{
  "id": "earthquake_effect",
  "type": "action",
  "action": "shake_screen",
  "intensity": 0.03,
  "duration": 2.0,
  "next": "earthquake_dialogue"
},
{
  "id": "earthquake_dialogue",
  "type": "dialogue",
  "speaker": "Character",
  "text": "Everything is shaking!",
  "text_effect": "shake",
  "effect_intensity": 5.0,
  "next": "next_node"
}
```

---

# Character System

## Character Definitions

Characters are defined in `assets/data/characters.json`:

```json
{
  "tiffany": {
    "name": "Tiffany",
    "default_pose": "default_smile",
    "poses": {
      "default_smile": {
        "base": "assets/images/characters/tiffany/base.png",
        "expression": "assets/images/characters/tiffany/smile.png"
      }
    }
  }
}
```

## Display Characters

```json
{
  "type": "action",
  "action": "show_character",
  "character": "tiffany",
  "pose": "smile",
  "position": "center",
  "transition": "fade",
  "duration": 0.4
}
```

**Positions:** left, center, right, or custom via PlacementManager

## Custom Positioning

Create placement files in `assets/data/placements/{scene_id}_placement.json`:

```json
{
  "node_id": {
    "x": 400,
    "y": 200,
    "scale": 0.8
  }
}
```

## Character Emphasis

Characters automatically emphasize (brighten) when speaking and deemphasize (darken) others, similar to DDLC.

---

# Background System

## Transitions

```json
{
  "type": "action",
  "action": "set_bg",
  "background": "assets/images/bg/classroom.png",
  "transition": "fade",
  "duration": 0.6
}
```

**Available transitions:**
- `cut` - Instant change
- `fade` - Fade to new background
- `crossfade` - Fade old while fading in new
- `slide_left` - Slide from right
- `slide_right` - Slide from left
- `slide_up` - Slide from bottom
- `slide_down` - Slide from top

---

# Screen Effects

## Shake

Camera shake for impact moments.

```json
{
  "action": "shake_screen",
  "intensity": 0.03,
  "duration": 2.0
}
```

## Flash

Color flash overlay.

```json
{
  "action": "flash",
  "color": "white",
  "duration": 0.5
}
```

## Glitch

Combined shake and flash for horror.

```json
{
  "action": "glitch",
  "intensity": 2.0,
  "duration": 0.8
}
```

---

# Rhythm Engine

## Overview

The rhythm engine is a fully decoupled gameplay loop that can be launched from VN scenes via `RhythmBridge`. It is designed around deterministic timing and event-driven rendering:

- **RhythmState** (`source/rhythm/RhythmState.hx`) orchestrates gameplay and connects systems.
- **Conductor** (`source/rhythm/Conductor.hx`) is the single authoritative timing source (ms-only).
- **ChartHandler** (`source/rhythm/ChartHandler.hx`) expands Psych-style charts into sorted runtime notes and decodes lanes.
- **NoteHandler** (`source/rhythm/NoteHandler.hx`) spawns notes, judges input, and emits events.
- **JudgementSystem** (`source/rhythm/JudgementSystem.hx`) scores timing windows (SICK/GOOD/BAD/MISS).
- **ArrowRenderer** + **NoteRenderer** render receptors and moving notes.
- **CharacterSpriteManager** + **CharacterAnimationBridge** load characters and play sing/idle animations.
- **RhythmCompletionBridge** defers VN callbacks until VN renderers are ready.

## Data Locations

- **Charts:** `assets/data/charts/<song>.json`
- **Music:** `assets/music/<song>.ogg`
- **Stage backgrounds:** `assets/images/stages/<stage>.png` (optional)
- **Arrow UI:** `assets/images/ui/arrows/receptor.png`
- **Notes:** `assets/images/ui/arrows/note.png`
- **Rhythm character configs:** `assets/data/characters/<id>/<id>.json`
- **Rhythm character atlases:** `assets/images/<image>.png` + `.xml` (from the JSON `image` field)

## Chart Format (Psych-style)

Charts are JSON files with a `song` root. Notes are stored as absolute timestamps (ms), not beats.

```json
{
  "song": {
    "song": "gentle_start_duet",
    "bpm": 120,
    "offset": 0.0,
    "stage": "stage1",
    "player": "player",
    "singers": ["hanami"],
    "notes": [
      {
        "sectionNotes": [
          [0, 0, 0, 0],
          [500, 1, 0, 0]
        ],
        "mustHitSection": true,
        "playerLaneCount": 4,
        "lengthInSteps": 16,
        "bpm": 120
      }
    ]
  }
}
```

**Note entry format:** `[timeMs, lane, holdMs?, noteType?]`

- `timeMs` is absolute (authoritative).
- `lane` is decoded into **input lanes** and **animation lanes** by `ChartHandler`.
- `holdMs` > 0 creates HOLD_HEAD, HOLD_TICK(s), and HOLD_TAIL slices.
- `noteType` currently supports `0` (normal) and `1` (swing).

### Lane Decoding Rules

`ChartHandler.decodeLane` defines the canonical mapping:

- **mustHitSection = true**
  - `lane < playerLaneCount` → player note (`inputLane = lane`)
  - `lane >= playerLaneCount` → opponent note (`singerIndex` derived from lane groups of 4)
- **mustHitSection = false**
  - All lanes are opponent notes (`inputLane = -1`)

Always use decoded fields (`inputLane`, `animLane`, `singerIndex`) from `Note`, not raw `lane`.

## Rhythm Character Data

Rhythm characters are loaded from `assets/data/characters/<id>/<id>.json` and drive sprite/animation setup.

```json
{
  "animations": [
    {
      "anim": "singLEFT",
      "name": "singLEFT",
      "fps": 5,
      "loop": false,
      "offsets": [272, 831],
      "indices": []
    }
  ],
  "image": "characters/hanami/hanami_rhythm",
  "position": [0, 0],
  "scale": 0.4,
  "flip_x": true,
  "sing_duration": 6.1
}
```

**Key fields used by the engine:**

- `image` → atlas basename under `assets/images/` (expects `.png` + `.xml`)
- `animations` → maps engine keys (`anim`) to atlas prefixes (`name`)
- `position` → base sprite position
- `scale` → global scale multiplier
- `flip_x` → horizontal flip
- `sing_duration` → beat-based sing hold duration

**Animation keys used by the engine:**
`idle`, `singLEFT`, `singDOWN`, `singUP`, `singRIGHT`, `miss`, `singRelease`

## Gameplay Flow (VN → Rhythm → VN)

1. VN node `{"type": "game", "song": "<id>"}` calls `RhythmBridge.start`.
2. `RhythmBridge` injects chart path + completion callback into `RhythmState`.
3. `RhythmState` loads the chart, music, stage, and spawns gameplay systems.
4. `NoteHandler` emits events to renderers and animation bridge.
5. On song completion, `RhythmCompletionBridge` stores result and callback.
6. VN state is rebuilt, and the callback is executed safely after VN renderers initialize.

## Input Mapping (current)

Player lanes are mapped to keyboard input in `RhythmState.handleInput()`:

- Lane 0 → `A`
- Lane 1 → `S`
- Lane 2 → `D`
- Lane 3 → `F`

This is currently fixed and can be extended later for configurable inputs.

---

# System Architecture

## SceneParser

Loads and validates JSON scene files:
- Validates scene structure
- Checks node IDs are unique
- Verifies all referenced nodes exist
- Creates node lookup dictionary

## SceneRunner

Executes the node graph:
- Tracks current node
- Calls VNCommands for each node type
- Handles branching and jumps
- Manages scene flow

## VNCommands

Routes actions to subsystems:
- `dialogue` → DialogueSystem
- `narration` → DialogueSystem
- `action` → Appropriate system based on action type
- `choice` → ChoiceSystem
- `game` → RhythmBridge
- `end` → SceneManager

## DialogueSystem

Manages text display:
- Parses and applies text effects
- Handles text advancement
- Manages effect state
- Updates animations each frame

## Integration

VNState must call `DialogueSystem.update(elapsed)` in its update loop for text effects to animate.

---

# Runtime Flow

1. TitleState plays title music via AudioSystem
2. User clicks PLAY, title music fades out
3. VNState loads and creates SceneRunner
4. SceneRunner loads scene JSON via SceneParser
5. SceneRunner executes starting node
6. VNCommands routes actions to subsystems
7. Subsystems update visuals, audio, gameplay
8. DialogueSystem updates text effects each frame
9. SceneRunner advances to next node
10. Process repeats until end node
11. SceneManager loads next scene

---

# Development

## Adding Node Types

1. Add case in SceneRunner.runNode()
2. Add handler in VNCommands
3. Implement subsystem behavior

## Adding Transitions

1. Add method in BackgroundSystem
2. Add case in transition switch
3. Implement transition logic

## Adding Text Effects

1. Add effect type to TextEffectSystem
2. Implement effect logic
3. Add parsing case in DialogueSystem

## Extending Characters

Character system supports expansion without affecting SceneRunner or VNCommands. Add poses, transitions, and positions as needed.

---

# Debugging

## Common Issues

### Audio Overlap
**Cause:** Using FlxG.sound.playMusic() instead of AudioSystem  
**Fix:** Always use AudioSystem.playMusic() in all states

### Unknown Node Type
**Cause:** Using `"type": "music"` instead of action node  
**Fix:** Use `"type": "action"` with `"action": "play_music"`

### Text Effects Not Animating
**Cause:** DialogueSystem.update() not called  
**Fix:** Call DialogueSystem.update(elapsed) in VNState.update()

### Character Positioning Wrong
**Cause:** Missing or incorrect placement data  
**Fix:** Create placement file in `assets/data/placements/`

## Console Output

Press F12 in browser to view:
- AudioSystem transition logs
- SceneRunner node execution
- DialogueSystem text display
- Background transitions
- Character operations
- Condition evaluations

---

# Implementation Status

## Completed Systems

- AudioSystem (music transitions, sound effects)
- DialogueSystem (text display with effects)
- TextEffectSystem (6 animation types)
- BackgroundSystem (7 transition modes)
- CharacterSystem (multi-layer sprites, positioning)
- CharacterRenderer (sprite layering)
- PlacementManager (custom positioning)
- EffectSystem (screen effects)
- SceneParser (JSON validation)
- SceneRunner (node execution)
- VNCommands (action routing)
- TitleState (menu and audio integration)
- VNState (scene rendering)

## In Development

- ChoiceSystem UI polish
- ConditionParser expression support
- RhythmBridge gameplay integration

---

# Performance

- Text effects use simple math operations
- Effects only active when text visible
- Automatic cleanup on dialogue change
- No memory leaks or accumulation
- Audio system prevents overlap
- Efficient crossfading with FlxTween
- Minimal CPU overhead

---

# Best Practices

## Audio

1. Always use AudioSystem for music
2. Fade between scenes for smooth transitions
3. Use appropriate transition durations
4. Stop or fade out music before state changes

## Scenes

1. Use descriptive node IDs
2. Keep scenes focused and manageable
3. Validate JSON before testing
4. Use text effects sparingly for impact

## Characters

1. Define all poses in characters.json
2. Use placement files for complex scenes
3. Leverage emphasis system for dialogue
4. Use appropriate transition durations

## Effects

1. Combine text and screen effects carefully
2. Match effect intensity to mood
3. Don't overuse effects
4. Test effects with actual dialogue
