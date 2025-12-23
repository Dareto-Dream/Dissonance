package core.rendering;

import core.scene.PlacementManager.PlacementData;
import core.scene.PlacementManager;
import flixel.group.FlxGroup;

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
	 * Show a character with hybrid placement support
	 * Supports both slot-based and custom coordinate positioning
	 */
	public function show(name:String, pose:String, transition:String, duration:Float, ?nodeId:String)
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Attempted to SHOW unknown character '" + name + "'");
			return;
		}

		// Try to get position from placement file
		var placementData:Null<PlacementData> = null;
		if (nodeId != null)
		{
			placementManager.applyNode(nodeId);
			placementData = placementManager.getPosition(name);
		}

		if (placementData != null)
		{
			// Check if custom coordinates provided
			if (placementData.x != null && placementData.y != null)
			{
				// Use custom coordinates
				trace('[CharacterSystem] Using CUSTOM placement for $name: (${placementData.x}, ${placementData.y})');
				r.setAbsolutePosition(placementData.x, placementData.y);
				
				// Store slot for reference if provided
				if (placementData.slot != null)
				{
					r.currentPosition = placementData.slot;
				}
			}
			else if (placementData.slot != null)
			{
				// Use slot-based positioning
				trace('[CharacterSystem] Using SLOT placement for $name: ${placementData.slot}');
				r.setPositionKeyword(placementData.slot);
			}
			else
			{
				// Placement data exists but is invalid
				trace('[CharacterSystem] WARNING: Invalid placement data for $name (no x/y or slot)');
				
				// Fall through to state persistence check below
				if (r.currentPosition != null && r.currentPosition != "")
				{
					trace('[CharacterSystem] $name keeping current position: ${r.currentPosition}');
				}
				else
				{
					trace('[CharacterSystem] $name defaulting to center');
					r.setPositionKeyword("center");
				}
			}
		}
		else
		{
			// No placement data for this node - use state persistence
			if (r.currentPosition != null && r.currentPosition != "")
			{
				// Character already has a position, keep it
				trace('[CharacterSystem] $name keeping current position: ${r.currentPosition}');
			}
			else
			{
				// First appearance, use default
				trace('[CharacterSystem] $name first appearance, using default center');
				r.setPositionKeyword("center");
			}
		}
		
		// Set pose AFTER positioning
		r.setPose(pose);
		trace('[CharacterSystem] Set pose "$pose" for $name');
		
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
				// Reset VN layers
				for (spr in r.vnLayers)
				{
					if (spr.visible)
					{
						spr.scale.set(r.config.scale, r.config.scale);
						spr.alpha = 1.0;
					}
				}
				
				// Reset rhythm layers
				for (spr in r.rhythmLayers)
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
	// ========================================================================
	// RHYTHM MODE MANAGEMENT
	// ========================================================================
	
	/**
	 * Enable rhythm mode for all characters
	 * Switches character rendering to use rhythm atlases with animations
	 */
	public function enableRhythmMode():Void
	{
		for (r in characters)
		{
			r.setRhythmMode(true);
		}
		trace("[CharacterSystem] Enabled rhythm mode for all characters");
	}
	
	/**
	 * Disable rhythm mode for all characters
	 * Returns character rendering to VN mode (static poses)
	 */
	public function disableRhythmMode():Void
	{
		for (r in characters)
		{
			r.setRhythmMode(false);
		}
		trace("[CharacterSystem] Disabled rhythm mode for all characters");
	}
}
