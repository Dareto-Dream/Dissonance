package vn;

class CharacterSystem {
    public static function show(node:Dynamic):Void {
        trace("SHOW CHARACTER: " + node.character);
    }

    public static function hide(charId:String):Void {
        trace("HIDE CHARACTER: " + charId);
    }
}
