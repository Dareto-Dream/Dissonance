package core.rendering;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;
import haxe.Json;
import openfl.utils.Assets;

class CharacterRenderer extends FlxGroup
{
	// Dual atlas support
	private var vnFrames:FlxAtlasFrames;
	private var rhythmFrames:FlxAtlasFrames;
	
	public var vnLayers:Map<String, FlxSprite> = new Map();
	public var rhythmLayers:Map<String, FlxSprite> = new Map();
	
	public var poseData:Dynamic;
	public var config:Dynamic;
	public var poses:Map<String, Dynamic>;

	public var name:String;
	public var baseX:Float = 0;
	public var baseY:Float = 0;
	
	public var currentPosition:String = "center";
	public var currentPose:String = "idle";
	
	// Mode switching
	public var isRhythmMode:Bool = false;
	
	// Animation state
	public var isLooping:Bool = false;
	private var currentAnimatingSprites:Array<FlxSprite> = [];
	
	// Store layer offsets from pose data
	private var layerOffsets:Map<String, {x:Float, y:Float}> = new Map();

	private var hasPoseData:Bool = false;
	private var hasVNAtlas:Bool = false;
	private var hasRhythmAtlas:Bool = false;

	public function new(characterName:String)
	{
		super();
		this.name = characterName;

		// Load pose data first
		loadPoseData(characterName);
		
		// Load VN atlas (required)
		loadVNAtlas(characterName);
		
		// Load rhythm atlas (optional)
		loadRhythmAtlas(characterName);
		
		// Create layer sprites for both atlases
		createLayerSprites();
	}
	
	private function loadPoseData(characterName:String):Void
	{
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
				trace("[CharacterRenderer] WARNING: No poses found in poses.json for " + characterName);
				hasPoseData = false;
				return;
			}

			poses = new Map<String, Dynamic>();
			var poseObj:Dynamic = poseData.poses;
			for (field in Reflect.fields(poseObj))
			{
				poses.set(field, Reflect.field(poseObj, field));
			}

