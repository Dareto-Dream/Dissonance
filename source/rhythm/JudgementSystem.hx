package rhythm;

/**
 * HitRating
 * =========
 * Ordered from best → worst.
 * Order matters for comparisons and UI.
 */
enum HitRating
{
    SICK;   // Perfect / near-perfect
    GOOD;
    BAD;
    MISS;
}

/**
 * JudgementSystem
 * ===============
 * Stateless timing judgement based purely on millisecond offsets.
 *
 * This class MUST remain pure.
 * If you need score, combo, accuracy, etc — that lives elsewhere.
 */
class JudgementSystem
{
    // Timing windows in milliseconds.
    // These are intentionally conservative defaults.
    public var sickWindowMs:Float = 45;
    public var goodWindowMs:Float = 90;
    public var badWindowMs:Float  = 135;

    public function new() {}

    /**
     * Returns the worst allowed hit window.
     * Used by NoteHandler for spawn/miss logic.
     */
    public inline function maxHitWindowMs():Float
    {
        return badWindowMs;
    }

    /**
     * Judge a hit based on time difference.
     *
     * @param deltaMs
     *   hitTimeMs - noteTimeMs
     *
     * Positive = late
     * Negative = early
     */
    public function judge(deltaMs:Float):HitRating
    {
        var abs = Math.abs(deltaMs);

        if (abs <= sickWindowMs) return SICK;
        if (abs <= goodWindowMs) return GOOD;
        if (abs <= badWindowMs)  return BAD;

        return MISS;
    }

    /**
     * Convenience helper for release judgement (tails).
     * Semantically identical, but kept separate for clarity.
     */
    public inline function judgeRelease(deltaMs:Float):HitRating
    {
        return judge(deltaMs);
    }
}
