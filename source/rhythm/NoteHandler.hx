package rhythm;

import flixel.util.FlxSignal;
import flixel.FlxG;
import rhythm.Note;
import rhythm.ChartData;
import rhythm.JudgementSystem;
import rhythm.Conductor;

/**
 * NoteHandler - Active note management and input handling
 */
class NoteHandler {
    private var activeNotes:Array<Note>;
    private var conductor:Conductor;
    private var judgement:JudgementSystem;
    
    public var onNoteHit:FlxTypedSignal<Note->HitRating->Void>;
    public var onNoteMiss:FlxTypedSignal<Note->Void>;
    public var onNPCNote:FlxTypedSignal<Int->Int->Bool->Void>;
    public var onHoldReleased:FlxTypedSignal<Note->Float->Void>;
    
    private var keysHeld:Map<Int, Bool>;
    
    public function new(conductor:Conductor, judgement:JudgementSystem) {
        this.conductor = conductor;
        this.judgement = judgement;
        this.activeNotes = [];
        this.keysHeld = new Map();
        
        this.onNoteHit = new FlxTypedSignal();
        this.onNoteMiss = new FlxTypedSignal();
        this.onNPCNote = new FlxTypedSignal();
        this.onHoldReleased = new FlxTypedSignal();
    }
    
    public function spawnNote(chartNote:ChartNote):Note {
        var note = new Note(chartNote);
        activeNotes.push(note);
        return note;
    }
    
    public function update():Void {
        var currentTime = conductor.songPosition * 1000;
        
        // Safety check - prevent infinite loops
        var startTime = haxe.Timer.stamp();
        
        try {
            processNPCNotes(currentTime);
            cullMissedNotes(currentTime);
            updateHolds(currentTime);
            cullCompletedHolds(currentTime);
        } catch (e:Dynamic) {
            trace('ERROR in NoteHandler.update: ${e}');
        }
        
        // Check if update took too long
        var elapsed = haxe.Timer.stamp() - startTime;
        if (elapsed > 0.1) {
            trace('WARNING: NoteHandler.update took ${elapsed}s - possible hang');
        }
    }
    
    private function processNPCNotes(currentTime:Float):Void {
        for (note in activeNotes) {
            if (!note.chartNote.isPlayer && !note.processed) {
                if (currentTime >= note.time) {
                    note.processed = true;
                    
                    onNPCNote.dispatch(
                        note.chartNote.singerIndex,
                        note.chartNote.poseIndex,
                        note.isHold
                    );
                }
            }
        }
    }
    
    private function cullMissedNotes(currentTime:Float):Void {
        var missedNotes = [];
        var hitWindow = judgement.getHitWindow() * 1000;
        
        for (note in activeNotes) {
            // Only cull unhit player notes
            if (note.chartNote.isPlayer && !note.hit) {
                if (currentTime > note.time + hitWindow) {
                    missedNotes.push(note);
                }
            }
        }
        
        for (note in missedNotes) {
            activeNotes.remove(note);
            onNoteMiss.dispatch(note);
        }
    }
    
    private function updateHolds(currentTime:Float):Void {
        for (note in activeNotes) {
            // Only process holds that have been hit but not released
            if (note.isHold && note.hit && !note.released) {
                var keyHeld = keysHeld.exists(note.lane) && keysHeld.get(note.lane);
                
                if (!keyHeld) {
                    // Key was released
                    note.released = true;
                    
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
     * NEW: Cull hold notes that have completed
     * This removes holds that were held to completion
     */
    private function cullCompletedHolds(currentTime:Float):Void {
        var completedHolds = [];
        
        for (note in activeNotes) {
            if (note.isHold && note.hit) {
                // If hold is released OR past its end time, it's complete
                var holdEndTime = note.time + note.length;
                
                if (note.released || currentTime > holdEndTime + 500) {
                    completedHolds.push(note);
                }
            }
        }
        
        for (note in completedHolds) {
            activeNotes.remove(note);
            trace('Culled completed hold note at ${note.time}ms');
        }
    }
    
    public function onKeyPress(lane:Int):Void {
        keysHeld.set(lane, true);
        
        var closestNote = findClosestPlayerNote(lane, conductor.songPosition * 1000);
        
        if (closestNote != null) {
            var hitTime = conductor.songPosition * 1000;
            var targetTime = closestNote.time;
            var difference = (hitTime - targetTime) / 1000;
            
            var rating = judgement.judge(difference);
            
            if (rating != MISS) {
                closestNote.hit = true;
                onNoteHit.dispatch(closestNote, rating);
                
                trace('Hit note at ${closestNote.time}ms (lane ${lane}) - ${rating}');
            }
        }
    }
    
    public function onKeyRelease(lane:Int):Void {
        keysHeld.set(lane, false);
    }
    
    private function findClosestPlayerNote(lane:Int, position:Float):Note {
        var hitWindow = judgement.getHitWindow() * 1000;
        var closest:Note = null;
        var bestDiff = Math.POSITIVE_INFINITY;
        
        for (note in activeNotes) {
            if (!note.chartNote.isPlayer) continue;
            if (note.lane != lane || note.hit) continue;
            
            var diff = Math.abs(note.time - position);
            if (diff < hitWindow && diff < bestDiff) {
                closest = note;
                bestDiff = diff;
            }
        }
        
        return closest;
    }
    
    public function clear():Void {
        activeNotes = [];
        keysHeld.clear();
    }
    
    public function getActiveCount():Int {
        return activeNotes.length;
    }
    
    /**
     * NEW: Get detailed active note counts for debugging
     */
    public function getActiveCountsByType():{player:Int, npc:Int, holds:Int} {
        var player = 0;
        var npc = 0;
        var holds = 0;
        
        for (note in activeNotes) {
            if (note.chartNote.isPlayer) {
                player++;
                if (note.isHold) holds++;
            } else {
                npc++;
            }
        }
        
        return {player: player, npc: npc, holds: holds};
    }
}
