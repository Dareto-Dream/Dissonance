package;

import flixel.FlxGame;
import openfl.display.Sprite;
import states.VNState;

class Main extends Sprite
{
    public function new()
    {
        super();

        // 1280x720 is ideal for a VN
        addChild(new FlxGame(1280, 720, VNState.new));
    }
}
