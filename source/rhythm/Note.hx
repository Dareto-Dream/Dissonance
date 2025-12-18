package rhythm;

import rhythm.ChartData;

/**
 * Note - Runtime note instance
 * 
 * This represents an active note in the game.
 * It's created from ChartNote data and tracks gameplay state.
 * 
 * Key fields:
 * - chartNote: The source data
 * - hit: Has the player hit this note?
 * - released: Has the player released a hold?
 * - processed: Has this NPC note triggered its animation?
 * 
 * Usage:
 *   var note = new Note(chartNote);
 *   if (!note.hit && songPosition > note.time + window) {
 *       // This note was missed
 *   }
 */
class Note {
    // Source chart data
    public var chartNote:ChartNote;
    
    // Convenient accessors (cached from chartNote)
    public var time:Float;
    public var lane:Int;
    public var length:Float;
    public var noteType:Int;
    public var isPlayer:Bool;
    
    // Gameplay state
    public var hit:Bool = false;
    public var released:Bool = false;
    public var processed:Bool = false; // For NPC notes
    
    // Hold note tracking
    public var isHold(get, never):Bool;
    
    /**
     * Constructor
     * @param chartNote The chart data for this note
     */
    public function new(chartNote:ChartNote) {
        this.chartNote = chartNote;
        
        // Cache commonly accessed fields
        this.time = chartNote.time;
        this.lane = chartNote.lane;
        this.length = chartNote.length;
        this.noteType = chartNote.noteType;
        this.isPlayer = chartNote.isPlayer;
    }
    
    /**
     * Check if this is a hold note
     */
    private function get_isHold():Bool {
        return length > 0;
    }
    
    /**
     * Get the end time of a hold note
     * Returns time + length (or just time if not a hold)
     */
    public function getEndTime():Float {
        return time + length;
    }
}