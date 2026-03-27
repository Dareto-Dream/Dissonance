package core.rendering;

import core.scene.PlacementManager;
import flixel.group.FlxGroup;

typedef CharacterSnapshot = {
	name:    String,
	pose:    String,
	slot:    String,
	flipped: Bool,
	showing: Bool
}

class CharacterSystem
{
	public static var instance:CharacterSystem;

	public static function get()
		return instance;

	public var characters:Map<String, CharacterRenderer> = new Map();
	public var group:FlxGroup;

	public var placementManager:PlacementManager;

	public static function init(group:FlxGroup, charDefs:Array<Dynamic>)
	{
		instance = new CharacterSystem(group, charDefs);
	}

	public function new(group:FlxGroup, charDefs:Array<Dynamic>)
	{
		this.group = group;
		placementManager = new PlacementManager();

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
	}

	// =========================================================================
	// Show / hide
	// =========================================================================

	/**
	 * Show a character, applying its placement slot for this node if defined.
	 *
	 * Slot lookup rules (in priority order):
	 *   1. placement file has a slot for (nodeId, name)  → move there
	 *   2. "hidden" slot in placement                     → hide instead
	 *   3. no placement entry + character already placed  → keep position
	 *   4. no placement entry + character new             → default "center"
	 */
	public function show(name:String, pose:String, transition:String, duration:Float, ?nodeId:String)
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Unknown character '" + name + "'");
			return;
		}

		if (nodeId != null)
		{
			var slot = placementManager.getSlot(nodeId, name);
			if (slot == "hidden")
			{
				hide(name, "fade_out", duration > 0 ? duration : 0.3);
				return;
			}
			if (slot != null)
				r.setPositionKeyword(slot);
			else if (r.currentPosition == null || r.currentPosition == "")
				r.setPositionKeyword("center");
		}
		else if (r.currentPosition == null || r.currentPosition == "")
		{
			r.setPositionKeyword("center");
		}

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

	/** Capture current visibility/pose/position for all characters. */
	public function getSnapshot():Array<CharacterSnapshot>
	{
		var snaps:Array<CharacterSnapshot> = [];
		for (name in characters.keys())
		{
			var r = characters.get(name);
			snaps.push({
				name:    name,
				pose:    r.currentPose,
				slot:    r.currentPosition,
				flipped: r.isFlipped,
				showing: r.isShowing
			});
		}
		return snaps;
	}

	/** Restore a snapshot previously captured by getSnapshot(). */
	public function restoreSnapshot(snaps:Array<CharacterSnapshot>):Void
	{
		if (snaps == null) return;
		for (snap in snaps)
		{
			if (!snap.showing || snap.pose == null) continue;
			show(snap.name, snap.pose, "", 0);
			if (snap.flipped) flipCharacter(snap.name, true);
		}
	}

	public function hasPose(name:String, pose:String):Bool
	{
		var r = characters.get(name);
		if (r == null) return false;
		return r.poses != null && r.poses.exists(pose);
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
