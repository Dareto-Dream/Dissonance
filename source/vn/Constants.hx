package vn;

/**
 * Constants - VN Engine Configuration and Constants
 * 
 * Centralized location for all VN engine constants including:
 * - Character placement slots and coordinates
 * - Screen dimensions
 * - Default values
 * - Configuration paths
 * 
 * Usage:
 *   var x = Constants.getSlotX("center");
 *   var path = Constants.CHARACTER_DEFS_PATH;
 */
class Constants
{
	// ========================================================================
	// FILE PATHS
	// ========================================================================
	
	/**
	 * Path to character definitions JSON
	 */
	public static inline var CHARACTER_DEFS_PATH:String = 
		"assets/data/characters/characters.json";
	
	// ========================================================================
	// SCREEN DIMENSIONS
	// ========================================================================
	
	/**
	 * Standard screen width
	 */
	public static inline var SCREEN_WIDTH:Int = 1280;
	
	/**
	 * Standard screen height
	 */
	public static inline var SCREEN_HEIGHT:Int = 720;
	
	// ========================================================================
	// CHARACTER PLACEMENT
	// ========================================================================
	
	/**
	 * Standard Y coordinate for character positioning
	 * Characters are positioned with their feet at the bottom of the screen
	 */
	public static inline var STANDARD_CHARACTER_Y:Float = 0;
	
	/**
	 * Slot positions as fractions of screen width.
	 * Negative fractions extend off-screen left; >1.0 off-screen right.
	 * Resolved against FlxG.width at runtime so all resolutions work.
	 */
	private static var SLOT_FRACTIONS:Map<String, Float> = [
		"far_left"     => -0.156,  // Off-screen left (slide in)
		"left"         =>  0.078,  // Left region
		"center_left"  =>  0.188,  // Left of center
		"center"       =>  0.500,  // Middle (default)
		"center_right" =>  0.813,  // Right of center
		"right"        =>  0.922,  // Right region
		"far_right"    =>  1.156   // Off-screen right (slide in)
	];

	/**
	 * Get X coordinate for a slot name, scaled to the current screen width.
	 * @param slot Slot name (e.g., "center", "left", "right")
	 * @return X coordinate, or center if slot not found
	 */
	public static function getSlotX(slot:String):Float
	{
		var w:Float = flixel.FlxG.width > 0 ? flixel.FlxG.width : 1280.0;
		if (SLOT_FRACTIONS.exists(slot))
			return SLOT_FRACTIONS.get(slot) * w;

		trace('[Constants] WARNING: Unknown slot "$slot", defaulting to center');
		return 0.5 * w;
	}
	
	/**
	 * Get standard Y coordinate for character placement
	 * @return Standard Y coordinate (always 0)
	 */
	public static inline function getSlotY():Float
	{
		return STANDARD_CHARACTER_Y;
	}
	
	/**
	 * Check if a slot name is valid
	 * @param slot Slot name to check
	 * @return True if slot exists
	 */
	public static function isValidSlot(slot:String):Bool
	{
		return SLOT_FRACTIONS.exists(slot);
	}

	/**
	 * Get all available slot names
	 * @return Array of slot names
	 */
	public static function getAllSlotNames():Array<String>
	{
		var names:Array<String> = [];
		for (key in SLOT_FRACTIONS.keys())
			names.push(key);
		return names;
	}

	/**
	 * Get slot name from X coordinate.
	 * Finds the closest slot to the given X position at the current resolution.
	 */
	public static function getSlotFromX(x:Float):String
	{
		var closestSlot:String = "center";
		var closestDistance:Float = Math.abs(x - getSlotX("center"));

		for (slot in SLOT_FRACTIONS.keys())
		{
			var distance = Math.abs(x - getSlotX(slot));
			if (distance < closestDistance)
			{
				closestDistance = distance;
				closestSlot = slot;
			}
		}

		return closestSlot;
	}
	
	// ========================================================================
	// DEFAULT VALUES
	// ========================================================================
	
	/**
	 * Default character pose name
	 */
	public static inline var DEFAULT_POSE:String = "neutral";
	
	/**
	 * Default transition duration in seconds
	 */
	public static inline var DEFAULT_TRANSITION_DURATION:Float = 0.4;
	
	/**
	 * Default fade duration in seconds
	 */
	public static inline var DEFAULT_FADE_DURATION:Float = 0.6;
	
	// ========================================================================
	// DIALOGUE SYSTEM
	// ========================================================================
	
	/**
	 * Default text speed for dialogue (characters per second)
	 */
	public static inline var DEFAULT_TEXT_SPEED:Float = 30.0;
	
	/**
	 * Default auto-advance delay in seconds
	 */
	public static inline var DEFAULT_AUTO_ADVANCE_DELAY:Float = 2.0;
	
	// ========================================================================
	// AUDIO SYSTEM
	// ========================================================================
	
	/**
	 * Default music volume
	 */
	public static inline var DEFAULT_MUSIC_VOLUME:Float = 0.7;
	
	/**
	 * Default sound effect volume
	 */
	public static inline var DEFAULT_SOUND_VOLUME:Float = 0.8;
	
	/**
	 * Default audio crossfade duration in seconds
	 */
	public static inline var DEFAULT_CROSSFADE_DURATION:Float = 2.0;
	
	// ========================================================================
	// INITIALIZATION
	// ========================================================================
	
	/**
	 * Initialize the constants
	 * Called automatically on first access
	 */
	public static function __init__():Void
	{
		// Map is initialized inline, nothing to do here
		// This function exists to ensure map is created before use
	}
}
