package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.system.scaleModes.RatioScaleMode;
import openfl.display.Sprite;
import states.VNState;

class Main extends Sprite
{
	public function new()
	{
		super();

		var w = 1280;
		var h = 720;

		addChild(new FlxGame(w, h, () -> new VNState(), 60, 60, true));

		// Must be run AFTER the FlxGame is created
		FlxG.scaleMode = new RatioScaleMode(true);
		FlxG.fixedTimestep = false;
	}
}