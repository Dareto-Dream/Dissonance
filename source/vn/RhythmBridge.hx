package vn;

import core.rendering.CharacterSystem;
import flixel.FlxG;
import rhythm.RhythmState;

/**
 * RhythmBridge
 * ============
 * VN → Rhythm game integration layer.
 *
 * This class is the ONLY place where the VN system
 * is allowed to start a rhythm game.
 *
 * Responsibilities:
 * - Build chart paths
 * - Inject runtime data into RhythmState
 * - Switch game state
 * - Receive completion callback
 *
 * RhythmState itself remains reusable and decoupled.
 */
typedef RhythmResult = {
    score:Int,
    combo:Int,
    accuracy:Float,
    health:Float,
    completed:Bool
}

class RhythmBridge
{
    /**
     * Start a rhythm game session.
     *
     * @param song   Song identifier (used for chart + audio lookup)
     * @param done   Callback invoked when rhythm game finishes
     */
    public static function start(
        song:String,
        done:RhythmResult->Void
    ):Void
    {
        trace("[RhythmBridge] START RHYTHM: " + song);

        // --------------------------------------------------
        // Resolve paths
        // --------------------------------------------------

        var chartPath = 'assets/data/charts/${song}.json';

        // --------------------------------------------------
        // Create rhythm state (NO constructor args)
        // --------------------------------------------------

        var rhythmState = new RhythmState();

        // Inject required runtime data
        rhythmState.song = song;
        rhythmState.chartPath = chartPath;

        // Inject completion callback (optional)
        rhythmState.onComplete = done;

        // --------------------------------------------------
        // Switch state
        // --------------------------------------------------

        FlxG.switchState(() -> rhythmState);
    }
}
