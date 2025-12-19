package vn;

class RhythmBridge {
    public static function start(song:String, done:Void->Void):Void {
        trace("START RHYTHM: " + song);
        done();
    }
}
