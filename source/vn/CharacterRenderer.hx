package vn;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

class CharacterRenderer
{
	public var sprite:FlxSprite;

	// Canonical VN stage positions
	public static inline var POS_LEFT:Float = 200;
	public static inline var POS_CENTER:Float = 640;
	public static inline var POS_RIGHT:Float = 1080;
	public static inline var BASE_Y:Float = 360;

	// Target placement for transitions
	private var targetX:Float = 0;
	private var targetY:Float = BASE_Y;

	public function new(sprite:FlxSprite)
	{
		this.sprite = sprite;
		sprite.visible = false;
	}

	// -------------------------------------------------
	//  POSE SWITCHING
	// -------------------------------------------------
	public function setPose(pose:String)
	{
		// Your animation system here:
		// sprite.animation.play(pose);
		if (sprite.animation != null)
			sprite.animation.play(pose);
	}

	// -------------------------------------------------
	//  POSITION RESOLUTION (STRING / NUMBER)
	// -------------------------------------------------
	public function resolvePosition(pos:Dynamic)
	{
		if (Std.isOfType(pos, Float) || Std.isOfType(pos, Int))
		{
			// numeric X position
			targetX = pos;
			targetY = BASE_Y;
			return;
		}

		switch (pos)
		{
			case "left":
				targetX = POS_LEFT;
			case "center":
				targetX = POS_CENTER;
			case "right":
				targetX = POS_RIGHT;
			default:
				targetX = POS_CENTER; // fallback
		}

		targetY = BASE_Y;
	}

	// -------------------------------------------------
	//  TRANSITIONS
	// -------------------------------------------------
	public function playTransition(trans:String, duration:Float)
	{
		switch (trans)
		{
			case "slide_in_left":
				sprite.x = -sprite.width;
				sprite.y = targetY;
				FlxTween.tween(sprite, {x: targetX}, duration, {ease: FlxEase.quadOut});

			case "slide_in_right":
				sprite.x = FlxG.width + sprite.width;
				sprite.y = targetY;
				FlxTween.tween(sprite, {x: targetX}, duration, {ease: FlxEase.quadOut});

			case "fade_in":
				sprite.alpha = 0;
				sprite.x = targetX;
				sprite.y = targetY;
				FlxTween.tween(sprite, {alpha: 1}, duration);

			case "instant":
				sprite.x = targetX;
				sprite.y = targetY;
				sprite.alpha = 1;

			default:
				// unrecognized → snap
				sprite.x = targetX;
				sprite.y = targetY;
				sprite.alpha = 1;
		}
	}

	// -------------------------------------------------
	//  VISIBILITY
	// -------------------------------------------------
	public function show()
	{
		sprite.visible = true;
    }

	public function hide(?transition:String, ?duration:Float = 0)
	{
		if (transition == null || transition == "instant")
		{
			sprite.visible = false;
			return;
		}

		switch (transition)
		{
			case "fade_out":
				FlxTween.tween(sprite, {alpha: 0}, duration, {
					onComplete: (_) -> sprite.visible = false
				});

			default:
				sprite.visible = false;
		}
    }
}
