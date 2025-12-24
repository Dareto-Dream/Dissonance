package rhythm;

import haxe.Json;
import openfl.Assets;
import rhythm.ChartData;

/**
 * ChartHandler - Chart loading and parsing
 */
class ChartHandler {
    private var chart:ChartData;
    private var parsedNotes:Array<ChartNote>;
    private var noteIndex:Int = 0;
    
    public function new(chartPath:String) {
        loadChart(chartPath);
        parseAllNotes();
        validate();
    }
    
    private function loadChart(path:String):Void {
        try {
            var rawText = Assets.getText(path);
            var rawData:Dynamic = Json.parse(rawText);
            
            if (Reflect.hasField(rawData, "song")) {
                chart = rawData.song;
            } else {
                chart = rawData;
            }
            
            trace('Chart loaded: ${chart.song} (${chart.bpm} BPM)');
        } catch (e:Dynamic) {
            trace('ERROR: Failed to load chart at ${path}: ${e}');
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
    
    private function parseAllNotes():Void {
        parsedNotes = [];
        
        for (section in chart.notes) {
            if (section.mustHitSection) {
                parsePlayerSection(section);
            } else {
                parseNPCSection(section);
            }
        }
        
        parsedNotes.sort((a, b) -> Std.int(a.time - b.time));
        
        trace('Parsed ${parsedNotes.length} total notes');
    }
    
    private function parsePlayerSection(section:ChartSection):Void {
        var laneCount = section.playerLaneCount != null ? section.playerLaneCount : 4;
        
        for (noteData in section.sectionNotes) {
            var time:Float = noteData[0];
            var lane:Int = noteData[1];
            var hold:Float = noteData[2];
            var noteType:Int = noteData.length >= 4 ? noteData[3] : NoteType.NORMAL;
            
            if (lane < 0 || lane >= laneCount) {
                trace('Warning: Invalid player lane ${lane} (max ${laneCount - 1}) at time ${time}');
                continue;
            }
            
            parsedNotes.push({
                time: time,
                lane: lane,
                length: hold,
                noteType: noteType,
                isPlayer: true
            });
        }
    }
    
    private function parseNPCSection(section:ChartSection):Void {
        for (noteData in section.sectionNotes) {
            var time:Float = noteData[0];
            var lane:Int = noteData[1];
            var hold:Float = noteData[2];
            
            var singerIndex = Math.floor(lane / 4);
            var poseIndex = lane % 4;
            
            if (singerIndex >= chart.singers.length) {
                trace('Warning: NPC lane ${lane} resolves to invalid singer ${singerIndex} at time ${time}');
                continue;
            }
            
            parsedNotes.push({
                time: time,
                lane: lane,
                length: hold,
                noteType: NoteType.NORMAL,
                isPlayer: false,
                singerIndex: singerIndex,
                poseIndex: poseIndex
            });
        }
    }
    
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
    
    public function getNotesToSpawn(songPosition:Float, spawnTime:Float):Array<ChartNote> {
        var result = [];
        var spawnThreshold = songPosition + spawnTime;
        
        while (noteIndex < parsedNotes.length) {
            var note = parsedNotes[noteIndex];
            
            if (note.time <= spawnThreshold) {
                result.push(note);
                noteIndex++;
            } else {
                break;
            }
        }
        
        return result;
    }
    
    /**
     * Check if there are more notes to spawn
     * @return true if more notes remain
     */
    public function hasMoreNotes():Bool {
        return noteIndex < parsedNotes.length;
    }
    
    /**
     * Get total note count
     */
    public function getTotalNoteCount():Int {
        return parsedNotes.length;
    }
    
    /**
     * Get current spawn index
     */
    public function getCurrentNoteIndex():Int {
        return noteIndex;
    }
    
    public function reset():Void {
        noteIndex = 0;
    }
    
    public function getBPM():Float { return chart.bpm; }
    public function getOffset():Float { return chart.offset; }
    public function getSingers():Array<String> { return chart.singers; }
    public function getPlayer():String { return chart.player; }
    public function getSongName():String { return chart.song; }
}
