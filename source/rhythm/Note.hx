package rhythm;

/**
 * NoteKind
 * ========
 * Runtime note roles. These are produced by ChartHandler (chart expansion)
 * and consumed by NoteHandler (spawn/judge/miss).
 *
 * Design rule:
 * - Every note is judged at most once, then removed from gameplay.
 */
enum NoteKind
{
    TAP;        // Normal note
    HOLD_HEAD;  // Hold start (press)
    HOLD_TICK;  // Optional sustain segment (usually per step)
    HOLD_TAIL;  // Hold end (release)
}

/**
 * Note
 * ====
 * Runtime note instance (already expanded, absolute timestamp in ms).
 *
 * NEW DESIGN (Post-Refactor):
 * - Notes drive PERFORMANCE (animation) and optionally JUDGEMENT
 * - No "player vs opponent" concept
 * - Notes have a performer (character ID) and optional judgement requirement
 *
 * The chart itself may store holds as a single entry (time + length),
 * but the engine never sees length here. It only sees NoteKind slices.
 *
 * This keeps judgement and lifecycle deterministic and simple.
 */
class Note
{
    // Absolute time in milliseconds (authoritative)
    public var timeMs:Float;

    // Raw lane from chart (for debugging/logging only)
    // Do NOT use this for gameplay logic - use decoded fields below
    public var lane:Int;

    // Role of this note slice
    public var kind:NoteKind;

    // Note style/type metadata (does NOT change core logic)
    public var isSwing:Bool;

    // One-shot guard
    public var judged:Bool = false;

    // ------------------------------------------------------------------
    // DECODED FIELDS (set by ChartHandler during note expansion)
    // ------------------------------------------------------------------
    // These are the CANONICAL fields for all gameplay logic.
    
    /**
     * Should this note be judged for player input?
     * 
     * TRUE if:
     * - mustHitSection == true
     * - lane >= 0
     * 
     * FALSE otherwise
     */
    public var isJudged:Bool = false;
    
    /**
     * Character ID who performs this note.
     * Resolved from section's singers array during chart expansion.
     * 
     * Example: "hanami", "tiffany", "laura"
     */
    public var characterID:String = "";
    
    /**
     * Index into section's singers array.
     * Used for performer resolution during chart expansion.
     * 
     * Positive lanes: index from start (0, 1, 2...)
     * Negative lanes: index from end (length-1, length-2...)
     */
    public var performerIndex:Int = -1;
    
    /**
     * Animation direction (0-3).
     * 
     * Resolved as: abs(lane) % 4
     * 
     * Maps to:
     * 0 = LEFT
     * 1 = DOWN
     * 2 = UP
     * 3 = RIGHT
     */
    public var animDirection:Int = 0;
    
    /**
     * Player input lane (0-3) if this note is judged.
     * -1 if animation-only.
     * 
     * For judged notes: same as raw lane
     * For animation-only: always -1
     */
    public var inputLane:Int = -1;

    // Useful metadata for events/debug
    public var chartIndex:Int = -1;     // optional: original ordering index
    public var sectionIndex:Int = -1;   // optional: which chart section it came from

    public function new(
        timeMs:Float,
        lane:Int,
        kind:NoteKind,
        isSwing:Bool = false
    )
    {
        this.timeMs = timeMs;
        this.lane = lane;
        this.kind = kind;
        this.isSwing = isSwing;
    }

    // ------------------------------------------------------------------
    // Convenience helpers
    // ------------------------------------------------------------------

    public inline function isHold():Bool
    {
        return kind == HOLD_HEAD || kind == HOLD_TICK || kind == HOLD_TAIL;
    }

    /**
     * Priority used for deterministic sorting when multiple notes share
     * the same timestamp.
     *
     * We want holds to behave nicely:
     * - HEAD before TAP (so presses register cleanly)
     * - TICK after TAP (doesn't steal hits)
     * - TAIL last (release judgement comes after everything else)
     */
    public inline function sortPriority():Int
    {
        return switch (kind)
        {
            case HOLD_HEAD: 0;
            case TAP: 1;
            case HOLD_TICK: 2;
            case HOLD_TAIL: 3;
        }
    }
}
