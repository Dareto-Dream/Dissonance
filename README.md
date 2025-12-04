# Dissonance Visual Novel Engine (HaxeFlixel 2025)

The Dissonance Engine is a modular visual novel framework built on HaxeFlixel 5.x.
It provides a node-based scripting system capable of branching narrative, transitions, character display, background control, and integration with rhythm gameplay segments.
This engine is custom-built for the narrative structure and pacing demands of the game "Dissonance."

---

## Overview

The purpose of the engine is to support a narrative that constantly switches between introspective visual novel scenes and gameplay sections. The design focuses on:

1. A lightweight, readable scene format using JSON
2. Clear separation of responsibilities across subsystems
3. A SceneRunner that executes nodes deterministically
4. Extensibility for additional effects, transitions, conditions, and gameplay hooks
5. Stability and predictability during Act 4 branching and puppeteer mode

The engine avoids reliance on FNF mod engines or legacy frameworks. Everything is written from scratch for maintainability and long-term growth.

---

# Project Structure

```
source/
├── Main.hx                     Entry point, initializes VNState
├── states/
│   └── VNState.hx              Main VN rendering layer and container
│
├── vn/
│   ├── SceneParser.hx          Loads JSON and maps nodes
│   ├── SceneRunner.hx          Executes the VN node graph
│   ├── VNCommands.hx           Dispatches node actions to systems
│   ├── VNConditions.hx         Evaluates expressions
│   ├── ConditionParser.hx      Expression parsing (to be implemented)
│   ├── DialogueSystem.hx       Dialogue UI with text effects support
│   ├── TextEffectSystem.hx     Text animation effects (shake, glitch, wave, etc.)
│   ├── BackgroundSystem.hx     Background transitions
│   ├── CharacterSystem.hx      Character poses and rendering
│   ├── CharacterRenderer.hx    Character sprite layering and rendering
│   ├── EffectSystem.hx         Screen effects (shake, flash, glitch)
│   ├── AudioSystem.hx          Sound and music management
│   ├── ChoiceSystem.hx         Choice UI
│   └── RhythmBridge.hx         VN to rhythm gameplay handoff
│
└── util/
    └── SceneManager.hx         Handles switching between VN scenes
```

---

# Scene File Format (JSON)

All scenes are stored here:

```
assets/data/scenes/<act>/<scene>.json
```

A scene definition contains a starting node and a list of nodes representing the narrative flow.

### Root Structure

```json
{
  "scene_id": "example_scene",
  "start": "n1",
  "nodes": [ ... ]
}
```

---

# Node Types

Each node is an object with at least:

```
"id": "n1",  
"type": "<node_type>"
```

The engine supports the following node types:

### 1. Dialogue

```json
{
  "id": "n1",
  "type": "dialogue",
  "speaker": "Tiffany",
  "character": "tiffany",
  "pose": "soft_smile",
  "text": "Welcome to the music club.",
  "text_effect": "wave",
  "effect_speed": 3.0,
  "effect_amplitude": 5.0,
  "next": "n2"
}
```

**Text Effects (Optional):**
- `text_effect`: Effect type (shake, glitch, wave, rainbow, fade, typewriter)
- `effect_intensity`: For shake/glitch effects (default: 2.0/5.0)
- `effect_speed`: For wave/rainbow/fade/typewriter effects (default: varies)
- `effect_amplitude`: For wave effect (default: 5.0)

### 2. Narration

```json
{
  "id": "n2",
  "type": "narration",
  "text": "The room falls quiet.",
  "text_effect": "fade",
  "effect_speed": 2.0,
  "next": "n3"
}
```

Text effects work the same way in narration nodes.

### 3. Action (Background, Characters, Effects)

```json
{
  "id": "n3",
  "type": "action",
  "action": "set_bg",
  "background": "assets/images/bg/classroom_day.png",
  "transition": "fade",
  "duration": 0.6,
  "next": "n4"
}
```

**Supported Background Transitions:**

* cut
* fade
* crossfade
* slide_left
* slide_right
* slide_up
* slide_down

**Supported Actions:**

* `set_bg` - Change background
* `show_character` - Display character sprite
* `hide_character` - Remove character sprite
* `shake_screen` - Screen shake effect
* `flash` - Screen flash effect
* `glitch` - Screen glitch effect
* `play_sound` - Play sound effect
* `play_music` - Play music track
* `set_text_effect` - Set persistent text effect
* `clear_text_effect` - Clear persistent text effect

**Persistent Text Effects Example:**

```json
{
  "id": "corruption_start",
  "type": "action",
  "action": "set_text_effect",
  "text_effect": "glitch",
  "effect_intensity": 8.0,
  "next": "corrupted_dialogue"
}
```

This applies the text effect to all subsequent dialogue until cleared with `clear_text_effect`.

### 4. Choice

```json
{
  "id": "n5",
  "type": "choice",
  "choices": [
    { "text": "Comfort her", "target": "n6a" },
    { "text": "Stay silent", "target": "n6b" }
  ]
}
```

