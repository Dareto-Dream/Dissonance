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
	
	// CRITICAL FIX: Separate screen position from character offset
	private var screenX:Float = 0;      // Where character is on screen
	private var screenY:Float = 0;
	private var characterOffsetX:Float = 0;  // Character-specific centering
	private var characterOffsetY:Float = 0;
	
	public var currentPosition:String = "center";
	public var currentPose:String;
	
	// Mode switching
	public var isRhythmMode:Bool = false;
	
	// Animation state
	public var isLooping:Bool = false;
	private var currentAnimatingSprites:Array<FlxSprite> = [];
	
	// Store current pose's layer data
	private var currentPoseLayers:Array<Dynamic>;

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
		
		// Initialize to center position
		setPositionKeyword("center");
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

			// CRITICAL FIX: Store character offset separately
			if (config.base_offset != null)
			{
				characterOffsetX = config.base_offset.x;
				characterOffsetY = config.base_offset.y;
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
				if (pose.layers == null) continue;
				
				var layerArr:Array<Dynamic> = cast pose.layers;

				for (entry in layerArr)
				{
					if (entry == null || entry.frame == null) continue;
					
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
		var frameNames:Array<String> = [];
		var frameIndex = 0;
		var maxFrames = 100;
		
		while (frameIndex < maxFrames)
		{
			var frameName = baseName + StringTools.lpad(Std.string(frameIndex), "0", 4);
			
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
			sprite.animation.addByNames(baseName, frameNames, 24, false);
			trace('[CharacterRenderer] Created ${frameNames.length}-frame animation for $baseName');
		}
		else
		{
			trace('[CharacterRenderer] WARNING: No frames found for $baseName');
		}
	}

	// =========================================================================
	// CRITICAL FIX: Completely rewritten positioning system
	// =========================================================================

	/**
	 * Set character position using keyword (e.g., "center", "left", "right")
	 * This is the PRIMARY way to position characters
	 */
	public function setPositionKeyword(pos:String):Void
	{
		currentPosition = pos;
		var screenW = flixel.FlxG.width;
		var centerX = (screenW / 2) - 250;

		// Convert slot keyword to screen coordinates
		switch (pos)
		{
			case "far_left":
				screenX = -200;
			case "left":
				screenX = 100;
			case "center_left":
				screenX = centerX - 400;
			case "center":
				screenX = centerX;
			case "center_right":
				screenX = centerX + 400;
			case "right":
				screenX = screenW - 500;
			case "far_right":
				screenX = screenW + 200;
			default:
				screenX = centerX;
		}
		
		screenY = 0;  // Base vertical position
		
		trace('[CharacterRenderer] Set position keyword "$pos" → screen position ($screenX, $screenY)');
		
		// CRITICAL: Reposition all layers if we have a pose active
		if (currentPose != null && currentPoseLayers != null)
		{
			updateLayerPositions();
		}
	}

	/**
	 * Set character to absolute screen coordinates
	 * Used by PlacementManager for custom positioning
	 */
	public function setAbsolutePosition(x:Float, y:Float):Void
	{
		trace('[CharacterRenderer] Set absolute position for $name: ($x, $y)');
		
		screenX = x;
		screenY = y;
		
		// CRITICAL: Reposition all layers
		if (currentPose != null && currentPoseLayers != null)
		{
			updateLayerPositions();
		}
	}

	/**
	 * Update all visible layer positions based on current screen position
	 * This is called whenever screenX/screenY changes OR when pose changes
	 */
	private function updateLayerPositions():Void
	{
		if (currentPoseLayers == null) return;
		
		for (entry in currentPoseLayers)
		{
			if (entry == null || entry.frame == null) continue;
			
			var frame:String = entry.frame;
			var layerOffsetX:Float = entry.x;
			var layerOffsetY:Float = entry.y;
			
			// Calculate final position:
			// screen position + character offset + layer offset
			var finalX = screenX + characterOffsetX + layerOffsetX;
			var finalY = screenY + characterOffsetY + layerOffsetY;
			
			// Apply to appropriate layer collection
			var spr = vnLayers.get(frame);
			if (spr != null && spr.visible)
			{
				spr.x = finalX;
				spr.y = finalY;
			}
			
			var rhythmSpr = rhythmLayers.get(frame);
			if (rhythmSpr != null && rhythmSpr.visible)
			{
				rhythmSpr.x = finalX;
				rhythmSpr.y = finalY;
			}
		}
	}

	// =========================================================================
	// Pose System - Now properly separated from positioning
	// =========================================================================

	public function setPose(poseName:String):Void
	{
		if (!hasPoseData || poses == null)
		{
			trace("[CharacterRenderer] Cannot set pose '" + poseName + "' for " + name + " - no pose data loaded");
			return;
		}
		
		var isRhythmPose = (poseName.indexOf("sing") == 0 || poseName == "idle" || poseName == "miss");
		var useRhythm = isRhythmMode && isRhythmPose;
		
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
		// Hide all layers first
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
		
		currentPose = poseName;
		currentPoseLayers = cast pose.layers;

		trace('[CharacterRenderer] Setting VN pose "$poseName" for $name (${currentPoseLayers.length} layers)');

		// Make layers visible and set their frames
		for (entry in currentPoseLayers)
		{
			if (entry == null || entry.frame == null) continue;
			
			var frame:String = entry.frame;
			var spr = vnLayers.get(frame);
			if (spr == null)
			{
				trace("[CharacterRenderer] WARNING: VN frame '" + frame + "' not found in layers");
				continue;
			}

			spr.visible = true;
			spr.animation.frameName = frame;
			spr.scale.set(config.scale, config.scale);
		}
		
		// CRITICAL: Position all layers based on current screen position
		updateLayerPositions();
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
		
		currentPose = poseName;
		currentPoseLayers = cast pose.layers;
		
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
		for (entry in currentPoseLayers)
		{
			if (entry == null || entry.frame == null) continue;
			
			var baseFrame:String = entry.frame;
			var spr = rhythmLayers.get(baseFrame);
			
			if (spr == null)
			{
				trace("[CharacterRenderer] WARNING: Rhythm sprite for '" + baseFrame + "' is null, trying VN fallback");
				
				var vnSpr = vnLayers.get(baseFrame);
				if (vnSpr != null)
				{
					vnSpr.visible = true;
					if (vnSpr.animation != null)
					{
						vnSpr.animation.frameName = baseFrame;
					}
					vnSpr.scale.set(config.scale, config.scale);
				}
				continue;
			}
			
			spr.visible = true;
			
			if (spr.animation != null && spr.animation.exists(baseFrame))
			{
				spr.animation.play(baseFrame, true);
				currentAnimatingSprites.push(spr);
				trace('[CharacterRenderer] Playing animation "$baseFrame"');
			}
			else
			{
				var staticFrame = baseFrame + "0000";
				if (spr.animation != null && rhythmFrames != null && rhythmFrames.getByName(staticFrame) != null)
				{
					spr.animation.frameName = staticFrame;
					trace('[CharacterRenderer] Using static frame "$staticFrame"');
				}
			}
			
			spr.scale.set(config.scale, config.scale);
		}
		
		// CRITICAL: Position all layers
		updateLayerPositions();
	}

	// =========================================================================
	// Transitions and Effects
	// =========================================================================

	public function setOffset(x:Float, y:Float):Void
	{
		screenX += x;
		screenY += y;
		updateLayerPositions();
	}
	
	public function fadeIn(d:Float = 0.4):Void
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

	public function slideIn(dir:String, d:Float = 0.45):Void
	{
		var off = (dir == "left") ? -400 : 400;
		var originalX = screenX;
		
		screenX += off;
		updateLayerPositions();
		
		FlxTween.tween(this, {screenX: originalX}, d, {
			onUpdate: function(_) {
				updateLayerPositions();
			}
		});
	}

	public function playTransition(t:String, d:Float):Void
	{
		switch (t)
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