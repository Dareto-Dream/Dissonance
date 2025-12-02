package util;

import flixel.FlxG;
import states.VNState;

class SceneManager {
    public static function loadScene(path:String):Void {
        trace("LOAD SCENE: " + path);
        FlxG.switchState(VNState.new);
    }
}
