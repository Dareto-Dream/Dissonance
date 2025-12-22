package rhythm;

/**
 * JudgementSystem - Hit timing evaluation
 * 
 * This class judges how accurately a note was hit.
 * It's pure math with no side effects.
 * 
 * Timing windows (in seconds):
 * - PERFECT: ±0.045s (45ms)
 * - GREAT: ±0.090s (90ms)
 * - GOOD: ±0.135s (135ms)
 * - BAD: ±0.180s (180ms)
 * - MISS: Beyond BAD window
 * 
 * Usage:
 *   var rating = judgement.judge(hitTime - targetTime);
 *   if (rating != MISS) {
 *       // Player hit the note
 *   }
 */

/**
 * Hit rating enum
 * Represents how accurate a hit was
 */
enum HitRating {
    PERFECT;
    GREAT;
    GOOD;
    BAD;
    MISS;
}

class JudgementSystem {
    // Timing windows in seconds
    public var perfectWindow:Float = 0.045;   // 45ms
    public var greatWindow:Float = 0.090;      // 90ms
    public var goodWindow:Float = 0.135;       // 135ms
    public var badWindow:Float = 0.180;        // 180ms
    
    /**
     * Constructor with optional custom windows
     */
    public function new(?perfectMs:Float, ?greatMs:Float, ?goodMs:Float, ?badMs:Float) {
        if (perfectMs != null) this.perfectWindow = perfectMs / 1000;
        if (greatMs != null) this.greatWindow = greatMs / 1000;
        if (goodMs != null) this.goodWindow = goodMs / 1000;
        if (badMs != null) this.badWindow = badMs / 1000;
    }
    
    /**
     * Judge a hit based on timing difference
     * 
     * @param timeDifference Hit time - target time (in seconds)
     * @return Rating enum
     */
    public function judge(timeDifference:Float):HitRating {
        var absDiff = Math.abs(timeDifference);
        
        if (absDiff <= perfectWindow) return PERFECT;
        if (absDiff <= greatWindow) return GREAT;
        if (absDiff <= goodWindow) return GOOD;
        if (absDiff <= badWindow) return BAD;
        return MISS;
    }
    
    /**
     * Get the hit window (BAD threshold)
     * Used for determining if a note is still hittable
     */
    public function getHitWindow():Float {
        return badWindow;
    }
    
    /**
     * Convert timing to normalized accuracy (0.0 to 1.0)
     * 1.0 = perfect, 0.0 = edge of BAD window
     */
    public function getAccuracy(timeDifference:Float):Float {
        var absDiff = Math.abs(timeDifference);
        return Math.max(0, 1 - (absDiff / badWindow));
    }
    
    /**
     * Get score value for a rating
     * Useful for combo systems
     */
    public function getScoreForRating(rating:HitRating):Int {
        return switch (rating) {
            case PERFECT: 350;
            case GREAT: 200;
            case GOOD: 100;
            case BAD: 50;
            case MISS: 0;
        }
    }
}