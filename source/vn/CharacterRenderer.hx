package vn;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import haxe.Json;
import openfl.utils.Assets;

class CharacterRenderer extends FlxGroup
{
	public var layers:Map<String, FlxSprite> = new Map();
	public var poseData:Dynamic;
	public var config:Dynamic;
	public var poses:Map<String, Dynamic>;

	public var name:String;
	public var baseX:Float = 0;
	public var baseY:Float = 0;
	
	public var currentPosition:String = "center";

	private var hasPoseData:Bool = false;
	private var hasAtlas:Bool = false;

	public function new(characterName:String)
	{
		super();

		this.name = characterName;

		var jsonPath = 'assets/data/characters/$characterName/poses.json';
		try
		{
			var jsonText = Assets.getText(jsonPath);
			poseData = Json.parse(jsonText);

			if (poseData == null)
			{
				throw "Parsed JSON is null";
			}

			config = poseData.config;
			if (config == null)
			{
				trace("[CharacterRenderer] WARNING: No config found in poses.json for " + characterName);
				config = {
					scale: 1.0,
					base_offset: {x: 0, y: 0}
				};
			}

			if (config.base_offset != null)
			{
				baseX = config.base_offset.x;
				baseY = config.base_offset.y;
			}

			if (poseData.poses == null)
			{
				trace("[CharacterRenderer] WARNING: No poses defined in poses.json for " + characterName);
				hasPoseData = false;
				poses = new Map<String, Dynamic>();
				return;
			}

			// Convert the Dynamic poses object to a proper Map
			poses = new Map<String, Dynamic>();
			var posesObj:Dynamic = poseData.poses;
			var poseNames:Array<String> = Reflect.fields(posesObj);

			for (poseName in poseNames)
			{
				var poseData:Dynamic = Reflect.field(posesObj, poseName);
				poses.set(poseName, poseData);
			}

			hasPoseData = true;
			trace("[CharacterRenderer] Loaded pose data for " + characterName + " with " + [for (k in poses.keys()) k].length + " poses");
		}
		catch (e:Dynamic)
		{
			trace("[CharacterRenderer] WARNING: Could not load poses.json for '" + characterName + "': " + e);
			trace("[CharacterRenderer] Path attempted: " + jsonPath);
			hasPoseData = false;
			poses = new Map<String, Dynamic>();

			config = {
				scale: 1.0,
				base_offset: {x: 0, y: 0}
			};
			baseX = 0;
			baseY = 0;
			return;
		}

		var png = 'assets/images/characters/$characterName/$characterName.png';
		var xml = 'assets/images/characters/$characterName/$characterName.xml';
		try
		{
			var frames = flixel.graphics.frames.FlxAtlasFrames.fromSparrow(png, xml);
			
			if (frames == null)
			{
				throw "fromSparrow returned null";
			}

			hasAtlas = true;

			for (poseName in poses.keys())
			{
				var pose:Dynamic = poses.get(poseName);

				if (pose == null || pose.layers == null)
				{
					trace("[CharacterRenderer] WARNING: Pose '" + poseName + "' has no layers for " + characterName);
					continue;
				}
				
				var layerArr:Array<Dynamic> = cast pose.layers;

				for (entry in layerArr)
				{
					if (entry == null || entry.frame == null)
						continue;
					
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
			trace("[CharacterRenderer] Created " + Lambda.count(layers) + " layer sprites for " + characterName);
		}
		catch (e:Dynamic)
		{
			trace("[CharacterRenderer] ERROR: Could not load atlas for " + characterName + ": " + e);
			trace("[CharacterRenderer] PNG: " + png);
			trace("[CharacterRenderer] XML: " + xml);
			hasAtlas = false;
		}
	}

	public function setPose(poseName:String):Void
	{
		if (!hasPoseData || poses == null)
		{
			trace("[CharacterRenderer] Cannot set pose '" + poseName + "' for " + name + " - no pose data loaded");
			return;
		}

		if (!hasAtlas)
		{
			trace("[CharacterRenderer] Cannot set pose '" + poseName + "' for " + name + " - no atlas loaded");
			return;
		}

		if (!poses.exists(poseName))
		{
			trace("[CharacterRenderer] Unknown pose: " + poseName + " for character " + name);
			var available = [for (k in poses.keys()) k];
			trace("[CharacterRenderer] Available poses: " + available.join(", "));
			return;
		}

		var pose = poses.get(poseName);
		if (pose == null || pose.layers == null)
		{
			trace("[CharacterRenderer] Pose '" + poseName + "' has no valid layers");
			return;
		}
		
		var layerArr:Array<Dynamic> = cast pose.layers;

		for (spr in layers)
			spr.visible = false;

		for (entry in layerArr)
		{
			if (entry == null || entry.frame == null)
				continue;
			
			var frame:String = entry.frame;
			var spr = layers.get(frame);
			if (spr == null)
			{
				trace("[CharacterRenderer] WARNING: Frame '" + frame + "' not found in layers");
				continue;
			}

			spr.visible = true;
			spr.animation.frameName = frame;

			spr.x = baseX + entry.x;
			spr.y = baseY + entry.y;
			spr.scale.set(config.scale, config.scale);
		}
	}

	public function setPositionKeyword(pos:String)
	{
		currentPosition = pos;
		var screenW = flixel.FlxG.width;
		var centerX = (screenW / 2) - 250;

		switch pos
		{
			case "far_left":
				setOffset(-200, 0);
			
			case "left":
				setOffset(100, 0);
			
			case "center_left":
				setOffset(centerX - 400, 0);
			
			case "center":
				setOffset(centerX, 0);
			
			case "center_right":
				setOffset(centerX + 400, 0);
			
			case "right":
				setOffset(screenW - 500, 0);
			
			case "far_right":
				setOffset(screenW + 200, 0);

			default:
				setOffset(centerX, 0);
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

	public function emphasize():Void
	{
		// Make character larger and more visible (active speaker)
		for (spr in layers)
		{
			if (spr.visible)
			{
				spr.scale.set(config.scale * 1.1, config.scale * 1.1);
				spr.alpha = 1.0;
			}
		}
	}

	public function deemphasize():Void
	{
		// Make character smaller and dimmer (inactive)
		for (spr in layers)
		{
			if (spr.visible)
			{
				spr.scale.set(config.scale * 0.9, config.scale * 0.9);
				spr.alpha = 0.6;
			}
		}
	}
}
