package rhythm;

import haxe.Json;
import openfl.Assets;
import rhythm.ChartData;

/**
 * ChartHandler - Chart loading and parsing
 * 
 * This class loads chart JSON files and parses them into usable data.
 * It handles validation, note parsing, and provides notes for spawning.
 * 
 * Key responsibilities:
 * - Load chart JSON
 * - Parse compact note arrays
 * - Validate lane ranges
 * - Resolve NPC lanes to singers
 * - Provide notes to spawn based on song position
 * 
 * Usage:
 *   var handler = new ChartHandler("assets/data/charts/song.json");
 *   var notes = handler.getNotesToSpawn(songPosition, spawnTime);
 */
class ChartHandler {
    // The parsed chart data
    private var chart:ChartData;
    
    // All notes parsed and sorted by time
    private var parsedNotes:Array<ChartNote>;
    
    // Current index in parsedNotes (for efficient spawning)
    private var noteIndex:Int = 0;
    
    /**
     * Constructor - loads and parses chart
     * @param chartPath Path to chart JSON file
     */
    public function new(chartPath:String) {
        loadChart(chartPath);
        parseAllNotes();
        validate();
    }
    
    /**
     * Load chart from JSON file
     * Wraps in the expected "song" structure if needed
     */
    private function loadChart(path:String):Void {
        try {
            var rawText = Assets.getText(path);
            var rawData:Dynamic = Json.parse(rawText);
            
            // Handle both {song: {...}} and direct {...} formats
            if (Reflect.hasField(rawData, "song")) {
                chart = rawData.song;
            } else {
                chart = rawData;
            }
            
            trace('Chart loaded: ${chart.song} (${chart.bpm} BPM)');
        } catch (e:Dynamic) {
            trace('ERROR: Failed to load chart at ${path}: ${e}');
            // Create minimal fallback chart
            chart = {
                song: "fallback",
                bpm: 120,
                offset: 0,
                player: "mc",
                singers: [],
                notes: []
            };
        }
    }
    
    /**
     * Parse all sections and notes
     * Converts compact arrays to typed objects
     */
    private function parseAllNotes():Void {
        parsedNotes = [];
        
        for (section in chart.notes) {
            if (section.mustHitSection) {
                parsePlayerSection(section);
            } else {
                parseNPCSection(section);
            }
        }
        
        // Sort all notes by time for efficient spawning
        parsedNotes.sort((a, b) -> Std.int(a.time - b.time));
        
        trace('Parsed ${parsedNotes.length} total notes');
    }
    
    /**
     * Parse a player section (mustHitSection = true)
     * Player notes use 4-element arrays: [time, lane, hold, type]
     */
    private function parsePlayerSection(section:ChartSection):Void {
        // Default to 4 lanes if not specified
        var laneCount = section.playerLaneCount != null ? section.playerLaneCount : 4;
        
        for (noteData in section.sectionNotes) {
            // Safely extract array elements
            var time:Float = noteData[0];
            var lane:Int = noteData[1];
            var hold:Float = noteData[2];
            var noteType:Int = noteData.length >= 4 ? noteData[3] : NoteType.NORMAL;
            
            // Validate lane range
            if (lane < 0 || lane >= laneCount) {
                trace('Warning: Invalid player lane ${lane} (max ${laneCount - 1}) at time ${time}');
                continue; // Skip invalid note
            }
            
            // Add parsed note
            parsedNotes.push({
                time: time,
                lane: lane,
                length: hold,
                noteType: noteType,
                isPlayer: true
            });
        }
    }
    
    /**
     * Parse an NPC section (mustHitSection = false)
     * NPC notes use 3-element arrays: [time, lane, hold]
     * Lane is resolved to singer + pose using division
     */
    private function parseNPCSection(section:ChartSection):Void {
        for (noteData in section.sectionNotes) {
            // Safely extract array elements
            var time:Float = noteData[0];
            var lane:Int = noteData[1];
            var hold:Float = noteData[2];
            // Ignore 4th element if present (safely)
            
            // Resolve to singer and pose
            // singerIndex = floor(lane / 4)
            // poseIndex = lane % 4
            var singerIndex = Math.floor(lane / 4);
            var poseIndex = lane % 4;
            
            // Validate singer exists
            if (singerIndex >= chart.singers.length) {
                trace('Warning: NPC lane ${lane} resolves to invalid singer ${singerIndex} at time ${time}');
                continue; // Skip invalid note
            }
            
            // Add parsed note
            parsedNotes.push({
                time: time,
                lane: lane,
                length: hold,
                noteType: NoteType.NORMAL, // Unused for NPCs
                isPlayer: false,
                singerIndex: singerIndex,
                poseIndex: poseIndex
            });
        }
    }
    
    /**
     * Validate the chart structure
     * Logs warnings for potential issues
     */
    private function validate():Void {
        if (chart.player == null || chart.player == "") {
            trace('Warning: Chart missing player identifier');
        }
        
        if (chart.singers == null || chart.singers.length == 0) {
            trace('Warning: Chart has no NPC singers defined');
        }
        
        if (parsedNotes.length == 0) {
            trace('Warning: Chart has no notes');
        }
    }
    
    /**
     * Get notes that should spawn this frame
     * 
     * Call this every frame with current song position and spawn lead time.
     * Returns notes that need to be spawned now.
     * 
     * @param songPosition Current position in song (milliseconds)
     * @param spawnTime How far ahead to spawn notes (milliseconds)
     * @return Array of notes to spawn
     */
    public function getNotesToSpawn(songPosition:Float, spawnTime:Float):Array<ChartNote> {
        var result = [];
        var spawnThreshold = songPosition + spawnTime;
        
        // Iterate from current index forward
        while (noteIndex < parsedNotes.length) {
            var note = parsedNotes[noteIndex];
            
            if (note.time <= spawnThreshold) {
                result.push(note);
                noteIndex++;
            } else {
                // Notes are sorted, so we can stop here
                break;
            }
        }
        
        return result;
    }
    
    /**
     * Reset to beginning (for restarts)
     */
    public function reset():Void {
        noteIndex = 0;
    }
    
    // Getters for chart metadata
    public function getBPM():Float { return chart.bpm; }
    public function getOffset():Float { return chart.offset; }
    public function getSingers():Array<String> { return chart.singers; }
    public function getPlayer():String { return chart.player; }
    public function getSongName():String { return chart.song; }
}