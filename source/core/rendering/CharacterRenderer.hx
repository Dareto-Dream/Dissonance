package core.rendering;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.utils.Assets;
import vn.Constants;

/**
 * CharacterRenderer - Renders a single VN character with full positioning control.
 *
 * Positioning model (layered offsets):
 *   finalX = screenX + characterOffsetX + layerOffsetX
 *   finalY = screenY + characterOffsetY + layerOffsetY
 *
 * screenX/Y   → where the character stands on screen (set by slot keyword or absolute coords)
 * characterOffsetX/Y → per-character centering loaded from poses.json config.base_offset
 * layerOffsetX/Y     → per-layer fine-tuning from the pose definition
 *
 * Atlas and pose data are cached statically so scene switches don't re-parse/re-upload textures.
 */
class CharacterRenderer extends FlxGroup
{
	// =========================================================================
	// Static atlas + pose cache (survives scene switches)
	// =========================================================================
	private static var _poseCache:Map<String, Dynamic>         = new Map();
	private static var _vnFramesCache:Map<String, FlxAtlasFrames>     = new Map();
	private static var _rhythmFramesCache:Map<String, FlxAtlasFrames> = new Map();

	/** Call this to fully evict a character from the cache (e.g. when assets change). */
	public static function evictCache(characterName:String):Void
	{
		_poseCache.remove(characterName);
		_vnFramesCache.remove(characterName);
		_rhythmFramesCache.remove(characterName);
	}

	/** Clear the entire cache. */
	public static function clearCache():Void
	{
		_poseCache.clear();
		_vnFramesCache.clear();
		_rhythmFramesCache.clear();
	}

	// =========================================================================
	// Atlas data
	// =========================================================================
	private var vnFrames:FlxAtlasFrames;
	private var rhythmFrames:FlxAtlasFrames;

	public var vnLayers:Map<String, FlxSprite>     = new Map();
	public var rhythmLayers:Map<String, FlxSprite> = new Map();

	public var poseData:Dynamic;
	public var config:Dynamic;
	public var poses:Map<String, Dynamic>;

	public var name:String;

	// =========================================================================
	// Position state
	// =========================================================================
	/** World-space X of the character anchor. Tweened by moveTo / slideIn. */
	public var screenX:Float = 0;
	/** World-space Y of the character anchor. */
	public var screenY:Float = 0;

	/** Per-character centering offset from poses.json → config.base_offset */
	private var characterOffsetX:Float = 0;
	private var characterOffsetY:Float = 0;

	/** Current named slot (e.g. "center", "left"). Updated by setPositionKeyword / moveTo. */
	public var currentPosition:String = "center";

	// =========================================================================
	// Visual state
	// =========================================================================
	public var currentPose:String;
	public var isFlipped:Bool = false;

	/** Whether rhythm-mode atlases are active. */
	public var isRhythmMode:Bool = false;

	/** Sprites currently playing frame-based animations (rhythm mode). */
	public var isLooping:Bool = false;
	private var currentAnimatingSprites:Array<FlxSprite> = [];
	private var currentPoseLayers:Array<Dynamic>;

	// =========================================================================
	// Load flags
	// =========================================================================
	private var hasPoseData:Bool   = false;
	private var hasVNAtlas:Bool    = false;
	private var hasRhythmAtlas:Bool = false;

	// Active tweens – cancelled before starting new movement/entrance tweens
	private var moveTween:FlxTween   = null;
	private var effectTween:FlxTween = null;

	// =========================================================================
	// Construction
	// =========================================================================

	public function new(characterName:String)
	{
		super();
		this.name = characterName;

		loadPoseData(characterName);
		loadVNAtlas(characterName);
		loadRhythmAtlas(characterName);
		createLayerSprites();

		setPositionKeyword("center");
	}

	// =========================================================================
	// Asset loading
	// =========================================================================

	private function loadPoseData(characterName:String):Void
	{
		// Cache hit: reuse previously parsed data
		if (_poseCache.exists(characterName))
		{
			poseData = _poseCache.get(characterName);
			_applyPoseData();
			return;
		}

		var jsonPath = 'assets/data/characters/$characterName/poses.json';
		try
		{
			var jsonText = Assets.getText(jsonPath);
			poseData = Json.parse(jsonText);

			if (poseData == null) throw "Parsed JSON is null";

			_poseCache.set(characterName, poseData);
			_applyPoseData();
		}
		catch (e:Dynamic)
		{
			trace("[CharacterRenderer] ERROR loading poses.json for " + characterName + ": " + e);
			hasPoseData = false;
		}
	}

