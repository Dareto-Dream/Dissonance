package vn;

import flixel.FlxG;
import rhythm.RhythmState;
import core.rendering.CharacterSystem;

/**
 * RhythmBridge - VN to Rhythm integration
 * 
 * This is the interface between the VN engine and the rhythm game.
 * When a VN scene reaches a "game" node, it calls RhythmBridge.start().
 * 
 * The rhythm game plays, then calls done() when complete.
 * Control returns to the VN with results.
 * 
 * Usage (from VNCommands):
 *   RhythmBridge.start("song_name", characterSystem, (result) -> {
 *       trace('Score: ${result.score}');
 *       sceneRunner.advance(); // Continue VN
 *   });
 */

typedef RhythmResult = {
    score:Int,
    combo:Int,
    accuracy:Float,
    health:Float,
    completed:Bool
}

class RhythmBridge {
    /**
     * Start a rhythm game session
     * 
     * @param song Song identifier
     * @param done Callback when song completes
     */
    public static function start(song:String, done:RhythmResult->Void):Void {
        trace("START RHYTHM: " + song);
        
        // Get the character system from VN
        var characterSystem = CharacterSystem.get();
        
        // Build chart path
        var chartPath = 'assets/data/charts/${song}.json';
        
        // Switch to rhythm state
        var rhythmState = new RhythmState(chartPath, characterSystem);
        
        // Store completion callback
        if (done != null) {
            Reflect.setField(rhythmState, "onComplete", done);
        }
        
        FlxG.switchState(rhythmState);
    }
}