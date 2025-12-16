package core.effects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class EffectSystem
{
	static var uiGroup:FlxGroup;
	static var flashSprite:FlxSprite;

	public static function init(group:FlxGroup):Void
	{
		uiGroup = group;

		// Single fullscreen flash overlay, permanently in uiGroup
		flashSprite = new FlxSprite(0, 0);
		flashSprite.makeGraphic(FlxG.width, FlxG.height, 0xffffffff);
		flashSprite.scrollFactor.set(0, 0);
		flashSprite.alpha = 0;
		flashSprite.visible = false;

		uiGroup.add(flashSprite);
	}

	// ------------------------------------------------------------
	// SCREEN SHAKE
	// ------------------------------------------------------------
	public static function shake(intensity:Float, duration:Float):Void
	{
        trace("SHAKE " + intensity);
		// Flixel native screen shake
		FlxG.camera.shake(intensity, duration);
    }

	// ------------------------------------------------------------
	// FLASH (WHITE OR ANY COLOR)
	// ------------------------------------------------------------
	public static function flash(color:String, duration:Float):Void
	{
        trace("FLASH " + color);
		if (flashSprite == null)
			return;

		// Convert "#RRGGBB" to Int color if needed
		var c:Int = Std.parseInt(color);
		if (Std.string(color).indexOf("#") == 0)
		{
			// Hex string → int
			c = FlxColor.fromString(color);
		}

		flashSprite.makeGraphic(FlxG.width, FlxG.height, c);
		flashSprite.alpha = 1;
		flashSprite.visible = true;

		FlxTween.tween(flashSprite, {alpha: 0}, duration, {
			ease: FlxEase.quadOut,
			onComplete: (_) -> flashSprite.visible = false
		});
    }

	// ------------------------------------------------------------
	// GLITCH (PLACEHOLDER IMPLEMENTATION)
	// ------------------------------------------------------------
	public static function glitch(intensity:Float, duration:Float):Void
	{
        trace("GLITCH " + intensity);
		// Currently just a screen shake + fast white flicker
		// You can replace this with a shader later.
		shake(intensity * 0.5, duration * 0.5);

		flash("#FFFFFF", duration * 0.1);
    }
}
