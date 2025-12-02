package vn;

class EffectSystem {
    public static function shake(intensity:Float, duration:Float):Void {
        trace("SHAKE " + intensity);
    }

    public static function flash(color:String, duration:Float):Void {
        trace("FLASH " + color);
    }

    public static function glitch(intensity:Float, duration:Float):Void {
        trace("GLITCH " + intensity);
    }
}
