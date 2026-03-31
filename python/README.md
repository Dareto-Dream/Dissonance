# Dissonance Visual Novel Editor

Legacy Python/Pygame editor for Dissonance. The primary supported workflow is now the built-in desktop editor opened from the game title screen with `7` or the `EDITOR` menu entry.

Use this directory as reference material while porting or comparing behavior. It is no longer the main authoring path.

## Features

### Story Editor
- Visual node-based scene graph editor
- Support for all engine node types (dialogue, narration, action, choice, conditional, jump, game, end)
- Interactive drag-and-drop node placement
- Bezier curve connections between nodes
- Pan and zoom canvas navigation
- Export to JSON scene files
- Keyboard shortcuts for rapid workflow

### Pose Editor
- Character pose composition interface
- Layer-based sprite assembly
- Real-time preview
- XML atlas integration

### XML Tools
- **XML Viewer**: Browse and preview texture atlas contents
- **XML Creator**: Generate texture atlases from sprite folders

### Text Effects Preview
- Live preview of all text effects:
  - Shake (nervousness, fear)
  - Glitch (corruption, horror)
  - Wave (ethereal, magical)
  - Rainbow (celebration, magic)
  - Fade (mysterious, weak)
  - Typewriter (dramatic reveals)

### Scene Placement
- Visual character and background positioning
- Preview final scene composition
- Export position metadata

### Condition Editor
- Visual conditional expression builder
- Support for rot score logic
- Flag management

## Installation

### Requirements
```bash
pip install pygame --break-system-packages
```

### Project Structure
```
~/python/
├── main.py                  # Main entry point
└── modules/
    ├── ui/
    │   ├── theme.py         # Color theme configuration
    │   └── sidebar.py       # Sidebar navigation
    ├── story/
    │   └── story_editor.py  # Story editor module
    ├── pose/
    │   └── pose_editor.py   # Pose editor module
    ├── xml/
    │   ├── xml_viewer.py    # XML viewer module
    │   └── xml_creator.py   # XML creator module
    ├── effects/
    │   └── text_effects.py  # Text effects preview
    ├── placement/
    │   └── scene_placement.py
    ├── conditions/
    │   └── condition_editor.py
    └── utils/
        └── (utilities)
```

## Usage

### Starting the Editor
```bash
cd ~/python
python3 main.py
```

### Story Editor Controls

#### Mouse Controls
- **Left Click**: Select node
- **Left Drag**: Move node
- **Middle Mouse/Drag**: Pan canvas
- **Right Click**: Add new node at cursor
- **Scroll Wheel**: Zoom in/out

#### Keyboard Shortcuts
- `G` - Toggle grid
- `I` - Toggle node IDs
- `F` - Frame all nodes
- `Ctrl+S` - Save scene
- `Ctrl+N` - Add new node
- `Ctrl+L` - Load scene
- `Delete` - Delete selected node

### Node Types

#### Dialogue Node
```json
{
  "id": "n1",
  "type": "dialogue",
  "speaker": "Tiffany",
  "character": "tiffany",
  "pose": "default_smile",
  "text": "Welcome!",
  "text_effect": "wave",
  "next": "n2"
}
```

#### Narration Node
```json
{
  "id": "n2",
  "type": "narration",
  "text": "The bell rings.",
  "next": "n3"
}
```

#### Action Node
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

#### Choice Node
```json
{
  "id": "n4",
  "type": "choice",
  "choices": [
    {"text": "Option A", "target": "n5a"},
    {"text": "Option B", "target": "n5b"}
  ]
}
```

#### Conditional Node
```json
{
  "id": "n6",
  "type": "if",
  "condition": "tiffany_rot <= 2",
  "trueNode": "n7a",
  "falseNode": "n7b"
}
```

## Supported Actions

### Background Actions
- `set_bg` - Change background with transitions (fade, crossfade, slide_left, slide_right, slide_up, slide_down, cut)

### Character Actions
- `show_character` - Display character sprite with pose
- `hide_character` - Remove character from scene

### Effect Actions
- `shake_screen` - Screen shake effect
- `flash` - Screen flash effect
- `glitch` - Screen glitch effect
- `set_text_effect` - Apply persistent text effect
- `clear_text_effect` - Clear persistent text effect

### Audio Actions
- `play_sound` - Play sound effect
- `play_music` - Play music track

## Text Effects

### Available Effects
- **shake**: Random jitter (intensity parameter)
- **glitch**: Position jumps + color corruption (intensity parameter)
- **wave**: Sine wave motion (speed, amplitude parameters)
- **rainbow**: Color cycling (speed parameter)
- **fade**: Alpha pulsing (speed parameter)
- **typewriter**: Character-by-character reveal (speed parameter)

### Example Usage
```json
{
  "type": "dialogue",
  "speaker": "???",
  "text": "Everything is breaking...",
  "text_effect": "glitch",
  "effect_intensity": 8.0,
  "next": "next_node"
}
```

## Export

All modules support exporting to `/mnt/user-data/outputs/` for easy download and integration into your Haxe project.

### Export Formats
- **Story Editor**: JSON scene files
- **Pose Editor**: JSON pose metadata
- **XML Creator**: PNG atlas + XML metadata
- **Scene Placement**: JSON position data

## Extending the Editor

### Adding a New Module

1. Create module file in `modules/yourmodule/your_module.py`
2. Implement the required interface:
```python
class YourModule:
    def __init__(self, workspace_rect, theme, project_root):
        pass
    
    def handle_event(self, event):
        pass
    
    def update(self, dt):
        pass
    
    def draw(self, surface):
        pass
    
    def cleanup(self):
        pass
```

3. Add to `main.py` imports and module dictionary
4. Add case in `switch_module()` method

### Customizing Theme

Edit `modules/ui/theme.py` to customize colors:
```python
self.accent_blue = (80, 140, 255)
self.node_dialogue = (80, 140, 200)
```

## Tips and Best Practices

### Story Editor
- Use descriptive node IDs for better organization
- Keep scene files focused (one scene per file)
- Use the grid to align nodes cleanly
- Frame all nodes (F key) to see entire graph
- Export frequently to avoid data loss

### Node Naming Convention
```
n1, n2, n3    # Linear progression
n4a, n4b      # Choice branches
n5_end        # Scene endings
```

### Text Effects
- Use shake for anxiety, earthquakes
- Use glitch for system corruption, horror
- Use wave for ghosts, ethereal speech
- Use fade for weakness, mysterious
- Use rainbow for magical effects
- Use typewriter for dramatic reveals

## Troubleshooting

### Editor won't start
- Ensure pygame is installed: `pip install pygame --break-system-packages`
- Check Python version: Requires Python 3.8+

### Can't see nodes
- Press `F` to frame all nodes
- Check zoom level (should be 0.3x - 2.0x)
- Verify nodes exist in scene data

### Export fails
- Ensure `/mnt/user-data/outputs/` exists
- Check file permissions
- Verify scene has valid data

## Development Status

### Completed ✅
- Main editor framework
- Sidebar navigation
- Story editor with full node graph
- Module switching system
- Theme system

### In Progress 🚧
- Pose editor implementation
- XML tools functionality
- Text effects live preview
- Scene placement tools
- Condition builder UI

### Planned 📋
- Undo/redo system
- File browser integration
- Copy/paste nodes
- Multi-select operations
- Node templates
- Script validation
- Asset browser
- Character database integration

## License

Part of the Dissonance Visual Novel project.

## Credits

Created for the Dissonance Engine (HaxeFlixel 2025)
Editor built with Python/Pygame
