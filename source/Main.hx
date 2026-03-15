package;

import dev.DevTools;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.system.scaleModes.RatioScaleMode;
import openfl.display.Sprite;
import states.TitleState;

class Main extends Sprite
{
	public function new()
	{
		super();
		DevTools.install();

		var w = 1280;
		var h = 720;

		addChild(new FlxGame(w, h, () -> new TitleState(), 60, 60, true));

		// Must be run AFTER the FlxGame is created
		FlxG.scaleMode = new RatioScaleMode(true);
		FlxG.fixedTimestep = false;
	}
}