### 5. Conditional (Branching)

```json
{
  "id": "n10",
  "type": "if",
  "condition": "tiffany_rot <= 2",
  "trueNode": "n11a",
  "falseNode": "n11b"
}
```

ConditionParser will evaluate the expression and SceneRunner will choose the next node accordingly.

### 6. Jump

```json
{
  "id": "n12",
  "type": "jump",
  "target": "n1"
}
```

### 7. Rhythm Start

```json
{
  "id": "n14",
  "type": "game",
  "song": "new_beginnings",
  "next": "n15"
}
```

RhythmBridge handles the gameplay session and returns when complete.

### 8. End Scene

```json
{
  "id": "end",
  "type": "end",
  "next_scene": "scenes/act2/intro.json"
}
```

SceneManager loads the next VN scene.

---

# Text Effects System

The engine includes a comprehensive text effects system for creating dramatic visual impact during dialogue and narration.

## Available Effects

### 1. Shake
Makes text shake randomly (nervousness, earthquakes, fear).

```json
{
  "text_effect": "shake",
  "effect_intensity": 3.0
}
```

### 2. Glitch
Creates a glitching effect with random position jumps and color corruption (system errors, horror).

```json
{
  "text_effect": "glitch",
  "effect_intensity": 5.0
}
```

### 3. Wave
Text moves in a sine wave pattern (ghosts, magic, floating).

```json
{
  "text_effect": "wave",
  "effect_speed": 3.0,
  "effect_amplitude": 5.0
}
```

### 4. Rainbow
Text cycles through rainbow colors (magical effects, celebrations).

```json
{
  "text_effect": "rainbow",
  "effect_speed": 2.0
}
```

### 5. Fade
Text pulses in and out (mysterious, ethereal).

```json
{
  "text_effect": "fade",
  "effect_speed": 2.0
}
```

### 6. Typewriter
Text appears character by character (dramatic reveals, computer text).

