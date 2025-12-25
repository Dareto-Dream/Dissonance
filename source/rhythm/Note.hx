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
 * NoteOwner
 * =========
 * Who this note belongs to / is controlled by.
 * Future-proofing: puppeteer mode and duets can route notes by owner.
 */
enum NoteOwner
{
    PLAYER;
    OPPONENT;
}

/**
 * Note
 * ====
 * Runtime note instance (already expanded, absolute timestamp in ms).
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

    // Lane/column (0..N-1)
    public var lane:Int;

    // Role of this note slice
    public var kind:NoteKind;

    // Who should play this note
    public var owner:NoteOwner;

    // Note style/type metadata (does NOT change core logic)
    public var isSwing:Bool;

    // One-shot guard
    public var judged:Bool = false;

    // ------------------------------------------------------------------
    // DECODED FIELDS (set by ChartHandler during note expansion)
    // ------------------------------------------------------------------
    // These are the CANONICAL fields for all gameplay logic.
    // Raw 'lane' should ONLY be used for debugging/logging.

    // Player input routing (only valid if owner == PLAYER)
    // -1 if this is an NPC note
    // 0..playerLaneCount-1 if this is a player note
    public var inputLane:Int = -1;

    // Animation lane (ALWAYS 0..3 for both player and NPC)
    // Used for directional animation selection
    public var animLane:Int = 0;

    // NPC singer index (only valid if owner == OPPONENT)
    // -1 if this is a player note
    // 0, 1, 2... for NPC0, NPC1, NPC2... in duets/trios
    public var singerIndex:Int = -1;

    // Useful metadata for events/debug
    public var chartIndex:Int = -1;     // optional: original ordering index
    public var sectionIndex:Int = -1;   // optional: which chart section it came from

    public function new(
        timeMs:Float,
        lane:Int,
        kind:NoteKind,
        owner:NoteOwner,
        isSwing:Bool = false
    )
    {
        this.timeMs = timeMs;
        this.lane = lane;
        this.kind = kind;
        this.owner = owner;
        this.isSwing = isSwing;
    }

    // ------------------------------------------------------------------
    // Convenience helpers
    // ------------------------------------------------------------------

    public inline function isHold():Bool
    {
        return kind == HOLD_HEAD || kind == HOLD_TICK || kind == HOLD_TAIL;
    }

    public inline function isPlayerNote():Bool
    {
        return owner == PLAYER;
    }

    public inline function isOpponentNote():Bool
    {
        return owner == OPPONENT;
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
