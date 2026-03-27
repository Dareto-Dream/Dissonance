# DISSONANCE — PLANNED FEATURES

Features that are out of scope for the current release but planned for future development.

---

## Act 4: System Override (Critical)

The engine must support temporary rule changes where player control is partially lost.

- Inputs behave differently (reversed, delayed, ignored)
- UI elements distort, flicker, or lie
- Characters act independently, overriding player choices
- Dialogue boxes change style/color to reflect loss of control
- Meta-narrative manipulation (4th wall breaks, engine "glitches")
- All effects must be data-driven via scene nodes, not hardcoded

**Priority:** High — this is a core story mechanic for Act 4.

---

## Real Glitch Shaders

Current glitch effect is a placeholder (screen shake + color flash). Replace with GPU shaders:

- Chromatic aberration
- Scanline distortion
- RGB channel splitting
- Static noise overlay
- CRT-style curvature during intense moments

---

## Animated Idle Sprites (VN Mode)

Characters are currently static frames in VN mode. Add subtle idle animations:

- Breathing (subtle scale oscillation)
- Blinking (periodic frame swap)
- Hair/clothing sway
- Idle fidgeting per character personality

---

## Voice Acting Integration

- Audio clip field per dialogue node (`voice: "assets/voices/tiffany_n42.ogg"`)
- Auto-advance synced to clip duration
- Lip-sync animation triggers (optional)
- Per-character voice volume settings

---

## Custom Fonts Per Character

Different dialogue box styling per speaker:

- Font family per character
- Text color themes
- Dialogue box border/background styles
- Speaker name styling

---

## BPM Changes Mid-Song

Conductor currently assumes constant BPM. For complex musical pieces:

- BPM change events at specific timestamps
- Smooth BPM transitions (accelerando/ritardando)
- Time signature changes
- Multiple BPM sections in chart data

---

## CG Gallery / Extras Menu

Unlockable after completing the game:

- CG art viewer for key story moments
- Music player for unlocked tracks
- Scene replay from any completed scene
- Character profile cards with personality summaries
- Statistics (choices made, rhythm scores, playtime)

---

## Achievements System

Track player accomplishments:

- Story milestones (complete each act)
- Rhythm performance (perfect scores, full combos)
- Hidden achievements for specific choice paths
- "Bad" achievements for negative outcomes
- Display in extras menu

---

## Localization / i18n

- External string tables (JSON per language)
- Dialogue text keys instead of inline strings
- Font fallbacks for non-Latin scripts
- Language selector in options
- RTL text support

---

## Mod Support / Custom Scenes

Allow community-created content:

- External scene loading from user directory
- Custom character definitions
- Custom chart import
- Workshop/sharing integration
- Scene validation tool

---

## Steam / Platform Integration

- Steam achievements
- Cloud save sync
- Rich presence (current act/scene)
- Trading cards / badges
- Controller support with proper button prompts

---

## Accessibility Features

- Colorblind mode (affect UI colors, not art)
- Screen reader support for dialogue text
- Input remapping (keyboard, controller, touch)
- High contrast mode
- Adjustable text size beyond current options
- Audio descriptions for key visual events

---

## Auto-Save on Scene Transitions

- Automatic save to a dedicated auto-save slot when transitioning between scenes
- Configurable in options (on/off)
- Visual indicator when auto-save occurs
- Auto-save slot visible in load menu but distinct from manual saves

---

## Chapter Select Menu

After completing the game once:

- Replay from any act/scene start
- Shows which endings have been reached
- Branching path visualization
- Choice history per playthrough

---

## Dialogue History Search

Enhancement to the existing dialogue history:

- Text search across backlog
- Filter by speaker
- Bookmark important dialogue
- Export conversation log

---

## Advanced Background Effects

- Parallax scrolling backgrounds (multi-layer)
- Animated backgrounds (rain, snow, particle effects)
- Day/night cycle transitions
- Weather system integration with story state

---

## Multiplayer Rhythm Mode

For rhythm game segments:

- Local co-op (split keyboard)
- Online spectator mode
- Score comparison / leaderboards
- Duet mode where both players have lanes
