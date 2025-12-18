package core.rendering;

import flixel.group.FlxGroup;
import core.scene.PlacementManager;
import core.scene.PlacementManager.PlacementData;

class CharacterSystem
{
	public static var instance:CharacterSystem;

	public static function get()
		return instance;

	public var characters:Map<String, CharacterRenderer> = [];
	public var group:FlxGroup;
	
	public var placementManager:PlacementManager;

	public static function init(group:FlxGroup, charDefs:Array<Dynamic>, ?placementPath:String)
	{
		instance = new CharacterSystem(group, charDefs, placementPath);
	}

	public function new(group:FlxGroup, charDefs:Array<Dynamic>, ?placementPath:String)
	{
		this.group = group;
		
		// Initialize placement manager
		placementManager = new PlacementManager();
		if (placementPath != null && placementPath != "")
		{
			placementManager.loadPlacements(placementPath);
		}

		var index = 0;
		for (c in charDefs)
		{
			index++;

			if (c == null)
			{
				trace("[CharacterSystem] ERROR: charDefs[" + index + "] is NULL.");
				continue;
			}

			if (!Reflect.hasField(c, "id") || c.id == null)
			{
				trace("[CharacterSystem] ERROR: charDefs[" + index + "] missing 'id' field.");
				continue;
			}

			var name:String = c.id;

			var renderer = new CharacterRenderer(name);
			characters.set(name, renderer);
			group.add(renderer);
		}

		var count = 0;
		for (_ in characters.keys())
			count++;

		trace("[CharacterSystem] Loaded " + count + " character definitions.");
	}

	/**
	 * Show a character with placement support
	 * FIXED: Properly applies custom positions by setting absolute coordinates
	 */
	public function show(name:String, pose:String, position:String, transition:String, duration:Float, ?nodeId:String)
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Attempted to SHOW unknown character '" + name + "'");
			return;
		}

		// Set pose first (this positions sprites based on pose data)
		r.setPose(pose);
		trace('[CharacterSystem] Set pose "$pose" for $name');

		// Check for custom placement data
		var customPosition:Null<PlacementData> = null;
		if (nodeId != null)
		{
			// Apply placements for this node first
			placementManager.applyNode(nodeId);
			customPosition = placementManager.getPosition(name);
			
			if (customPosition != null)
			{
				trace('[CharacterSystem] Found custom placement for $name at node $nodeId');
			}
			else
			{
				trace('[CharacterSystem] No custom placement for $name at node $nodeId');
			}
		}

		if (customPosition != null)
		{
			// Use custom placement - set ABSOLUTE position
			trace('[CharacterSystem] ✓ Using CUSTOM placement for $name: (${customPosition.x}, ${customPosition.y}) slot=${customPosition.slot}');
			
			// FIXED: Use setAbsolutePosition instead of adding offsets
			r.setAbsolutePosition(customPosition.x, customPosition.y);
			r.currentPosition = customPosition.slot;
		}
		else
		{
			// Use default slot-based positioning
			trace('[CharacterSystem] Using DEFAULT slot positioning for $name: $position');
			r.setPositionKeyword(position);
		}

		// Apply transition
		if (transition != null && transition != "")
		{
			trace('[CharacterSystem] Applying transition: $transition (duration: $duration)');
			r.playTransition(transition, duration);
		}
	}

	public function hide(name:String, transition:String, duration:Float)
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Attempted to HIDE unknown character '" + name + "'");
			return;
		}

		r.hide();
		
		// Remove from placement tracking
		placementManager.removeCharacter(name);
	}

	public function emphasizeCharacter(name:String):Void
	{
		// Deemphasize all characters first
		for (charName in characters.keys())
		{
			var r = characters.get(charName);
			if (r != null)
				r.deemphasize();
		}

		// Emphasize the active speaker
		var r = characters.get(name);
		if (r != null)
			r.emphasize();
		else
			trace("[CharacterSystem] Cannot emphasize unknown character '" + name + "'");
	}

	public function deemphasizeAll():Void
	{
		// Reset all characters to normal state
		for (charName in characters.keys())
		{
			var r = characters.get(charName);
			if (r != null)
			{
				for (spr in r.layers)
				{
					if (spr.visible)
					{
						spr.scale.set(r.config.scale, r.config.scale);
						spr.alpha = 1.0;
					}
				}
			}
		}
	}
	
	public function resetPlacements():Void
	{
		placementManager.reset();
	}
	
	// ========================================================================
	// RHYTHM GAME INTEGRATION
	// ========================================================================
	
	/**
	 * Play an animation (rhythm game wrapper for setPose)
	 * This allows the rhythm system to trigger character animations
	 * 
	 * @param name Character ID
	 * @param animName Animation/pose name (e.g., "singLEFT", "singDOWN", "idle", "miss")
	 */
	public function playAnimation(name:String, animName:String):Void
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Cannot play animation for unknown character '" + name + "'");
			return;
		}
		
		r.setPose(animName);
	}
	
	/**
	 * Enable/disable animation looping for hold notes
	 * In rhythm gameplay, hold notes should keep the sing animation playing
	 * 
	 * @param name Character ID
	 * @param looping Whether to loop the current animation
	 */
	public function setLooping(name:String, looping:Bool):Void
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Cannot set looping for unknown character '" + name + "'");
			return;
		}
		
		r.isLooping = looping;
		trace('[CharacterSystem] Set looping=${looping} for $name');
	}
	
	/**
	 * Check if a character has a specific pose
	 * Useful for fallback behavior (e.g., if "miss" doesn't exist, use "idle")
	 * 
	 * @param name Character ID
	 * @param pose Pose name
	 * @return True if pose exists
	 */
	public function hasPose(name:String, pose:String):Bool
	{
		var r = characters.get(name);
		if (r == null) return false;
		
		return r.poses.exists(pose);
	}
}
