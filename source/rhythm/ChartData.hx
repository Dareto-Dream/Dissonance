package rhythm;

/**
 * ChartData.hx - Type definitions for rhythm charts
 * 
 * This file defines the structure of chart data.
 * It matches the Psych-style JSON format with compact note arrays.
 * 
 * Note format:
 * - Player notes: [time_ms, lane, hold_ms, note_type]
 * - NPC notes: [time_ms, lane, hold_ms]
 */

/**
 * A single note after parsing
 * This is what the game actually uses (parsed from compact arrays)
 */
typedef ChartNote = {
    time:Float,              // Time in milliseconds
    lane:Int,                // Lane index (0-based)
    length:Float,            // Hold duration in ms (0 for tap)
    noteType:Int,            // 0=NORMAL, 1=SWING, 2=ORBIT, 3=GLITCH, 4=FORCED
    isPlayer:Bool,           // true if player note, false if NPC
    ?singerIndex:Int,        // NPC only: which singer (0-based)
    ?poseIndex:Int           // NPC only: which pose (0=left, 1=down, 2=up, 3=right)
}

/**
 * A section of the chart
 * Sections have ownership (player or NPCs) and contain notes
 */
typedef ChartSection = {
    sectionNotes:Array<Array<Dynamic>>,  // Raw note arrays from JSON
    mustHitSection:Bool,                  // true = player, false = NPCs
    ?playerLaneCount:Int,                 // How many lanes for player (if mustHitSection)
    lengthInSteps:Int,                    // Section length
    bpm:Float                             // BPM for this section
}

/**
 * The complete chart data structure
 * This is the root of the JSON file
 */
typedef ChartData = {
    song:String,              // Song identifier
    bpm:Float,                // Default BPM
    offset:Float,             // Audio offset in seconds
    player:String,            // Player character ID (always "mc")
    singers:Array<String>,    // NPC character IDs in order
    notes:Array<ChartSection> // All sections
}

/**
 * Note type constants
 * Use these instead of magic numbers
 */
class NoteType {
    public static inline var NORMAL:Int = 0;
    public static inline var SWING:Int = 1;
    public static inline var ORBIT:Int = 2;
    public static inline var GLITCH:Int = 3;
    public static inline var FORCED:Int = 4;
}

/**
 * Pose mapping for NPC notes
 * poseIndex % 4 maps to these
 */
class PoseType {
    public static inline var LEFT:Int = 0;
    public static inline var DOWN:Int = 1;
    public static inline var UP:Int = 2;
    public static inline var RIGHT:Int = 3;
    
    public static var NAMES:Array<String> = ["singLEFT", "singDOWN", "singUP", "singRIGHT"];
}