	private function _applyPoseData():Void
	{
		config = poseData.config;
		if (config == null)
			config = { scale: 1.0, base_offset: { x: 0, y: 0 } };

		if (config.base_offset != null)
		{
			characterOffsetX = config.base_offset.x;
			characterOffsetY = config.base_offset.y;
		}

		if (poseData.poses == null)
		{
			hasPoseData = false;
			return;
		}

		poses = new Map<String, Dynamic>();
		for (field in Reflect.fields(poseData.poses))
			poses.set(field, Reflect.field(poseData.poses, field));

		hasPoseData = true;
	}

	private function loadVNAtlas(characterName:String):Void
	{
		// Cache hit
		if (_vnFramesCache.exists(characterName))
		{
			vnFrames = _vnFramesCache.get(characterName);
			hasVNAtlas = (vnFrames != null);
			return;
		}

		try
		{
			vnFrames = FlxAtlasFrames.fromSparrow(
				'assets/images/characters/$characterName/$characterName.png',
				'assets/images/characters/$characterName/$characterName.xml'
			);
			hasVNAtlas = true;
			_vnFramesCache.set(characterName, vnFrames);
		}
		catch (e:Dynamic)
		{
			trace("[CharacterRenderer] ERROR loading VN atlas for " + characterName + ": " + e);
			hasVNAtlas = false;
			_vnFramesCache.set(characterName, null); // cache miss so we don't retry every load
		}
	}

	private function loadRhythmAtlas(characterName:String):Void
	{
		// Cache hit
		if (_rhythmFramesCache.exists(characterName))
		{
			rhythmFrames = _rhythmFramesCache.get(characterName);
			hasRhythmAtlas = (rhythmFrames != null);
			return;
		}

		try
		{
			var png = 'assets/images/characters/$characterName/${characterName}_rhythm.png';
			var xml = 'assets/images/characters/$characterName/${characterName}_rhythm.xml';

			if (!Assets.exists(png) || !Assets.exists(xml))
			{
				hasRhythmAtlas = false;
				_rhythmFramesCache.set(characterName, null);
				return;
			}

			rhythmFrames = FlxAtlasFrames.fromSparrow(png, xml);
			hasRhythmAtlas = true;
			_rhythmFramesCache.set(characterName, rhythmFrames);
		}
		catch (e:Dynamic)
		{
			hasRhythmAtlas = false;
			_rhythmFramesCache.set(characterName, null);
		}
	}

