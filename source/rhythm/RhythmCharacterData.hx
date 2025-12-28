package rhythm;

/**
 * RhythmCharacterData
 * ===================
 * Data structure for rhythm character configuration.
 * 
 * Loaded from: assets/data/characters/<charID>/<charID>.json
 * 
 * This is the SINGLE SOURCE OF TRUTH for:
 * - Animation definitions
 * - Sprite configuration
 * - Character positioning
 * - Animation timing
 * 
 * CRITICAL: anim ≠ name
 * - anim = engine animation key (what gameplay code plays)
 * - name = XML frame prefix (what atlas contains)
 */

typedef RhythmCharacterData =
{
    /**
     * Animation definitions.
     * Each animation maps an engine key to XML frames.
     */
    var animations:Array<RhythmAnimationDef>;

    /**
     * Path to sprite image/atlas (without extension).
     * Example: "characters/DADDY_DEAREST"
     * Loader will append .png and .xml
     */
    var image:String;

    /**
     * Base position offset [x, y].
     * Applied when adding character to stage.
     */
    var position:Array<Float>;

    /**
     * Sprite scale multiplier.
     */
    var scale:Float;

    /**
     * Flip sprite horizontally.
     */
    var flip_x:Bool;

    /**
     * How long (in steps/beats) sing animations hold before returning to idle.
     * Used by animation bridge for timing.
     */
    var sing_duration:Float;
}

/**
 * Animation definition.
 * Maps engine animation key to XML frame data.
 */
typedef RhythmAnimationDef =
{
    /**
     * Engine animation key.
     * What gameplay code uses to play animation.
     * Examples: "idle", "singLEFT", "singUP"
     */
    var anim:String;

    /**
     * XML frame prefix.
     * What the Sparrow atlas actually contains.
     * Examples: "Dad Sing Note UP", "BF NOTE LEFT0", "idle"
     * 
     * CRITICAL: This can be DIFFERENT from anim.
     */
    var name:String;

    /**
     * Animation framerate (frames per second).
     */
    var fps:Int;

    /**
     * Whether animation should loop.
     */
    var loop:Bool;

    /**
     * Position offset [x, y] applied when this animation plays.
     * Compensates for sprite anchor/alignment differences per animation.
     */
    var offsets:Array<Float>;

    /**
     * Frame indices to use (optional).
     * If empty/null: use addByPrefix to auto-collect frames
     * If present: use addByIndices with these exact frame numbers
     */
    var indices:Array<Int>;
}