```json
{
  "text_effect": "typewriter",
  "effect_speed": 40.0
}
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

## Combining with Screen Effects

Text effects can be combined with screen effects for maximum dramatic impact:

```json
{
  "id": "earthquake",
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

# SceneParser

SceneParser loads a JSON file and validates:

* scene_id exists
* start node exists
* nodes array is valid
* all node ids are unique
* all referenced nodes exist

It builds a dictionary mapping:

```
nodeId -> nodeData
```

This allows SceneRunner to perform instant lookup without searching.

---

# SceneRunner

SceneRunner is the core state machine of the VN.
Its responsibilities:

* Track the current node
* Execute it
* Call VNCommands for each node type
* Advance to the next node
* Handle branching, jumps, choice callbacks, and endings

It never performs rendering. It only decides what should happen next.

When a node requests a transition into rhythm gameplay, SceneRunner pauses itself until RhythmBridge signals completion.

---

# VNCommands

This class routes actions to the correct subsystems.
Examples:

```
dialogue node        → DialogueSystem.show()
narration node       → DialogueSystem.showNarration()
set_bg action        → BackgroundSystem.set()
character show       → CharacterSystem.show()
effect:shake         → EffectSystem.shake()
play sound           → AudioSystem.playSound()
choice               → ChoiceSystem.show()
game                 → RhythmBridge.start()
end                  → SceneManager.loadScene()
set_text_effect      → DialogueSystem.setEffect()
clear_text_effect    → DialogueSystem.clearEffect()
```

VNCommands remains thin and focused on routing. It does not parse text effects - that responsibility belongs to DialogueSystem.

---

# DialogueSystem

Handles all dialogue and narration display with integrated text effect support.

**Key Features:**
- Text effect parsing and application
- Effect state management
- Automatic position/color reset
- Optional auto-advance
- Update loop for effect animation

**Architecture:**
- DialogueSystem handles its own text effect parsing (proper separation of concerns)
- TextEffectSystem provides the effect animation logic
- VNCommands simply routes to DialogueSystem

**Integration:**
VNState must call `DialogueSystem.update(elapsed)` in its update loop for effects to animate.

---

# TextEffectSystem

Pure effect logic and animation system. Handles:
- Shake animation (random jitter)
- Glitch animation (position jumps + color corruption)
- Wave animation (sine wave motion)
- Rainbow animation (color cycling)
- Fade animation (alpha pulsing)
- Typewriter animation (character reveal)

This system is stateless and reusable. All state is managed by DialogueSystem.

---

# BackgroundSystem

Handles loading, scaling, and transitioning between backgrounds.
Uses a FlxSpriteGroup stored inside VNState.

Supported transition modes:

* cut (instant)
* fade
* crossfade
* slide_left
* slide_right
* slide_up
* slide_down

Background images are scaled to match the screen resolution using FlxSprite's setGraphicSize.

---

# CharacterSystem

Manages character sprite display with support for:
- Multiple character positions (left, center, right)
- Pose changes
- Character emphasis (DDLC-style)
- Transitions (fade, slide)
- Multi-layer character rendering

Characters are rendered using CharacterRenderer which handles sprite layering and composition.

---

# EffectSystem

Provides screen-level effects:
- **shake**: Camera shake for impact moments
- **flash**: Color flash overlay (white, red, etc.)
- **glitch**: Screen glitch effect (combines shake + flash)

These are separate from text effects and can be combined for dramatic sequences.

---

# VNState

VNState is responsible for managing the layers:

* Background layer (FlxSpriteGroup)
* Character layer (FlxSpriteGroup)
* UI layer (FlxGroup)
* Dialogue box
* Name box
* Mouse visibility

VNState initializes a SceneRunner and begins the scene defined in Main.hx.

---

# Extending the Engine

## Adding a New Node Type

1. Add a case branch in SceneRunner
2. Add handling in VNCommands
3. Implement subsystem behavior

## Adding a New Transition

Modify BackgroundSystem by creating a new method and adding a new switch-case branch.

## Adding a New Text Effect

1. Add new effect type to TextEffectSystem enum
2. Implement effect logic in TextEffectSystem
3. Add parsing case in DialogueSystem.parseTextEffect()

## Expanding CharacterSystem

Character poses, transitions, slots, and multi-layered sprite behavior can be added without affecting SceneRunner or VNCommands.

## Adding Expression Operators

ConditionParser can be expanded with operators such as:

* ==
* !=
* >=
* <=
* and
* or

---

# Runtime Flow

The general runtime process:

1. VNState loads SceneRunner
2. SceneRunner loads scene JSON through SceneParser
3. SceneRunner grabs node "start" and executes it
4. VNCommands dispatches to specific subsystems
5. Subsystems update visuals or gameplay
6. DialogueSystem updates text effects each frame
7. SceneRunner advances to next node
8. Process repeats until an end node
9. SceneManager loads next VN scene or returns to rhythm mode

This structure ensures deterministic control of narrative progression.

---

# Debugging

Checks to perform if the VN shows a black screen:

1. Main.hx must call `VNState.new` instead of `VNState`
2. JSON file must exist at the correct path
3. JSON must contain `"start"` and matching `"id"` nodes
4. VNState must add all groups to the state
5. Background path must be correct and asset must exist
6. VNState must call `DialogueSystem.update(elapsed)` for text effects
7. Browser console (F12) will show:

   * Trace logs from DialogueSystem
   * Background transitions
   * SceneRunner progress
   * Condition evaluations
   * Node traversal
   * Text effect activation

These logs confirm engine behavior even before visual UI is implemented.

---

# Implemented Systems

## Fully Implemented
* **DialogueSystem** - Text display with effect support
* **TextEffectSystem** - 6 text animation effects
* **BackgroundSystem** - Background transitions
* **CharacterSystem** - Character display and posing
* **CharacterRenderer** - Multi-layer sprite rendering
* **EffectSystem** - Screen effects (shake, flash, glitch)
* **SceneParser** - JSON validation and loading
* **SceneRunner** - Node execution state machine
* **VNCommands** - Command routing

## Partially Implemented
* **AudioSystem** - Basic structure (needs implementation)
* **ChoiceSystem** - Basic structure (needs UI)
* **ConditionParser** - Basic structure (needs full expression parsing)

---

# Use Cases for Text Effects

## Horror Scenarios
- **Glitch**: System corruption, reality breaking
- **Shake**: Fear, anxiety, instability
- Combined with screen effects for maximum impact

## Emotional Moments
- **Shake**: Nervousness, trembling
- **Fade**: Weakness, fading consciousness

## Supernatural
- **Wave**: Ghost speech, ethereal voices
- **Fade**: Spectral presence

## Magical Effects
- **Rainbow**: Spells, magical power
- **Wave**: Mystical energy

## Dramatic Reveals
- **Typewriter**: Important messages, computer readouts
- **Glitch**: Corrupted data, broken memories

---

# Roadmap

## Completed
* Text effects system (shake, glitch, wave, rainbow, fade, typewriter)
* Background transition system
* Character display system
* Screen effects (shake, flash, glitch)
* Clean architecture with separation of concerns

## In Progress
* Character rot variants and distressed poses
* Full ConditionParser for rot scoring logic
* Choice UI implementation

## Planned
* Full AudioSystem implementation (crossfades, spatial audio)
* Horror effect enhancements for Act 3 and 4
* Rhythm gameplay integration polish
* Puppeteer mode commands for Act 4 behavior
* Persistent data system to track player choices, rot scores, and flags
* Per-character text effect animations
* Shader-based advanced effects

---

# Performance Notes

The text effects system is highly optimized:
- Lightweight (simple math operations)
- Only active when text is visible
- Automatic cleanup when dialogue changes
- No memory leaks or accumulation
- Minimal CPU overhead