			trace("[CharacterRenderer] Loaded " + Lambda.count(poses) + " poses for " + characterName);
			hasPoseData = true;
		}
		catch (e:Dynamic)
		{
			trace("[CharacterRenderer] ERROR: Could not load poses.json for " + characterName + ": " + e);
			hasPoseData = false;
		}
	}
	
	private function loadVNAtlas(characterName:String):Void
	{
		try
		{
			var png = 'assets/images/characters/$characterName/$characterName.png';
			var xml = 'assets/images/characters/$characterName/$characterName.xml';
			vnFrames = FlxAtlasFrames.fromSparrow(png, xml);
			hasVNAtlas = true;
			trace("[CharacterRenderer] Loaded VN atlas for " + characterName);
		}
		catch (e:Dynamic)
		{
			trace("[CharacterRenderer] ERROR: Could not load VN atlas for " + characterName + ": " + e);
			hasVNAtlas = false;
		}
	}
	
	private function loadRhythmAtlas(characterName:String):Void
	{
		try
		{
			var png = 'assets/images/characters/$characterName/${characterName}_rhythm.png';
			var xml = 'assets/images/characters/$characterName/${characterName}_rhythm.xml';
			
			// Check if rhythm assets exist
			if (!Assets.exists(png) || !Assets.exists(xml))
			{
				trace("[CharacterRenderer] No rhythm atlas found for " + characterName + " (this is optional)");
				hasRhythmAtlas = false;
				return;
			}
			
			rhythmFrames = FlxAtlasFrames.fromSparrow(png, xml);
			hasRhythmAtlas = true;
			trace("[CharacterRenderer] Loaded rhythm atlas for " + characterName);
		}
		catch (e:Dynamic)
		{
			trace("[CharacterRenderer] Could not load rhythm atlas for " + characterName + ": " + e);
			hasRhythmAtlas = false;
		}
	}
	
	private function createLayerSprites():Void
	{
		if (!hasPoseData) return;
		
		// Create VN layer sprites
		if (hasVNAtlas)
		{
			for (poseName in poses.keys())
			{
				var pose:Dynamic = poses.get(poseName);
				if (pose.layers == null)
				{
					trace("[CharacterRenderer] WARNING: Pose '" + poseName + "' has no layers");
					continue;
				}
				
				var layerArr:Array<Dynamic> = cast pose.layers;

				for (entry in layerArr)
				{
					if (entry == null || entry.frame == null)
						continue;
					
					var frame:String = entry.frame;

					if (!vnLayers.exists(frame))
					{
						var spr = new FlxSprite();
						spr.frames = vnFrames;
						spr.visible = false;
						spr.antialiasing = true;
						spr.scrollFactor.set(0, 0);

						vnLayers.set(frame, spr);
						add(spr);
					}
				}
			}
			trace("[CharacterRenderer] Created " + Lambda.count(vnLayers) + " VN layer sprites for " + name);
		}
		
		// Create rhythm layer sprites with animations
		if (hasRhythmAtlas)
		{
			var rhythmPoses = ["singLEFT", "singDOWN", "singUP", "singRIGHT", "idle", "miss"];
			
			for (poseName in rhythmPoses)
			{
				if (!poses.exists(poseName)) continue;
				
				var pose:Dynamic = poses.get(poseName);
				if (pose.layers == null) continue;
				
				var layerArr:Array<Dynamic> = cast pose.layers;
				for (entry in layerArr)
				{
					if (entry == null || entry.frame == null) continue;
					var baseFrame:String = entry.frame;
					
					if (!rhythmLayers.exists(baseFrame))
					{
						var spr = new FlxSprite();
						spr.frames = rhythmFrames;
						spr.visible = false;
						spr.antialiasing = true;
						spr.scrollFactor.set(0, 0);
						
						// Setup multi-frame animation
						setupRhythmAnimation(spr, baseFrame);
						
						rhythmLayers.set(baseFrame, spr);
						add(spr);
					}
				}
			}
			trace("[CharacterRenderer] Created " + Lambda.count(rhythmLayers) + " rhythm layer sprites for " + name);
		}
	}
	
	private function setupRhythmAnimation(sprite:FlxSprite, baseName:String):Void
	{
		// Look for sequenced frames: baseName0000, baseName0001, baseName0002, etc.
		var frameNames:Array<String> = [];
		var frameIndex = 0;
		var maxFrames = 100; // Safety limit
		
		while (frameIndex < maxFrames)
		{
			var frameName = baseName + StringTools.lpad(Std.string(frameIndex), "0", 4);
			
			// Check if frame exists in atlas
			if (rhythmFrames.getByName(frameName) != null)
			{
				frameNames.push(frameName);
				frameIndex++;
			}
			else
			{
				break;
			}
		}
		
		if (frameNames.length > 0)
		{
			// Create animation with 24 fps, non-looping
			sprite.animation.addByNames(baseName, frameNames, 24, false);
			trace('[CharacterRenderer] Created ${frameNames.length}-frame animation for $baseName');
		}
		else
		{
			trace('[CharacterRenderer] WARNING: No frames found for $baseName');
		}
	}

	public function setPose(poseName:String):Void
	{
		if (!hasPoseData || poses == null)
		{
			trace("[CharacterRenderer] Cannot set pose '" + poseName + "' for " + name + " - no pose data loaded");
			return;
		}
		
		// Determine which atlas to use based on mode and pose name
		var isRhythmPose = (poseName.indexOf("sing") == 0 || poseName == "idle" || poseName == "miss");
		var useRhythm = isRhythmMode && isRhythmPose;
		
		// If trying to use rhythm mode but no rhythm atlas, fall back to VN
		if (useRhythm && !hasRhythmAtlas)
		{
			trace('[CharacterRenderer] WARNING: Rhythm mode requested but no rhythm atlas for $name, using VN atlas');
			useRhythm = false;
		}
		
		if (useRhythm)
		{
			setPoseRhythm(poseName);
		}
		else
		{
			if (!hasVNAtlas)
			{
				trace("[CharacterRenderer] Cannot set VN pose '" + poseName + "' for " + name + " - no VN atlas loaded");
				return;
			}
			setPoseVN(poseName);
		}
	}
	
	private function setPoseVN(poseName:String):Void
	{
		// Hide all layers
		for (spr in vnLayers) spr.visible = false;
		for (spr in rhythmLayers) spr.visible = false;
		
		if (!poses.exists(poseName))
		{
			trace("[CharacterRenderer] Unknown VN pose: " + poseName + " for character " + name);
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
		layerOffsets.clear();

		trace('[CharacterRenderer] Setting VN pose "$poseName" for $name (${layerArr.length} layers)');

		for (entry in layerArr)
		{
			if (entry == null || entry.frame == null)
				continue;
			
			var frame:String = entry.frame;
			var spr = vnLayers.get(frame);
			if (spr == null)
			{
				trace("[CharacterRenderer] WARNING: VN frame '" + frame + "' not found in layers");
				continue;
			}

			spr.visible = true;
			spr.animation.frameName = frame;

			var offsetX:Float = entry.x;
			var offsetY:Float = entry.y;
			layerOffsets.set(frame, {x: offsetX, y: offsetY});

			spr.x = baseX + offsetX;
			spr.y = baseY + offsetY;
			spr.scale.set(config.scale, config.scale);
		}
		
		currentPose = poseName;
	}
	
	private function setPoseRhythm(poseName:String):Void
	{
		// Stop any currently playing animations
		for (spr in currentAnimatingSprites)
		{
			if (spr != null && spr.animation != null && spr.animation.curAnim != null)
			{
				spr.animation.stop();
			}
		}
		currentAnimatingSprites = [];
		
		// Hide all layers
		for (spr in vnLayers) spr.visible = false;
		for (spr in rhythmLayers) spr.visible = false;
		
		if (!poses.exists(poseName))
		{
			trace("[CharacterRenderer] Unknown rhythm pose: " + poseName + " for character " + name);
			return;
		}
		
		var pose = poses.get(poseName);
		if (pose == null || pose.layers == null)
		{
			trace("[CharacterRenderer] Pose has no layers");
			return;
		}
		
		layerOffsets.clear();
		var layerArr:Array<Dynamic> = cast pose.layers;
		
		trace('[CharacterRenderer] Setting rhythm pose "$poseName" for $name');
		
		// Check if we have any rhythm layers at all
		var hasAnyRhythmLayers = false;
		for (_ in rhythmLayers.keys())
		{
			hasAnyRhythmLayers = true;
			break;
		}
		
		// FALLBACK: If no rhythm layers at all, use VN layers
		if (!hasRhythmAtlas || !hasAnyRhythmLayers)
		{
			trace('[CharacterRenderer] No rhythm layers for $name, using VN layers as fallback');
			setPoseVN(poseName);
			return;
		}
		
		// Process each layer
		for (entry in layerArr)
		{
			if (entry == null || entry.frame == null) continue;
			
			var baseFrame:String = entry.frame;
			var spr = rhythmLayers.get(baseFrame);
			
			// NULL CHECK - Critical for preventing errors
			if (spr == null)
			{
				trace("[CharacterRenderer] WARNING: Rhythm sprite for '" + baseFrame + "' is null, trying VN fallback");
				
				// Try VN layer as fallback
				var vnSpr = vnLayers.get(baseFrame);
				if (vnSpr != null)
				{
					vnSpr.visible = true;
					
					// Safely set frame name
					if (vnSpr.animation != null)
					{
						vnSpr.animation.frameName = baseFrame;
					}
					
					var offsetX:Float = entry.x;
					var offsetY:Float = entry.y;
					layerOffsets.set(baseFrame, {x: offsetX, y: offsetY});
					
					vnSpr.x = baseX + offsetX;
					vnSpr.y = baseY + offsetY;
					vnSpr.scale.set(config.scale, config.scale);
				}
				else
				{
					trace("[CharacterRenderer] WARNING: No VN fallback for '" + baseFrame + "' either");
				}
				continue;
			}
			
			// spr is confirmed not null here
			spr.visible = true;
			
			// CRITICAL NULL CHECK: Safely check animation before calling exists()
			if (spr.animation != null && spr.animation.exists(baseFrame))
			{
				spr.animation.play(baseFrame, true); // Force restart
				currentAnimatingSprites.push(spr);
				trace('[CharacterRenderer] Playing animation "$baseFrame"');
			}
			else
			{
				// Fallback to static frame
				var staticFrame = baseFrame + "0000";
				if (spr.animation != null && rhythmFrames != null && rhythmFrames.getByName(staticFrame) != null)
				{
					spr.animation.frameName = staticFrame;
					trace('[CharacterRenderer] Using static frame "$staticFrame"');
				}
				else
				{
					trace('[CharacterRenderer] No animation for "$baseFrame", no static fallback available');
				}
			}
			
			var offsetX:Float = entry.x;
			var offsetY:Float = entry.y;
			layerOffsets.set(baseFrame, {x: offsetX, y: offsetY});
			
			spr.x = baseX + offsetX;
			spr.y = baseY + offsetY;
			spr.scale.set(config.scale, config.scale);
		}
		
		currentPose = poseName;
	}

	public function setAbsolutePosition(x:Float, y:Float):Void
	{
		trace('[CharacterRenderer] Moving character $name to absolute position ($x, $y)');
		
		var deltaX = x - baseX;
		var deltaY = y - baseY;
		
		trace('[CharacterRenderer]   Delta: ($deltaX, $deltaY) from base ($baseX, $baseY)');
		
		// Move all visible sprites
		for (spr in vnLayers)
		{
			if (spr.visible)
			{
				spr.x += deltaX;
				spr.y += deltaY;
			}
		}
		
		for (spr in rhythmLayers)
		{
			if (spr.visible)
			{
				spr.x += deltaX;
				spr.y += deltaY;
			}
		}
		
		baseX = x;
		baseY = y;
	}

	public function setPositionKeyword(pos:String)
	{
		currentPosition = pos;
		var screenW = flixel.FlxG.width;
		var centerX = (screenW / 2) - 250;

		var targetX:Float;
		var targetY:Float = 0;

		switch pos
		{
			case "far_left":
				targetX = -200;
			case "left":
				targetX = 100;
			case "center_left":
				targetX = centerX - 400;
			case "center":
				targetX = centerX;
			case "center_right":
				targetX = centerX + 400;
			case "right":
				targetX = screenW - 500;
			case "far_right":
				targetX = screenW + 200;
			default:
				targetX = centerX;
		}
		
		setAbsolutePosition(targetX, targetY);
	}

	public function setOffset(x:Float, y:Float)
	{
		for (spr in vnLayers)
		{
			spr.x += x;
			spr.y += y;
		}
		
		for (spr in rhythmLayers)
		{
			spr.x += x;
			spr.y += y;
		}
		
		baseX += x;
		baseY += y;
	}
	
	public function fadeIn(d:Float = 0.4)
	{
		for (spr in vnLayers)
		{
			spr.alpha = 0;
			if (spr.visible)
				FlxTween.tween(spr, {alpha: 1}, d);
		}
		
		for (spr in rhythmLayers)
		{
			spr.alpha = 0;
			if (spr.visible)
				FlxTween.tween(spr, {alpha: 1}, d);
		}
	}

	public function slideIn(dir:String, d:Float = 0.45)
	{
		var off = (dir == "left") ? -400 : 400;

		for (spr in vnLayers)
		{
			if (!spr.visible) continue;
			var finalX = spr.x;
			spr.x += off;
			FlxTween.tween(spr, {x: finalX}, d);
		}
		
		for (spr in rhythmLayers)
		{
			if (!spr.visible) continue;
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
		for (spr in vnLayers) spr.visible = false;
		for (spr in rhythmLayers) spr.visible = false;
	}

	public function emphasize():Void
	{
		for (spr in vnLayers)
		{
			if (spr.visible)
			{
				spr.scale.set(config.scale * 1.1, config.scale * 1.1);
				spr.alpha = 1.0;
			}
		}
		
		for (spr in rhythmLayers)
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
		for (spr in vnLayers)
		{
			if (spr.visible)
			{
				spr.scale.set(config.scale * 0.9, config.scale * 0.9);
				spr.alpha = 0.6;
			}
		}
		
		for (spr in rhythmLayers)
		{
			if (spr.visible)
			{
				spr.scale.set(config.scale * 0.9, config.scale * 0.9);
				spr.alpha = 0.6;
			}
		}
	}
	
	public function setRhythmMode(enabled:Bool):Void
	{
		isRhythmMode = enabled;
		trace('[CharacterRenderer] Rhythm mode ${enabled ? "ENABLED" : "DISABLED"} for $name');
		
		if (!enabled)
		{
			// Stop all animations when exiting rhythm mode
			for (spr in currentAnimatingSprites)
			{
				if (spr != null && spr.animation != null && spr.animation.curAnim != null)
				{
					spr.animation.stop();
				}
			}
			currentAnimatingSprites = [];
		}
	}
	
	public function shouldLoop():Bool
	{
		return isLooping;
	}
}