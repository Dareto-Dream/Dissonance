package core.rendering;

import core.scene.PlacementManager.PlacementData;
import core.scene.PlacementManager;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

class CharacterSystem
{
	public static var instance:CharacterSystem;

	public static function get()
		return instance;

	public var characters:Map<String, CharacterRenderer> = new Map();
	public var group:FlxGroup;

	public var placementManager:PlacementManager;

	public static function init(group:FlxGroup, charDefs:Array<Dynamic>, ?placementPath:String)
	{
		instance = new CharacterSystem(group, charDefs, placementPath);
	}

	public function new(group:FlxGroup, charDefs:Array<Dynamic>, ?placementPath:String)
	{
		this.group = group;

		placementManager = new PlacementManager();
		if (placementPath != null && placementPath != "")
			placementManager.loadPlacements(placementPath);

		var index = 0;
		for (c in charDefs)
		{
			index++;
			if (c == null || !Reflect.hasField(c, "id") || c.id == null)
			{
				trace("[CharacterSystem] ERROR: charDefs[" + index + "] missing 'id' field.");
				continue;
			}

			var renderer = new CharacterRenderer(c.id);
			characters.set(c.id, renderer);
			group.add(renderer);
		}

		trace("[CharacterSystem] Loaded " + Lambda.count(characters) + " character definitions.");
	}

	// =========================================================================
	// Show / hide
	// =========================================================================

	/**
	 * Show a character with placement + transition support.
	 * Reads flip, z_order, and entry transition from placement data when present.
	 */
	public function show(name:String, pose:String, transition:String, duration:Float, ?nodeId:String)
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Unknown character '" + name + "'");
			return;
		}

		// Apply placement for this node
		var placement:Null<PlacementData> = null;
		if (nodeId != null)
		{
			placementManager.applyNode(nodeId);
			placement = placementManager.getPosition(name);
		}

		if (placement != null)
		{
			// --- Position ---
			if (placement.x != null && placement.y != null)
				r.setAbsolutePosition(placement.x, placement.y);
			else if (placement.slot != null)
				r.setPositionKeyword(placement.slot);
			else if (r.currentPosition != null && r.currentPosition != "")
				{ /* keep current */ }
			else
				r.setPositionKeyword("center");

			if (placement.slot != null) r.currentPosition = placement.slot;

			// --- Flip ---
			if (placement.flip != null)
				r.flip(placement.flip);

			// --- Entry transition override from placement ---
			if (placement.transition != null && placement.transition != "")
			{
				var dur = placement.transition_duration != null ? placement.transition_duration : duration;
				r.setPose(pose);
				r.playTransition(placement.transition, dur);
				return;
			}
		}
		else
		{
			// State persistence: keep position if character already placed
			if (r.currentPosition == null || r.currentPosition == "")
				r.setPositionKeyword("center");
		}

		// Set pose then play transition
		r.setPose(pose);
		if (transition != null && transition != "")
			r.playTransition(transition, duration);
	}

	public function hide(name:String, transition:String, duration:Float)
	{
		var r = characters.get(name);
		if (r == null) return;

		if (transition == "fade_out")
			r.fadeOut(duration > 0 ? duration : 0.4);
		else
			r.hide();

		placementManager.removeCharacter(name);
	}

	// =========================================================================
	// Movement (animated)
	// =========================================================================

	/** Smoothly slide a character to a new named slot. */
	public function moveCharacter(name:String, slot:String, duration:Float = 0.45, ?ease:Float->Float):Void
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Unknown character '" + name + "'");
			return;
		}
		r.moveTo(slot, duration, ease);
	}

	/** Smoothly slide a character to absolute screen coordinates. */
	public function moveCharacterAbsolute(name:String, x:Float, y:Float, duration:Float = 0.45, ?ease:Float->Float):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.moveToAbsolute(x, y, duration, ease);
	}

	// =========================================================================
	// Flip
	// =========================================================================

	/** Mirror a character horizontally. */
	public function flipCharacter(name:String, flipped:Bool):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.flip(flipped);
	}

	// =========================================================================
	// Tint / color
	// =========================================================================

	/** Apply a color tint to a specific character. */
	public function setCharacterTint(name:String, color:Int):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.setTint(color);
	}

	/** Remove color tint from a specific character. */
	public function clearCharacterTint(name:String):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.clearTint();
	}

	/** Apply tint to ALL visible characters (e.g. grayscale flashback mode). */
	public function setAllTint(color:Int):Void
	{
		for (r in characters) r.setTint(color);
	}

	public function clearAllTints():Void
	{
		for (r in characters) r.clearTint();
	}

	// =========================================================================
	// Per-character effects
	// =========================================================================

	/** Make a character bounce (good for reaction moments). */
	public function bounceCharacter(name:String, height:Float = 30, duration:Float = 0.5):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.bounce(height, duration);
	}

	/** Shake a character in place (good for fear / anger). */
	public function shakeCharacter(name:String, intensity:Float = 15, duration:Float = 0.5):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.shakeCharacter(intensity, duration);
	}

	/** Pop a character in (scale from 0 → normal). */
	public function popInCharacter(name:String, duration:Float = 0.3):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.popIn(duration);
	}

	// =========================================================================
	// Emphasis (DDLC-style speaking highlights)
	// =========================================================================

	public function emphasizeCharacter(name:String):Void
	{
		for (charName in characters.keys())
		{
			var r = characters.get(charName);
			if (r != null)
				r.deemphasize();
		}

		var r = characters.get(name);
		if (r != null) r.emphasize();
		else trace("[CharacterSystem] Cannot emphasize unknown character '" + name + "'");
	}

	public function deemphasizeAll():Void
	{
		for (r in characters)
		{
			for (spr in r.vnLayers)
				if (spr.visible) { spr.scale.set(r.config.scale, r.config.scale); spr.alpha = 1.0; }

			for (spr in r.rhythmLayers)
				if (spr.visible) { spr.scale.set(r.config.scale, r.config.scale); spr.alpha = 1.0; }
		}
	}

	// =========================================================================
	// Placement helpers
	// =========================================================================

	public function resetPlacements():Void
	{
		placementManager.reset();
	}

	// =========================================================================
	// Rhythm game integration
	// =========================================================================

	public function playAnimation(name:String, animName:String):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.setPose(animName);
	}

	public function setLooping(name:String, looping:Bool):Void
	{
		var r = characters.get(name);
		if (r == null) return;
		r.isLooping = looping;
	}

	public function hasPose(name:String, pose:String):Bool
	{
		var r = characters.get(name);
		if (r == null) return false;
		return r.poses.exists(pose);
	}

	public function enableRhythmMode():Void
	{
		for (r in characters) r.setRhythmMode(true);
	}

	public function disableRhythmMode():Void
	{
		for (r in characters) r.setRhythmMode(false);
	}
}
