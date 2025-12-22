package rhythm;

import flixel.util.FlxSignal;
import flixel.FlxG;
import rhythm.Note;
import rhythm.ChartData;
import rhythm.JudgementSystem;
import rhythm.Conductor;

/**
 * NoteHandler - Active note management and input handling
 * 
 * This class manages all notes that are currently active in gameplay.
 * It handles player input, determines hits/misses, and triggers events.
 * 
 * Key responsibilities:
 * - Track active notes
 * - Handle key press/release
 * - Find closest hittable note
 * - Process NPC notes
 * - Cull missed notes
 * - Emit events for hits/misses
 * 
 * Usage:
 *   handler.spawnNote(chartNote);
 *   handler.onKeyPress(lane);
 *   handler.update();
 */
class NoteHandler {
    // Active notes in the game
    private var activeNotes:Array<Note>;
    
    // References to other systems
    private var conductor:Conductor;
    private var judgement:JudgementSystem;
    
    // Events
    public var onNoteHit:FlxTypedSignal<Note->HitRating->Void>;
    public var onNoteMiss:FlxTypedSignal<Note->Void>;
    public var onNPCNote:FlxTypedSignal<Int->Int->Bool->Void>; // singerIndex, poseIndex, isHold
    public var onHoldReleased:FlxTypedSignal<Note->Float->Void>; // note, accuracy
    
    // Key states for hold tracking
    private var keysHeld:Map<Int, Bool>;
    
    /**
     * Constructor
     * @param conductor Timing reference
     * @param judgement Hit evaluation system
     */
    public function new(conductor:Conductor, judgement:JudgementSystem) {
        this.conductor = conductor;
        this.judgement = judgement;
        this.activeNotes = [];
        this.keysHeld = new Map();
        
        // Initialize signals
        this.onNoteHit = new FlxTypedSignal();
        this.onNoteMiss = new FlxTypedSignal();
        this.onNPCNote = new FlxTypedSignal();
        this.onHoldReleased = new FlxTypedSignal();
    }
    
    /**
     * Spawn a new note into active gameplay
     * @param chartNote The chart data for this note
     * @return The created Note instance
     */
    public function spawnNote(chartNote:ChartNote):Note {
        var note = new Note(chartNote);
        activeNotes.push(note);
        return note;
    }
    
    /**
     * Update all active notes
     * Call this every frame
     */
    public function update():Void {
        var currentTime = conductor.songPosition * 1000; // Convert to ms
        
        // Process NPC notes
        processNPCNotes(currentTime);
        
        // Cull missed player notes
        cullMissedNotes(currentTime);
        
        // Update hold states
        updateHolds(currentTime);
    }
    
    /**
     * Process NPC notes that have reached their time
     * NPCs auto-hit at exact timing
     */
    private function processNPCNotes(currentTime:Float):Void {
        for (note in activeNotes) {
            if (!note.chartNote.isPlayer && !note.processed) {
                if (currentTime >= note.time) {
                    note.processed = true;
                    
                    // Trigger animation event
                    onNPCNote.dispatch(
                        note.chartNote.singerIndex,
                        note.chartNote.poseIndex,
                        note.isHold
                    );
                }
            }
        }
    }
    
    /**
     * Remove notes that were missed
     */
    private function cullMissedNotes(currentTime:Float):Void {
        var missedNotes = [];
        var hitWindow = judgement.getHitWindow() * 1000; // Convert to ms
        
        for (note in activeNotes) {
            if (note.chartNote.isPlayer && !note.hit) {
                if (currentTime > note.time + hitWindow) {
                    missedNotes.push(note);
                }
            }
        }
        
        // Remove and dispatch miss events
        for (note in missedNotes) {
            activeNotes.remove(note);
            onNoteMiss.dispatch(note);
        }
    }
    
    /**
     * Update hold note states
     * Check if player is still holding
     */
    private function updateHolds(currentTime:Float):Void {
        for (note in activeNotes) {
            if (note.isHold && note.hit && !note.released) {
                // Check if key is still held
                var keyHeld = keysHeld.exists(note.lane) && keysHeld.get(note.lane);
                
                if (!keyHeld) {
                    note.released = true;
                    
                    // Calculate hold accuracy
                    var holdEndTime = currentTime;
                    var perfectEnd = note.time + note.length;
                    var holdAccuracy = (holdEndTime >= perfectEnd) ? 1.0 : 
                                      (holdEndTime - note.time) / note.length;
                    
                    onHoldReleased.dispatch(note, holdAccuracy);
                }
            }
        }
    }
    
    /**
     * Handle key press for a lane
     * @param lane Lane index (0-based)
     */
    public function onKeyPress(lane:Int):Void {
        keysHeld.set(lane, true);
        
        var closestNote = findClosestPlayerNote(lane, conductor.songPosition * 1000);
        
        if (closestNote != null) {
            var hitTime = conductor.songPosition * 1000;
            var targetTime = closestNote.time;
            var difference = (hitTime - targetTime) / 1000; // Convert to seconds
            
            var rating = judgement.judge(difference);
            
            if (rating != MISS) {
                closestNote.hit = true;
                onNoteHit.dispatch(closestNote, rating);
            }
        }
    }
    
    /**
     * Handle key release for a lane
     * @param lane Lane index (0-based)
     */
    public function onKeyRelease(lane:Int):Void {
        keysHeld.set(lane, false);
    }
    
    /**
     * Find the closest hittable note in a lane
     * @param lane Lane to search
     * @param position Current song position (ms)
     * @return Closest note or null
     */
    private function findClosestPlayerNote(lane:Int, position:Float):Note {
        var hitWindow = judgement.getHitWindow() * 1000; // Convert to ms
        var closest:Note = null;
        var bestDiff = Math.POSITIVE_INFINITY;
        
        for (note in activeNotes) {
            // Skip non-player notes
            if (!note.chartNote.isPlayer) continue;
            
            // Skip wrong lane or already hit
            if (note.lane != lane || note.hit) continue;
            
            var diff = Math.abs(note.time - position);
            if (diff < hitWindow && diff < bestDiff) {
                closest = note;
                bestDiff = diff;
            }
        }
        
        return closest;
    }
    
    /**
     * Clear all active notes (for restarts)
     */
    public function clear():Void {
        activeNotes = [];
        keysHeld.clear();
    }
    
    /**
     * Get count of active notes (for debugging)
     */
    public function getActiveCount():Int {
        return activeNotes.length;
    }
}