package rhythm;

/**
 * ChartData
 * =========
 * Typed representation of a Psych-style chart JSON.
 *
 * NEW DESIGN (Post-Refactor):
 * - Sections have `singers` array instead of `playerLaneCount`
 * - No "player vs opponent" concept
 *
 * This file intentionally contains:
 * - NO gameplay logic
 * - NO timing logic
 * - NO expansion logic
 *
 * It is purely a structured data container.
 */
typedef ChartData =
{
    var song:ChartSong;
}

/**
 * Root song object.
 */
typedef ChartSong =
{
    var song:String;
    var bpm:Float;
    var offset:Float;

    var player:String;
    var singers:Array<String>;
    @:optional var stage:String;

    var notes:Array<ChartSection>;
}

/**
 * One chart section.
 *
 * NEW DESIGN:
 * - `singers` array defines who can animate in this section
 * - `mustHitSection` determines if positive lanes are judged
 * - `playerLaneCount` removed (no longer used)
 *
 * Sections are ORGANIZATIONAL, not temporal authorities.
 * Timing always comes from absolute note times.
 */
typedef ChartSection =
{
    var sectionNotes:Array<ChartRawNote>;

    var mustHitSection:Bool;
    var lengthInSteps:Int;
    
    // NEW: Section-level singers array
    var singers:Array<String>;

    // Optional / Psych-style extensions
    @:optional var bpm:Float;
}

/**
 * Raw note entry as it appears in the chart JSON.
 *
 * Format (Psych-style):
 * [ timeMs, lane, holdMs?, noteType? ]
 */
typedef ChartRawNote = Array<Float>;

/**
 * Constants related to chart interpretation.
 *
 * These DO NOT enforce gameplay logic — they only document intent.
 */
class ChartConstants
{
    // noteType values (from your chart examples)
    public static inline var NOTE_NORMAL:Int = 0;
    public static inline var NOTE_SWING:Int  = 1;

    // Safety indices for raw note arrays
    public static inline var IDX_TIME:Int  = 0;
    public static inline var IDX_LANE:Int  = 1;
    public static inline var IDX_HOLD:Int  = 2;
    public static inline var IDX_TYPE:Int  = 3;
}
