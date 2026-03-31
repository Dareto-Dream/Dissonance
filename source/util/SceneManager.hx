package util;

import core.state.SaveSystem;
import flixel.FlxG;
import states.VNState;

class SceneManager {
    public static function loadScene(path:String):Void {
		SaveSystem.autoSave();
		FlxG.switchState(() -> new VNState(path));
    }
}
