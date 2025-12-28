package rhythm;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import rhythm.ArrowRenderer;
import rhythm.Conductor;
import rhythm.Note;

/**
 * NoteRenderer
 * ============
 * Visual-only note renderer.
 * 
 * Handles:
 * - Note sprite creation
 * - Radial inward motion toward receptors
 * - Time-based positioning
 * - Asset loading with debug fallback
 * 
 * Does NOT handle:
 * - Hit detection (NoteHandler)
 * - Timing logic (Conductor)
 */
class NoteRenderer extends FlxGroup
{
    // ------------------------------------------------------------------
    // Asset configuration
    // ------------------------------------------------------------------

    /**
     * Path to note sprite asset.
     * Expected format: Single PNG or spritesheet
     * 
     * Current expectation: 32x32 colored note graphic
     */
    public static var NOTE_ASSET_PATH:String = "assets/images/ui/arrows/note.png";

    /**
     * Note sprite dimensions.
     */
    public static var NOTE_WIDTH:Int = 32;
    public static var NOTE_HEIGHT:Int = 32;

    /**
     * Enable debug rendering (colored boxes) if assets fail to load.
     */
    public static var DEBUG_FALLBACK:Bool = true;

    // ------------------------------------------------------------------
    // Spawn configuration
    // ------------------------------------------------------------------

    /**
     * How far ahead (in milliseconds) to spawn notes.
     * Notes appear at edge and travel inward.
     */
    public static var SPAWN_AHEAD_MS:Float = 2000;

    /**
     * Spawn distance from center (radius where notes appear).
     * Should be larger than receptor radius for visible travel.
     */
    public static var SPAWN_RADIUS:Float = 400;

    // ------------------------------------------------------------------
    // Dependencies
    // ------------------------------------------------------------------

    private var conductor:Conductor;
    private var arrowRenderer:ArrowRenderer;

    // Active note sprites (mapped by Note instance)
    private var activeNotes:Map<Note, FlxSprite> = [];

    public function new(conductor:Conductor, arrowRenderer:ArrowRenderer)
    {
        super();

        this.conductor = conductor;
        this.arrowRenderer = arrowRenderer;

        trace("[NoteRenderer] Initialized");
        trace("[NoteRenderer] Asset path: ${NOTE_ASSET_PATH}");
        trace("[NoteRenderer] Spawn ahead: ${SPAWN_AHEAD_MS}ms at radius ${SPAWN_RADIUS}");
    }

    // ------------------------------------------------------------------
    // Note lifecycle
    // ------------------------------------------------------------------

    /**
     * Spawn a note visually.
     * Called by RhythmState when NoteHandler dispatches onNoteSpawn.
     */
    public function spawnNote(note:Note):Void
    {
        // Only render player notes (NPC notes handled by character renderer)
        if (!note.isPlayerNote()) return;

        var sprite = new FlxSprite();

        // Attempt to load note asset
        var loadSuccess = tryLoadNoteAsset(sprite);

        if (!loadSuccess && DEBUG_FALLBACK)
        {
            createDebugNote(sprite, note);
        }

        activeNotes.set(note, sprite);
        add(sprite);

        trace('[NoteRenderer] Spawned note: lane=${note.inputLane}, time=${note.timeMs}');
    }

    /**
     * Remove a note visual.
     * Called when note is hit, missed, or otherwise consumed.
     */
    public function removeNote(note:Note):Void
    {
        if (!activeNotes.exists(note)) return;

        var sprite = activeNotes.get(note);
        activeNotes.remove(note);
        remove(sprite);
        sprite.destroy();
    }

    // ------------------------------------------------------------------
    // Update loop
    // ------------------------------------------------------------------

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        var nowMs = conductor.songPositionMs;

        // Update positions for all active notes
        for (note => sprite in activeNotes)
        {
            updateNotePosition(note, sprite, nowMs);
        }
    }

    /**
     * Update note position based on time-to-hit.
     * Notes travel radially inward from spawn radius toward receptor.
     */
    private function updateNotePosition(note:Note, sprite:FlxSprite, nowMs:Float):Void
    {
        var timeUntilHit = note.timeMs - nowMs;

        // Calculate progress (1.0 = just spawned, 0.0 = at receptor)
        var progress = timeUntilHit / SPAWN_AHEAD_MS;
        progress = Math.max(0, Math.min(1, progress)); // Clamp 0-1

        // Get receptor target position
        var receptorPos = arrowRenderer.getReceptorPosition(note.inputLane);

        // Calculate spawn position (same angle as receptor, but at spawn radius)
        var centerX = ArrowRenderer.LAYOUT_CENTER_X >= 0 
            ? ArrowRenderer.LAYOUT_CENTER_X 
            : flixel.FlxG.width / 2;
        var centerY = ArrowRenderer.LAYOUT_CENTER_Y >= 0 
            ? ArrowRenderer.LAYOUT_CENTER_Y 
            : (flixel.FlxG.height / 2) + ArrowRenderer.LAYOUT_CENTER_Y_OFFSET;

        // Calculate angle for this lane
        var anglePerLane = (Math.PI * 2) / 4; // 4 lanes for now
        var angle = ArrowRenderer.LAYOUT_START_ANGLE + (note.inputLane * anglePerLane);

        // Spawn position (outer radius)
        var spawnX = centerX + Math.cos(angle) * SPAWN_RADIUS;
        var spawnY = centerY + Math.sin(angle) * SPAWN_RADIUS;

        // Interpolate from spawn position to receptor position
        var currentX = spawnX + (receptorPos.x - spawnX) * (1 - progress);
        var currentY = spawnY + (receptorPos.y - spawnY) * (1 - progress);

        // Center sprite on calculated position
        sprite.x = currentX - (NOTE_WIDTH / 2);
        sprite.y = currentY - (NOTE_HEIGHT / 2);
    }

    // ------------------------------------------------------------------
    // Asset loading
    // ------------------------------------------------------------------

    /**
     * Attempt to load note asset.
     * Returns true if successful, false if asset missing/invalid.
     */
    private function tryLoadNoteAsset(sprite:FlxSprite):Bool
    {
        try
        {
            sprite.loadGraphic(NOTE_ASSET_PATH, false, NOTE_WIDTH, NOTE_HEIGHT);
            return sprite.frames != null;
        }
        catch (e:Dynamic)
        {
            trace('[NoteRenderer] Asset load failed: ${e}');
            return false;
        }
    }

    /**
     * Create debug fallback rendering (colored box for testing).
     */
    private function createDebugNote(sprite:FlxSprite, note:Note):Void
    {
        // Use same color scheme as ArrowRenderer for lane consistency
        var color = switch (note.inputLane)
        {
            case 0: 0xFFFF0000; // Red
            case 1: 0xFF00FF00; // Green
            case 2: 0xFF0000FF; // Blue
            case 3: 0xFFFFFF00; // Yellow
            default: 0xFFFFFFFF; // White
        };

        sprite.makeGraphic(NOTE_WIDTH, NOTE_HEIGHT, color);
    }
}
