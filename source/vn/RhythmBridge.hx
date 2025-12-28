package vn;

import core.rendering.CharacterSystem;
import flixel.FlxG;
import flixel.FlxState;
import Type;
import rhythm.RhythmCompletionBridge;
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
     * @param vnState  VN state to return to after rhythm completes (a NEW instance will be built)
     * @param done   Callback invoked when rhythm game finishes (called AFTER returning to VN)
     */
    public static function start(
        song:String,
        vnState:FlxState,
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
        
        // CRITICAL: Always rebuild VN state when returning
        // Reusing the old instance is invalid because FlxG destroys it during the switch
        var vnStateClass = Type.getClass(vnState);
        rhythmState.returnStateFactory = () -> {
            var nextState = Type.createInstance(vnStateClass, []);
            if (nextState == null)
            {
                trace('[RhythmBridge] ERROR: returnStateFactory produced null');
            }
            return nextState;
        };

        // Inject completion callback (optional)
        // IMPORTANT: This will be called AFTER returning to VN state
        rhythmState.onComplete = done;

        // --------------------------------------------------
        // Switch state
        // --------------------------------------------------

        FlxG.switchState(() -> rhythmState);
    }
}
