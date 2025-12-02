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
│   ├── DialogueSystem.hx       Stub for dialogue UI
│   ├── BackgroundSystem.hx     Background transitions
│   ├── CharacterSystem.hx      Stub for character poses and rendering
│   ├── EffectSystem.hx         Stub for screen effects
│   ├── AudioSystem.hx          Stub for sound and music
│   ├── ChoiceSystem.hx         Stub for choice UI
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
  "next": "n2"
}
```

### 2. Narration

```json
{
  "id": "n2",
  "type": "narration",
  "text": "The room falls quiet.",
  "next": "n3"
}
```

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

Supported transitions:

* cut
* fade
* crossfade
* slide_left
* slide_right
* slide_up
* slide_down

Additional transitions can be implemented in BackgroundSystem.

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
```

SceneRunner remains highly simplified because VNCommands handles all execution logic outside of follow-up node selection.

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

# VNState

VNState is responsible for managing the layers:

* Background layer (FlxSpriteGroup)
* Character layer (FlxSpriteGroup)
* UI layer (to be implemented)
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

## Expanding CharacterSystem

Character poses, transitions, slots, and multi-layered sprite behavior can be added without affecting SceneRunner or VNCommands.

## Adding Expression Operators

ConditionParser can be expanded with operators such as:

* ==
* !=
* > =
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
6. SceneRunner advances to next node
7. Process repeats until an end node
8. SceneManager loads next VN scene or returns to rhythm mode

This structure ensures deterministic control of narrative progression.

---

# Debugging

Checks to perform if the VN shows a black screen:

1. Main.hx must call `VNState.new` instead of `VNState`
2. JSON file must exist at the correct path
3. JSON must contain `"start"` and matching `"id"` nodes
4. VNState must add all groups to the state
5. Background path must be correct and asset must exist
6. Browser console (F12) will show:

   * Trace logs from DialogueSystem
   * Background transitions
   * SceneRunner progress
   * Condition evaluations
   * Node traversal

These logs confirm engine behavior even before visual UI is implemented.

---

# Current Missing Systems

These systems currently exist as stubs and will be implemented later:

* DialogueSystem (textbox, namebox, typewriter)
* CharacterSystem (poses, layers, transitions)
* ChoiceSystem (UI for decisions)
* EffectSystem (camera shake, glitch effects, color overlays)
* AudioSystem (sound effects, music crossfades)
* ConditionParser (full expression evaluation)

The engine is already functional but still in a state where UI features and character rendering need to be implemented.

---

# Roadmap

* Implement CharacterSystem with neutral, speaking, distressed, and rot variants
* Build a full DialogueSystem with typewriter and VN UI skin
* Add a robust ConditionParser for rot scoring logic
* Implement horror effects for Act 3 and 4
* Integrate rhythm gameplay transitions
* Add puppeteer mode commands for Act 4 behavior
* Add persistent data system to track player choices, rot scores, and flags