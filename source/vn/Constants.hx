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
	 * Slot coordinate definitions
	 * Maps slot names to X coordinates for character placement
	 * 
	 * Based on 1280x720 screen resolution:
	 * - center = 640 (middle of screen)
	 * - left/right = positioned in thirds
	 * - far_left/far_right = off-screen for slide-in effects
	 */
	private static var SLOT_POSITIONS:Map<String, Float> = [
		"far_left"     => -200.0,   // Off-screen left (slide in)
		"left"         => 100.0,    // Left third of screen
		"center_left"  => 240.0,    // Left of center
		"center"       => 640.0,    // Middle (default)
		"center_right" => 1040.0,   // Right of center
		"right"        => 1180.0,   // Right third of screen
		"far_right"    => 1480.0    // Off-screen right (slide in)
	];
	
	/**
	 * Get X coordinate for a slot name
	 * @param slot Slot name (e.g., "center", "left", "right")
	 * @return X coordinate, or center if slot not found
	 */
	public static function getSlotX(slot:String):Float
	{
		if (SLOT_POSITIONS.exists(slot))
		{
			return SLOT_POSITIONS.get(slot);
		}
		else
		{
			trace('[Constants] WARNING: Unknown slot "$slot", defaulting to center');
			return SLOT_POSITIONS.get("center");
		}
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
		return SLOT_POSITIONS.exists(slot);
	}
	
	/**
	 * Get all available slot names
	 * @return Array of slot names
	 */
	public static function getAllSlotNames():Array<String>
	{
		var names:Array<String> = [];
		for (key in SLOT_POSITIONS.keys())
		{
			names.push(key);
		}
		return names;
	}
	
	/**
	 * Get slot name from X coordinate
	 * Finds the closest slot to the given X position
	 * @param x X coordinate
	 * @return Closest slot name
	 */
	public static function getSlotFromX(x:Float):String
	{
		var closestSlot:String = "center";
		var closestDistance:Float = Math.abs(x - SLOT_POSITIONS.get("center"));
		
		for (slot in SLOT_POSITIONS.keys())
		{
			var slotX = SLOT_POSITIONS.get(slot);
			var distance = Math.abs(x - slotX);
			
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
