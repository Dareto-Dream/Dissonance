package util;

import flixel.FlxG;
import states.VNState;

class SceneManager {
    public static function loadScene(path:String):Void {
		FlxG.switchState(() -> new VNState(path));
    }
}