package rhythm;

import rhythm.JudgementSystem.HitRating;

/**
 * ScoreTracker
 * ============
 * Accumulates score, combo, health, and accuracy during a rhythm song.
 *
 * Stateful — one instance per song.
 * All values are read-only externally; mutations go through on* methods.
 */
class ScoreTracker
{
    // Score awarded per rating
    public static inline var SCORE_SICK:Int  = 350;
    public static inline var SCORE_GOOD:Int  = 200;
    public static inline var SCORE_BAD:Int   = 50;

    // Health deltas per event (0.0–1.0 scale, starts at 0.5)
    public static inline var HEALTH_SICK:Float   =  0.040;
    public static inline var HEALTH_GOOD:Float   =  0.010;
    public static inline var HEALTH_BAD:Float    = -0.030;
    public static inline var HEALTH_MISS:Float   = -0.070;
    public static inline var HEALTH_GHOST:Float  = -0.040;

    // Live state
    public var score:Int       = 0;
    public var combo:Int       = 0;
    public var maxCombo:Int    = 0;
    public var health:Float    = 0.5;

    // Rating counters
    public var sickCount:Int   = 0;
    public var goodCount:Int   = 0;
    public var badCount:Int    = 0;
    public var missCount:Int   = 0;
    public var totalJudged:Int = 0;

    // Last rating (for HUD flash)
    public var lastRating:HitRating = MISS;

    public function new() {}

    /**
     * Call when the player successfully hits a judged note.
     */
    public function onNoteHit(rating:HitRating):Void
    {
        lastRating = rating;
        totalJudged++;

        switch (rating)
        {
            case SICK:
                score += SCORE_SICK + (combo * 2);
                health  = Math.min(1.0, health + HEALTH_SICK);
                combo++;
                sickCount++;

            case GOOD:
                score += SCORE_GOOD + combo;
                health  = Math.min(1.0, health + HEALTH_GOOD);
                combo++;
                goodCount++;

            case BAD:
                score += SCORE_BAD;
                health  = Math.max(0.0, health + HEALTH_BAD);
                combo   = 0;
                badCount++;

            case MISS:
                // Judge returned MISS — treat same as onNoteMiss
                health  = Math.max(0.0, health + HEALTH_MISS);
                combo   = 0;
                missCount++;
        }

        if (combo > maxCombo) maxCombo = combo;
    }

    /**
     * Call when a judged note passes its window without being hit.
     */
    public function onNoteMiss():Void
    {
        lastRating  = MISS;
        totalJudged++;
        health      = Math.max(0.0, health + HEALTH_MISS);
        combo       = 0;
        missCount++;
    }

    /**
     * Call on ghost tap (input with no note in window).
     * Does not count as a judged note.
     */
    public function onGhostTap():Void
    {
        health = Math.max(0.0, health + HEALTH_GHOST);
        combo  = 0;
    }

    /**
     * Weighted accuracy: SICK=100%, GOOD=75%, BAD=25%, MISS=0%.
     * Returns 1.0 if no notes have been judged yet.
     */
    public function getAccuracy():Float
    {
        if (totalJudged == 0) return 1.0;
        return (sickCount * 1.0 + goodCount * 0.75 + badCount * 0.25) / totalJudged;
    }

    /**
     * True when health has hit zero — triggers song failure.
     */
    public inline function isDead():Bool
    {
        return health <= 0.0;
    }
}
