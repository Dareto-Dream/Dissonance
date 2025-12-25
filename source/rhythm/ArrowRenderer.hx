package rhythm;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxTimer;
import rhythm.JudgementSystem.HitRating;
import rhythm.Note.NoteKind;
import rhythm.Note;

using flixel.util.FlxSpriteUtil;

/**
 * ArrowRenderer
 * =============
 * Visual-only arrow lane renderer.
 *
 * Reacts to gameplay events.
 * Never polls input or time.
 */
class ArrowRenderer extends FlxGroup
{
    private static inline var LANES:Int = 4;

    private var arrows:Array<FlxSprite> = [];

    // ------------------------------------------------------------------
    // Asset configuration (can be injected or overridden)
    // ------------------------------------------------------------------

    /**
     * Path to arrow receptor spritesheet.
     * Expected format: Single PNG with 4 frames (64x64 each)
     * Frame order: [idle, press, hit, miss]
     * 
     * Set this BEFORE calling new() if you need a custom path.
     */
    public static var ARROW_ASSET_PATH:String = "assets/images/ui/arrows/receptor.png";
    
    /**
     * Frame dimensions for arrow sprites.
     */
    public static var ARROW_FRAME_WIDTH:Int = 64;
    public static var ARROW_FRAME_HEIGHT:Int = 64;

    /**
     * Enable debug rendering (colored boxes) if assets fail to load.
     */
    public static var DEBUG_FALLBACK:Bool = false;

    public function new()
    {
        super();

        createArrows();
    }

    // ------------------------------------------------------------------
    // Setup
    // ------------------------------------------------------------------

    private function createArrows():Void
    {
        trace("[ArrowRenderer] Creating ${LANES} arrow receptors");
        trace("[ArrowRenderer] Asset path: ${ARROW_ASSET_PATH}");

        for (i in 0...LANES)
        {
            var arrow = new FlxSprite(100 + i * 150, 600);
            
            // Attempt to load spritesheet
            var loadSuccess = tryLoadArrowAsset(arrow);

            if (loadSuccess)
            {
                // Asset loaded successfully - set up animations
                arrow.animation.add("idle", [0], 0, false);
                arrow.animation.add("press", [1], 0, false);
                arrow.animation.add("hit", [2], 0, false);
                arrow.animation.add("miss", [3], 0, false);
                arrow.animation.play("idle");
                
                trace('[ArrowRenderer] Receptor ${i}: Asset loaded');
            }
            else
            {
                // Asset failed - use debug fallback
                if (DEBUG_FALLBACK)
                {
                    createDebugArrow(arrow, i);
                    trace('[ArrowRenderer] Receptor ${i}: Using debug fallback');
                }
                else
                {
                    trace('[ArrowRenderer] Receptor ${i}: FAILED (no fallback enabled)');
                }
            }

            arrows.push(arrow);
            add(arrow);
        }

        trace("[ArrowRenderer] Setup complete");
    }

    /**
     * Attempt to load arrow asset.
     * Returns true if successful, false if asset missing/invalid.
     */
    private function tryLoadArrowAsset(sprite:FlxSprite):Bool
    {
        try
        {
            sprite.loadGraphic(
                ARROW_ASSET_PATH,
                true,
                ARROW_FRAME_WIDTH,
                ARROW_FRAME_HEIGHT
            );
            
            // Verify we got frames
            return sprite.frames != null && sprite.frames.frames.length >= 4;
        }
        catch (e:Dynamic)
        {
            trace('[ArrowRenderer] Asset load failed: ${e}');
            return false;
        }
    }

    /**
     * Create debug fallback rendering (colored boxes for testing).
     */
    private function createDebugArrow(sprite:FlxSprite, index:Int):Void
    {
        // Create a simple colored square
        sprite.makeGraphic(64, 64, getDebugColor(index));
        
        // Optional: add a border
        sprite.drawRect(0, 0, 64, 64, getDebugColor(index), {thickness: 2, color: 0xFFFFFFFF});
    }

    /**
     * Get debug color for receptor index.
     */
    private function getDebugColor(index:Int):Int
    {
        return switch (index)
        {
            case 0: 0xFFFF0000; // Red (LEFT)
            case 1: 0xFF00FF00; // Green (DOWN)
            case 2: 0xFF0000FF; // Blue (UP)
            case 3: 0xFFFFFF00; // Yellow (RIGHT)
            default: 0xFFFFFFFF; // White
        };
    }

    // ------------------------------------------------------------------
    // Event hooks (called by RhythmState)
    // ------------------------------------------------------------------

    /**
     * Called when a note is spawned.
     * Optional hook if you want receptors to glow early.
     */
    public function spawnNote(note:Note):Void
    {
        // Intentionally empty for now.
        // Future use: pre-glow, anticipation effects.
    }

    /**
     * Called when a note is successfully hit.
     */
    public function onNoteHit(note:Note, rating:HitRating):Void
    {
        // Only render player notes
        if (!note.isPlayerNote()) return;

        var arrow = arrows[note.inputLane];

        // Try animation if available
        if (arrow.animation != null && arrow.animation.exists("hit"))
        {
            arrow.animation.play("hit", true);

            // Return to idle after a short flash
            new FlxTimer().start(0.06, function(t:FlxTimer) {
                if (arrow.animation.exists("idle"))
                    arrow.animation.play("idle");
            });
        }
        else
        {
            // Debug fallback: flash white
            arrow.color = 0xFFFFFFFF;
            new FlxTimer().start(0.06, function(t:FlxTimer) {
                arrow.color = getDebugColor(note.inputLane);
            });
        }
    }

    /**
     * Called when a note is missed.
     */
    public function onNoteMiss(note:Note):Void
    {
        // Only render player notes
        if (!note.isPlayerNote()) return;

        var arrow = arrows[note.inputLane];

        // Try animation if available
        if (arrow.animation != null && arrow.animation.exists("miss"))
        {
            arrow.animation.play("miss", true);

            new FlxTimer().start(0.1, function(t:FlxTimer) {
                if (arrow.animation.exists("idle"))
                    arrow.animation.play("idle");
            });
        }
        else
        {
            // Debug fallback: flash dark
            arrow.color = 0xFF444444;
            new FlxTimer().start(0.1, function(t:FlxTimer) {
                arrow.color = getDebugColor(note.inputLane);
            });
        }
    }

    /**
     * Called when player presses a lane with no valid note.
     */
    public function onGhostTap(lane:Int):Void
    {
        var arrow = arrows[lane];

        // Try animation if available
        if (arrow.animation != null && arrow.animation.exists("press"))
        {
            arrow.animation.play("press", true);

            new FlxTimer().start(0.05, function(t:FlxTimer) {
                if (arrow.animation.exists("idle"))
                    arrow.animation.play("idle");
            });
        }
        else
        {
            // Debug fallback: brief darken
            arrow.color = 0xFFAAAAAA;
            new FlxTimer().start(0.05, function(t:FlxTimer) {
                arrow.color = getDebugColor(lane);
            });
        }
    }
}
