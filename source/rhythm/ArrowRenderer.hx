package rhythm;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;
import rhythm.JudgementSystem.HitRating;
import rhythm.Note.NoteKind;
import rhythm.Note;

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
    public static var DEBUG_FALLBACK:Bool = true;

    // ------------------------------------------------------------------
    // Layout configuration
    // ------------------------------------------------------------------

    /**
     * Layout mode for receptors.
     * "radial" = circular arrangement around center point
     * "linear" = horizontal line (legacy, not recommended)
     */
    public static var LAYOUT_MODE:String = "radial";

    /**
     * Center X position for radial layout.
     * -1 = auto (screen center)
     */
    public static var LAYOUT_CENTER_X:Float = -1;

    /**
     * Center Y position for radial layout.
     * -1 = auto (screen center with downward bias)
     */
    public static var LAYOUT_CENTER_Y:Float = -1;

    /**
     * Radius from center for radial layout.
     * Tuned for visible note travel time.
     */
    public static var LAYOUT_RADIUS:Float = 150;

    /**
     * Starting angle for radial layout.
     * -Math.PI/2 = top, then clockwise
     */
    public static var LAYOUT_START_ANGLE:Float = -Math.PI / 2;

    /**
     * Downward bias offset for auto-centered layout.
     * Positive = lower on screen
     */
    public static var LAYOUT_CENTER_Y_OFFSET:Float = 50;

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
        trace("[ArrowRenderer] Layout mode: ${LAYOUT_MODE}");
        trace("[ArrowRenderer] Asset path: ${ARROW_ASSET_PATH}");

        // Calculate layout positions
        var positions = calculateReceptorPositions();

        for (i in 0...LANES)
        {
            var pos = positions[i];
            var arrow = new FlxSprite(pos.x, pos.y);
            
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
                
                trace('[ArrowRenderer] Receptor ${i}: Asset loaded at (${pos.x}, ${pos.y})');
            }
            else
            {
                // Asset failed - use debug fallback
                if (DEBUG_FALLBACK)
                {
                    createDebugArrow(arrow, i);
                    trace('[ArrowRenderer] Receptor ${i}: Debug fallback at (${pos.x}, ${pos.y})');
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
     * Calculate receptor positions based on layout mode.
     */
    private function calculateReceptorPositions():Array<{x:Float, y:Float}>
    {
        var positions:Array<{x:Float, y:Float}> = [];

        if (LAYOUT_MODE == "radial")
        {
            // Determine center point
            var centerX = LAYOUT_CENTER_X >= 0 ? LAYOUT_CENTER_X : FlxG.width / 2;
            var centerY = LAYOUT_CENTER_Y >= 0 ? LAYOUT_CENTER_Y : (FlxG.height / 2) + LAYOUT_CENTER_Y_OFFSET;

            trace('[ArrowRenderer] Radial layout: center=(${centerX}, ${centerY}), radius=${LAYOUT_RADIUS}');

            var anglePerLane = (Math.PI * 2) / LANES;

            for (i in 0...LANES)
            {
                var angle = LAYOUT_START_ANGLE + (i * anglePerLane);
                
                // Calculate position on circle
                var x = centerX + Math.cos(angle) * LAYOUT_RADIUS;
                var y = centerY + Math.sin(angle) * LAYOUT_RADIUS;

                // Center the sprite on the calculated point
                x -= ARROW_FRAME_WIDTH / 2;
                y -= ARROW_FRAME_HEIGHT / 2;

                positions.push({x: x, y: y});
            }
        }
        else // Linear fallback
        {
            trace('[ArrowRenderer] Linear layout (legacy)');
            for (i in 0...LANES)
            {
                positions.push({
                    x: 100 + i * 150,
                    y: 600
                });
            }
        }

        return positions;
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
        sprite.makeGraphic(64, 64, getDebugColor(index));

        FlxSpriteUtil.drawRect(
            sprite,
            0, 0,
            64, 64,
            0x00000000,
            { thickness: 2, color: 0xFFFFFFFF }
        );
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

    /**
     * Get the screen position of a receptor by input lane.
     * Returns center point of the receptor sprite.
     */
    public function getReceptorPosition(inputLane:Int):{x:Float, y:Float}
    {
        if (inputLane < 0 || inputLane >= arrows.length)
            return {x: 0, y: 0};

        var arrow = arrows[inputLane];
        return {
            x: arrow.x + (ARROW_FRAME_WIDTH / 2),
            y: arrow.y + (ARROW_FRAME_HEIGHT / 2)
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
        // Only render judged notes (positive lanes that require input)
        if (!note.isJudged) return;  // ✅ FIXED: was note.isPlayerNote()

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
        // Only render judged notes
        if (!note.isJudged) return;  // ✅ FIXED: was note.isPlayerNote()

        var arrow = arrows[note.inputLane];

        // Try animation if available
        if (arrow.animation != null && arrow.animation.exists("miss"))
        {
            arrow.animation.play("miss", true);

            // Return to idle after feedback
            new FlxTimer().start(0.1, function(t:FlxTimer) {
                if (arrow.animation.exists("idle"))
                    arrow.animation.play("idle");
            });
        }
        else
        {
            // Debug fallback: flash red
            arrow.color = 0xFFFF0000;
            new FlxTimer().start(0.1, function(t:FlxTimer) {
                arrow.color = getDebugColor(note.inputLane);
            });
        }
    }

    /**
     * Called on ghost tap (input with no note in window).
     */
    public function onGhostTap(inputLane:Int):Void
    {
        var arrow = arrows[inputLane];

        // Try animation if available
        if (arrow.animation != null && arrow.animation.exists("miss"))
        {
            arrow.animation.play("miss", true);

            // Quick return to idle
            new FlxTimer().start(0.05, function(t:FlxTimer) {
                if (arrow.animation.exists("idle"))
                    arrow.animation.play("idle");
            });
        }
        else
        {
            // Debug fallback: flash dark red
            arrow.color = 0xFF880000;
            new FlxTimer().start(0.05, function(t:FlxTimer) {
                arrow.color = getDebugColor(inputLane);
            });
        }
    }
}
