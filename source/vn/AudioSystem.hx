package vn;

class AudioSystem {
    public static function playSound(sound:String, volume:Float):Void {
        trace("PLAY SOUND " + sound);
    }

    public static function playMusic(track:String, volume:Float):Void {
        trace("PLAY MUSIC " + track);
    }
}