	private function createLayerSprites():Void
	{
		if (!hasPoseData) return;

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
		}

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
		}
	}

	private function setupRhythmAnimation(sprite:FlxSprite, baseName:String):Void
	{
		var frameNames:Array<String> = [];
		var frameIndex = 0;
		while (frameIndex < 100)
		{
			var frameName = baseName + StringTools.lpad(Std.string(frameIndex), "0", 4);
			if (rhythmFrames.getByName(frameName) != null)
			{
				frameNames.push(frameName);
				frameIndex++;
			}
			else break;
		}
		if (frameNames.length > 0)
			sprite.animation.addByNames(baseName, frameNames, 24, false);
	}

	// =========================================================================
	// Slot helpers
	// =========================================================================

	/**
	 * Converts a named slot to a screen X coordinate.
	 * Delegates to Constants.getSlotX() for a single source of truth.
	 */
	public function slotToScreenX(slot:String):Float
	{
		return Constants.getSlotX(slot);
	}

	// =========================================================================
	// Positioning — instant
	// =========================================================================

	/** Instantly place character at a named slot. */
	public function setPositionKeyword(pos:String):Void
	{
		cancelMoveTween();
		currentPosition = pos;
		screenX = slotToScreenX(pos);
		screenY = 0;
		if (currentPose != null && currentPoseLayers != null)
			updateLayerPositions();
	}

	/** Instantly place character at absolute screen coordinates. */
	public function setAbsolutePosition(x:Float, y:Float):Void
	{
		cancelMoveTween();
		screenX = x;
		screenY = y;
		if (currentPose != null && currentPoseLayers != null)
			updateLayerPositions();
	}

	// =========================================================================
	// Positioning — animated
	// =========================================================================

	/**
	 * Smoothly move character to a named slot over `duration` seconds.
	 * Uses quartOut easing by default for a snappy feel.
	 */
	public function moveTo(slot:String, duration:Float = 0.45, ?ease:Float->Float):Void
	{
		var targetX = slotToScreenX(slot);
		currentPosition = slot;

		if (duration <= 0)
		{
			screenX = targetX;
			screenY = 0;
			updateLayerPositions();
			return;
		}

		cancelMoveTween();
		var easeFn = ease != null ? ease : FlxEase.quartOut;
		moveTween = FlxTween.tween(this, { screenX: targetX, screenY: 0.0 }, duration, {
			ease: easeFn,
			onUpdate: _ -> updateLayerPositions(),
			onComplete: _ -> { moveTween = null; }
		});
	}

	/**
	 * Smoothly move character to absolute coordinates.
	 */
	public function moveToAbsolute(x:Float, y:Float, duration:Float = 0.45, ?ease:Float->Float):Void
	{
		if (duration <= 0)
		{
			screenX = x;
			screenY = y;
			updateLayerPositions();
			return;
		}

		cancelMoveTween();
		var easeFn = ease != null ? ease : FlxEase.quartOut;
		moveTween = FlxTween.tween(this, { screenX: x, screenY: y }, duration, {
			ease: easeFn,
			onUpdate: _ -> updateLayerPositions(),
			onComplete: _ -> { moveTween = null; }
		});
	}

	private function cancelMoveTween():Void
	{
		if (moveTween != null)
		{
			moveTween.cancel();
			moveTween = null;
		}
	}

	// =========================================================================
	// Layer position update — called whenever screenX/Y changes
	// =========================================================================

	private function updateLayerPositions():Void
	{
		if (currentPoseLayers == null) return;

		for (entry in currentPoseLayers)
		{
			if (entry == null || entry.frame == null) continue;

			var frame:String = entry.frame;
			var lox:Float = entry.x;
			var loy:Float = entry.y;

			// Mirror both layer offset and character base offset when flipped
			var fx = isFlipped ? -lox : lox;
			var ox = isFlipped ? -characterOffsetX : characterOffsetX;

			var finalX = screenX + ox + fx;
			var finalY = screenY + characterOffsetY + loy;

			var spr = vnLayers.get(frame);
			if (spr != null && spr.visible)
			{
				spr.x = finalX;
				spr.y = finalY;
			}

			var rspr = rhythmLayers.get(frame);
			if (rspr != null && rspr.visible)
			{
				rspr.x = finalX;
				rspr.y = finalY;
			}
		}
	}

	// =========================================================================
	// Flip
	// =========================================================================

	/** Mirror the character horizontally. */
	public function flip(flipped:Bool):Void
	{
		isFlipped = flipped;
		for (spr in vnLayers)     spr.flipX = flipped;
		for (spr in rhythmLayers) spr.flipX = flipped;
		updateLayerPositions();
	}

	// =========================================================================
	// Tint / color filter
	// =========================================================================

	/** Apply a color tint to all layers. Pass FlxColor.WHITE to clear. */
	public function setTint(color:Int):Void
	{
		for (spr in vnLayers)     spr.color = color;
		for (spr in rhythmLayers) spr.color = color;
	}

	public function clearTint():Void
	{
		setTint(FlxColor.WHITE);
	}

	// =========================================================================
	// Pose system
	// =========================================================================

	public function setPose(poseName:String):Void
	{
		if (!hasPoseData || poses == null) return;

		var isRhythmPose = (poseName.indexOf("sing") == 0 || poseName == "idle" || poseName == "miss");
		var useRhythm    = isRhythmMode && isRhythmPose && hasRhythmAtlas;

		if (useRhythm) setPoseRhythm(poseName);
		else           setPoseVN(poseName);
	}

	private function setPoseVN(poseName:String):Void
	{
		for (spr in vnLayers)     spr.visible = false;
		for (spr in rhythmLayers) spr.visible = false;

		if (!hasVNAtlas || !poses.exists(poseName)) return;

		var pose = poses.get(poseName);
		if (pose == null || pose.layers == null) return;

		currentPose      = poseName;
		currentPoseLayers = cast pose.layers;

		for (entry in currentPoseLayers)
		{
			if (entry == null || entry.frame == null) continue;
			var spr = vnLayers.get(entry.frame);
			if (spr == null) continue;
			spr.visible = true;
			spr.animation.frameName = entry.frame;
			spr.scale.set(config.scale, config.scale);
			spr.flipX = isFlipped;
		}

		updateLayerPositions();
	}

	private function setPoseRhythm(poseName:String):Void
	{
		for (spr in currentAnimatingSprites)
			if (spr != null && spr.animation != null && spr.animation.curAnim != null)
				spr.animation.stop();
		currentAnimatingSprites = [];

		for (spr in vnLayers)     spr.visible = false;
		for (spr in rhythmLayers) spr.visible = false;

		if (!poses.exists(poseName)) return;

		var pose = poses.get(poseName);
		if (pose == null || pose.layers == null) return;

		currentPose       = poseName;
		currentPoseLayers = cast pose.layers;

		var hasAny = false;
		for (_ in rhythmLayers.keys()) { hasAny = true; break; }

		if (!hasRhythmAtlas || !hasAny)
		{
			setPoseVN(poseName);
			return;
		}

		for (entry in currentPoseLayers)
		{
			if (entry == null || entry.frame == null) continue;
			var baseFrame:String = entry.frame;
			var spr = rhythmLayers.get(baseFrame);

			if (spr == null)
			{
				var vnSpr = vnLayers.get(baseFrame);
				if (vnSpr != null) { vnSpr.visible = true; vnSpr.animation.frameName = baseFrame; vnSpr.scale.set(config.scale, config.scale); }
				continue;
			}

			spr.visible = true;
			if (spr.animation != null && spr.animation.exists(baseFrame))
			{
				spr.animation.play(baseFrame, true);
				currentAnimatingSprites.push(spr);
			}
			else
			{
				var sf = baseFrame + "0000";
				if (spr.animation != null && rhythmFrames != null && rhythmFrames.getByName(sf) != null)
					spr.animation.frameName = sf;
			}
			spr.scale.set(config.scale, config.scale);
			spr.flipX = isFlipped;
		}

		updateLayerPositions();
	}

	// =========================================================================
	// Entrance & exit transitions
	// =========================================================================

	/** Fade all visible layers from 0 to 1. */
	public function fadeIn(d:Float = 0.4):Void
	{
		_forVisibleLayers(function(spr:FlxSprite) {
			spr.alpha = 0;
			FlxTween.tween(spr, { alpha: 1 }, d);
		});
	}

	/** Fade all visible layers from current to 0. */
	public function fadeOut(d:Float = 0.4):Void
	{
		_forVisibleLayers(function(spr:FlxSprite) {
			FlxTween.tween(spr, { alpha: 0 }, d, {
				onComplete: _ -> spr.visible = false
			});
		});
	}

	/** Slide in from the left or right. */
	public function slideIn(dir:String, d:Float = 0.45):Void
	{
		var off = (dir == "left") ? -400.0 : 400.0;
		var targetX = screenX;

		screenX += off;
		updateLayerPositions();

		cancelMoveTween();
		moveTween = FlxTween.tween(this, { screenX: targetX }, d, {
			ease: FlxEase.quartOut,
			onUpdate: _ -> updateLayerPositions(),
			onComplete: _ -> { moveTween = null; }
		});
	}

	/** Slide in from below the screen. */
	public function slideUp(d:Float = 0.5):Void
	{
		var targetY = screenY;
		screenY += 400;
		updateLayerPositions();

		cancelMoveTween();
		moveTween = FlxTween.tween(this, { screenY: targetY }, d, {
			ease: FlxEase.quartOut,
			onUpdate: _ -> updateLayerPositions(),
			onComplete: _ -> { moveTween = null; }
		});
	}

	/** Quick scale pop-in (starts tiny, snaps to normal). */
	public function popIn(d:Float = 0.3):Void
	{
		var targetScale = config.scale;
		_forVisibleLayers(function(spr:FlxSprite) {
			spr.scale.set(targetScale * 0.1, targetScale * 0.1);
			FlxTween.tween(spr.scale, { x: targetScale, y: targetScale }, d, {
				ease: FlxEase.backOut
			});
		});
	}

	/**
	 * Bounce up and back down — good for "enter stage left" emphasis moments.
	 * Uses a brief up-tween then bounceOut back to resting Y.
	 */
	public function bounce(height:Float = 30, d:Float = 0.5):Void
	{
		cancelEffectTween();
		var baseY = screenY;
		effectTween = FlxTween.tween(this, { screenY: baseY - height }, d * 0.4, {
			ease: FlxEase.quadOut,
			onUpdate: _ -> updateLayerPositions(),
			onComplete: _ -> {
				effectTween = FlxTween.tween(this, { screenY: baseY }, d * 0.6, {
					ease: FlxEase.bounceOut,
					onUpdate: _ -> updateLayerPositions(),
					onComplete: _ -> { effectTween = null; }
				});
			}
		});
	}

	/**
	 * Quick horizontal shake in place — good for emotional reactions.
	 */
	public function shakeCharacter(intensity:Float = 15, duration:Float = 0.5):Void
	{
		cancelEffectTween();
		var baseX  = screenX;
		var steps  = Std.int(duration / 0.05);
		var stepDur = duration / steps;
		var dir    = 1.0;
		var step   = 0;

		function doStep():Void
		{
			if (step >= steps)
			{
				screenX = baseX;
				updateLayerPositions();
				effectTween = null;
				return;
			}
			var targetX = baseX + dir * intensity * (1.0 - step / steps);
			dir = -dir;
			step++;
			effectTween = FlxTween.tween(this, { screenX: targetX }, stepDur, {
				ease: FlxEase.quadInOut,
				onUpdate: _ -> updateLayerPositions(),
				onComplete: _ -> doStep()
			});
		}
		doStep();
	}

	private function cancelEffectTween():Void
	{
		if (effectTween != null)
		{
			effectTween.cancel();
			effectTween = null;
		}
	}

	/** Route named transition to the right method. */
	public function playTransition(t:String, d:Float):Void
	{
		switch (t)
		{
			case "fade":           fadeIn(d);
			case "fade_out":       fadeOut(d);
			case "slide_left":     slideIn("left", d);
			case "slide_right":    slideIn("right", d);
			case "slide_up":       slideUp(d);
			case "pop":            popIn(d);
			case "bounce":         bounce(30, d);
			default:               /* no transition */
		}
	}

	// =========================================================================
	// Emphasis (DDLC-style speaking highlights)
	// =========================================================================

	public function emphasize():Void
	{
		_forVisibleLayers(function(spr:FlxSprite) {
			spr.scale.set(config.scale * 1.1, config.scale * 1.1);
			spr.alpha = 1.0;
		});
	}

	public function deemphasize():Void
	{
		_forVisibleLayers(function(spr:FlxSprite) {
			spr.scale.set(config.scale * 0.9, config.scale * 0.9);
			spr.alpha = 0.6;
		});
	}

	// =========================================================================
	// Visibility
	// =========================================================================

	public function hide():Void
	{
		for (spr in vnLayers)     spr.visible = false;
		for (spr in rhythmLayers) spr.visible = false;
	}

	/** True if any VN or rhythm layer sprite is currently visible. */
	public var isShowing(get, never):Bool;
	private function get_isShowing():Bool
	{
		for (spr in vnLayers)     if (spr.visible) return true;
		for (spr in rhythmLayers) if (spr.visible) return true;
		return false;
	}

	// =========================================================================
	// Rhythm mode
	// =========================================================================

	public function setRhythmMode(enabled:Bool):Void
	{
		isRhythmMode = enabled;
		if (!enabled)
		{
			for (spr in currentAnimatingSprites)
				if (spr != null && spr.animation != null && spr.animation.curAnim != null)
					spr.animation.stop();
			currentAnimatingSprites = [];
		}
	}

	public function shouldLoop():Bool
	{
		return isLooping;
	}

	// =========================================================================
	// Offset helper (additive nudge)
	// =========================================================================

	public function setOffset(x:Float, y:Float):Void
	{
		screenX += x;
		screenY += y;
		updateLayerPositions();
	}

	// =========================================================================
	// Internal utility
	// =========================================================================

	private function _forVisibleLayers(fn:FlxSprite->Void):Void
	{
		for (spr in vnLayers)     if (spr.visible) fn(spr);
		for (spr in rhythmLayers) if (spr.visible) fn(spr);
	}
}
