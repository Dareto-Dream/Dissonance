package vn;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import haxe.Json;
import openfl.utils.Assets;

/**
 * Layered VN Character Renderer
 */
class CharacterRenderer extends FlxGroup
{
	public var layers:Map<String, FlxSprite> = new Map();
	public var poseData:Dynamic;
	public var config:Dynamic;

	public var name:String;
	public var baseX:Float = 0;
	public var baseY:Float = 0;

	public function new(characterName:String)
	{
		super();

		this.name = characterName;

		// Load JSON
		var jsonPath = 'assets/data/characters/$characterName/poses.json';
		poseData = Json.parse(Assets.getText(jsonPath));
		config = poseData.config;

		baseX = config.base_offset.x;
		baseY = config.base_offset.y;

		// Load atlas
		var png = 'assets/images/characters/$characterName/$characterName.png';
		var xml = 'assets/images/characters/$characterName/$characterName.xml';
		var frames = flixel.graphics.frames.FlxAtlasFrames.fromSparrow(png, xml);

		// Prebuild sprites
		var poses:Map<String, Dynamic> = cast poseData.poses;

		for (poseName => pose in poses)
		{
			var layerArr:Array<Dynamic> = cast pose.layers;

			for (entry in layerArr)
			{
				var frame:String = entry.frame;

				if (!layers.exists(frame))
				{
					var spr = new FlxSprite();
					spr.frames = frames;
					spr.visible = false;
					spr.antialiasing = true;
					spr.scrollFactor.set(0, 0);

					layers.set(frame, spr);
					add(spr);
				}
			}
		}
	}

	public function setPose(poseName:String):Void
	{
		var poses:Map<String, Dynamic> = cast poseData.poses;

		if (!poses.exists(poseName))
		{
			trace("[CharacterRenderer] Unknown pose: " + poseName);
			return;
		}

		var pose = poses.get(poseName);
		var layerArr:Array<Dynamic> = cast pose.layers;

		// Hide all
		for (spr in layers)
			spr.visible = false;

		// Activate pose layers
		for (entry in layerArr)
		{
			var frame:String = entry.frame;
			var spr = layers.get(frame);
			if (spr == null)
				continue;

			spr.visible = true;
			spr.animation.frameName = frame;

			spr.x = baseX + entry.x;
			spr.y = baseY + entry.y;
			spr.scale.set(config.scale, config.scale);
		}
	}

	public function setPositionKeyword(pos:String)
	{
		var screenW = flixel.FlxG.width;

		switch pos
		{
			case "left":
				setOffset(100, 0);

			case "right":
				setOffset(screenW - 500, 0);

			default:
				setOffset((screenW / 2) - 250, 0);
		}
	}

	public function setOffset(x:Float, y:Float)
	{
		for (spr in layers)
		{
			spr.x += x;
			spr.y += y;
		}
    }

	public function fadeIn(d:Float = 0.4)
	{
		for (spr in layers)
		{
			spr.alpha = 0;
			if (spr.visible)
				FlxTween.tween(spr, {alpha: 1}, d);
		}
	}

	public function slideIn(dir:String, d:Float = 0.45)
	{
		var off = (dir == "left") ? -400 : 400;

		for (spr in layers)
		{
			if (!spr.visible)
				continue;
			var finalX = spr.x;
			spr.x += off;
			FlxTween.tween(spr, {x: finalX}, d);
		}
	}

	public function playTransition(t:String, d:Float)
	{
		switch t
		{
			case "fade":
				fadeIn(d);
			case "slide_left":
				slideIn("left", d);
			case "slide_right":
				slideIn("right", d);
			default:
		}
	}

	public function hide():Void
	{
		for (spr in layers)
			spr.visible = false;
    }
}
