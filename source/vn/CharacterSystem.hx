package vn;

import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import states.VNState;
import vn.CharacterRenderer;

/**
 * CharacterSystem
 *
 * This system controls which characters appear on screen,
 * where they appear, and which pose they use.
 *
 * Rendering is handled by CharacterRenderer.
 */
class CharacterSystem
{
	// Tracks all visible characters: charId -> FlxSpriteGroup
	private static var active:Map<String, FlxSpriteGroup> = new Map();

	/**
	 * Shows or updates a character.
	 *
	 * Expected fields in the node:
	 *   node.character  : String
	 *   node.pose       : String
	 *   node.slot       : String ("left", "center", "right")
	 */
	public static function show(node:Dynamic):Void
	{
		var charId:String = node.character;
		var poseId:String = node.pose;
		var slot:String = node.slot;

		if (charId == null || poseId == null)
		{
			trace("[CharacterSystem] ERROR: Missing character or pose");
			return;
		}

		var state:VNState = cast FlxG.state;

		// If character already exists, remove old one so we can replace it.
		if (active.exists(charId))
		{
			var old = active[charId];
			state.charGroup.remove(old, true);
			old.destroy();
		}

		// Build the pose group using your CharacterRenderer.
		var rendered = CharacterRenderer.build(charId, poseId);

		// Position based on slot
		switch (slot)
		{
			case "left":
				rendered.x = 150;
				rendered.y = 100;

			case "center":
				rendered.x = (FlxG.width / 2) - 200;
				rendered.y = 100;

			case "right":
				rendered.x = FlxG.width - 350;
				rendered.y = 100;

			default:
				rendered.x = (FlxG.width / 2) - 200;
				rendered.y = 100;
		}

		// Add to screen
		state.charGroup.add(rendered);
		active[charId] = rendered;
	}

	/**
	 * Removes a character if they are currently on screen.
	 *
	 * node.character or charId:String
	 */
	public static function hide(charId:String):Void
	{
		if (!active.exists(charId))
		{
			trace("[CharacterSystem] Hide ignored, character not active: " + charId);
			return;
		}

		var state:VNState = cast FlxG.state;

		var grp = active[charId];
		state.charGroup.remove(grp, true);
		grp.destroy();
		active.remove(charId);
    }
}
