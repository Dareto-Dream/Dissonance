package rhythm;

import core.rendering.CharacterSystem;
import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import rhythm.*;
import rhythm.JudgementSystem.HitRating;

/**
 * RhythmState - Main rhythm game state
 */
class RhythmState extends FlxState {
    private var conductor:Conductor;
    private var chartHandler:ChartHandler;
    private var noteHandler:NoteHandler;
    private var judgement:JudgementSystem;
    private var renderer:ArrowRenderer;
    private var animBridge:CharacterAnimationBridge;
    
    private var characterSystem:CharacterSystem;
    
    private var chartPath:String;
    private var scrollSpeed:Float = 400;
    private var spawnTime:Float = 2000;
    
    private var keyBindings:Array<FlxKey> = [
        FlxKey.A, FlxKey.S, FlxKey.W, FlxKey.D
    ];
    
    private var score:Int = 0;
    private var combo:Int = 0;
    private var health:Float = 1.0;
    private var songStarted:Bool = false;
    
    private var allNotesSpawned:Bool = false;
    private var songEndTimer:Float = 0;
    private var songEndDelay:Float = 2.0;
    
    public var onSongComplete:Void->Void = null;
    
    private var scoreText:FlxText;
    private var comboText:FlxText;
    private var debugText:FlxText;
    private var detailedDebugText:FlxText;
    private var endText:FlxText;
    
    // Safety tracking
    private var lastUpdateTime:Float = 0;
    private var hangDetected:Bool = false;
    
    public function new(chartPath:String, characterSystem:CharacterSystem, ?onComplete:Void->Void) {
        super();
        this.chartPath = chartPath;
        this.characterSystem = characterSystem;
        this.onSongComplete = onComplete;
    }
    
    override public function create():Void {
        super.create();

        characterSystem.enableRhythmMode();
        
        bgColor = FlxColor.fromRGB(20, 20, 30);
        
        chartHandler = new ChartHandler(chartPath);
        conductor = new Conductor(chartHandler.getBPM(), chartHandler.getOffset());
        judgement = new JudgementSystem();
        noteHandler = new NoteHandler(conductor, judgement);
        
        noteHandler.onNoteHit.add(onNoteHit);
        noteHandler.onNoteMiss.add(onNoteMiss);
        noteHandler.onNPCNote.add(onNPCNote);
        noteHandler.onHoldReleased.add(onHoldReleased);
        
        var centerX = FlxG.width / 2;
        var centerY = FlxG.height / 2;
        var radius = 200;
        renderer = new ArrowRenderer(4, centerX, centerY, radius);
        renderer.conductor = conductor;
        renderer.scrollSpeed = scrollSpeed;
        add(renderer);
        
        animBridge = new CharacterAnimationBridge(
            characterSystem,
            chartHandler.getPlayer(),
            chartHandler.getSingers()
        );
        
        createUI();
        startSong();
        
        lastUpdateTime = haxe.Timer.stamp();
    }
    
    private function createUI():Void {
        scoreText = new FlxText(10, 10, 200, "Score: 0");
        scoreText.setFormat(null, 20, FlxColor.WHITE);
        add(scoreText);
        
        comboText = new FlxText(10, 40, 200, "");
        comboText.setFormat(null, 16, FlxColor.YELLOW);
        add(comboText);
        
        debugText = new FlxText(10, FlxG.height - 60, 700, "");
        debugText.setFormat(null, 12, FlxColor.LIME);
        add(debugText);
        
        detailedDebugText = new FlxText(10, FlxG.height - 30, 700, "");
        detailedDebugText.setFormat(null, 10, FlxColor.CYAN);
        add(detailedDebugText);
        
        endText = new FlxText(0, FlxG.height / 2 - 50, FlxG.width, "");
        endText.setFormat(null, 32, FlxColor.WHITE, "center");
        endText.visible = false;
        add(endText);
    }
    
    private function startSong():Void {
        var musicPath = 'assets/music/${chartHandler.getSongName()}.ogg';
        
        try {
            FlxG.sound.playMusic(musicPath, 1.0, false);
            conductor.start(FlxG.sound.music.time);
            songStarted = true;
            trace('Song started: ${chartHandler.getSongName()} at ${chartHandler.getBPM()} BPM');
            trace('Total notes in chart: ${chartHandler.getTotalNoteCount()}');
        } catch (e:Dynamic) {
            trace('WARNING: Could not load music at ${musicPath}: ${e}');
            trace('Continuing without music for testing...');
            songStarted = true;
        }
    }
    
    override public function update(elapsed:Float):Void {
        // Hang detection
        var currentTime = haxe.Timer.stamp();
        var timeSinceLastUpdate = currentTime - lastUpdateTime;
        
        if (timeSinceLastUpdate > 1.0 && !hangDetected) {
            trace('WARNING: Long frame detected! ${timeSinceLastUpdate}s');
            hangDetected = true;
        }
        lastUpdateTime = currentTime;
        
        super.update(elapsed);
        
        if (!songStarted) return;
        
        // Update systems with try-catch for safety
        try {
            conductor.update();
            spawnNotes();
            handleInput();
            noteHandler.update();
            updateDebugInfo();
            checkSongEnd(elapsed);
        } catch (e:Dynamic) {
            trace('CRITICAL ERROR in update: ${e}');
            trace('Song position: ${conductor.songPosition * 1000}ms');
            exitToVN(); // Emergency exit
        }
        
        if (FlxG.keys.justPressed.ESCAPE) {
            trace('Manual exit');
            exitToVN();
        }
    }
    
    private function spawnNotes():Void {
        var songPosMs = conductor.songPosition * 1000;
        var newNotes = chartHandler.getNotesToSpawn(songPosMs, spawnTime);
        
        if (newNotes.length > 0) {
            trace('Spawning ${newNotes.length} notes at ${songPosMs}ms');
        }
        
        if (newNotes.length == 0 && !allNotesSpawned) {
            var hasMoreNotes = chartHandler.hasMoreNotes();
            if (!hasMoreNotes) {
                allNotesSpawned = true;
                trace('All notes spawned at ${songPosMs}ms (${chartHandler.getCurrentNoteIndex()}/${chartHandler.getTotalNoteCount()})');
            }
        }
        
        for (chartNote in newNotes) {
            var note = noteHandler.spawnNote(chartNote);
            
            if (chartNote.isPlayer) {
                renderer.addNote(note);
            }
        }
    }
    
    private function handleInput():Void {
        for (lane in 0...keyBindings.length) {
            var key = keyBindings[lane];
            
            if (FlxG.keys.checkStatus(key, JUST_PRESSED)) {
                noteHandler.onKeyPress(lane);
            }
            
            if (FlxG.keys.checkStatus(key, JUST_RELEASED)) {
                noteHandler.onKeyRelease(lane);
            }
        }
    }
    
    private function updateDebugInfo():Void {
        var songPosMs = Std.int(conductor.songPosition * 1000);
        var activeNotes = noteHandler.getActiveCount();
        var musicTime = FlxG.sound.music != null ? Std.int(FlxG.sound.music.time) : 0;
        
        debugText.text = 'Time: ${songPosMs}ms | Music: ${musicTime}ms | Notes: ${activeNotes} | Health: ${Std.int(health * 100)}%';
        
        if (allNotesSpawned) {
            debugText.text += ' | Ending in: ${Math.ceil(Math.max(0, songEndDelay - songEndTimer))}s';
        }
        
        // Detailed breakdown
        var counts = noteHandler.getActiveCountsByType();
        detailedDebugText.text = 'Player: ${counts.player} | NPC: ${counts.npc} | Holds: ${counts.holds} | Chart: ${chartHandler.getCurrentNoteIndex()}/${chartHandler.getTotalNoteCount()}';
    }
    
    private function onNoteHit(note:Note, rating:HitRating):Void {
        var points = judgement.getScoreForRating(rating);
        score += points;
        combo++;
        
        scoreText.text = 'Score: ${score}';
        comboText.text = combo > 0 ? 'Combo: ${combo}' : '';
        
        renderer.playHitAnimation(note.lane, rating);
        animBridge.onPlayerNoteHit(note.lane, note.isHold);
        
        health = Math.min(1.0, health + 0.02);
        
        // Only remove regular notes immediately
        // Hold notes stay active until released
        if (!note.isHold) {
            renderer.removeNote(note);
        }
    }
    
    private function onNoteMiss(note:Note):Void {
        combo = 0;
        comboText.text = '';
        
        animBridge.onPlayerNoteMiss(note.lane);
        
        health = Math.max(0, health - 0.05);
        
        renderer.removeNote(note);
        
        if (health <= 0) {
            trace('Game Over!');
            showGameOver();
        }
    }
    
    private function onNPCNote(singerIndex:Int, poseIndex:Int, isHold:Bool):Void {
        animBridge.onNPCNote(singerIndex, poseIndex, isHold);
    }
    
    private function onHoldReleased(note:Note, accuracy:Float):Void {
        animBridge.onPlayerNoteRelease();
        
        if (accuracy > 0.9) {
            score += 50;
            scoreText.text = 'Score: ${score}';
        }
        
        // Remove hold note visual when released
        renderer.removeNote(note);
        
        trace('Hold released at ${note.time}ms with accuracy ${accuracy}');
    }
    
    private function checkSongEnd(elapsed:Float):Void {
        if (allNotesSpawned) {
            var activeNotes = noteHandler.getActiveCount();
            
            if (activeNotes == 0) {
                songEndTimer += elapsed;
                
                if (songEndTimer >= songEndDelay) {
                    trace('Song complete - all notes finished');
                    finishSong();
                    return;
                }
            } else {
                songEndTimer = 0;
            }
        }
        
        if (FlxG.sound.music != null && !FlxG.sound.music.playing) {
            songEndTimer += elapsed;
            
            if (songEndTimer >= 1.0) {
                trace('Song complete - music ended');
                finishSong();
            }
        }
    }
    
    private function showGameOver():Void {
        endText.text = "GAME OVER\nFinal Score: " + score;
        endText.visible = true;
        
        haxe.Timer.delay(() -> {
            exitToVN();
        }, 2000);
    }
    
    private function finishSong():Void {
        endText.text = "SONG COMPLETE!\nScore: " + score + "\nCombo: " + combo;
        endText.visible = true;
        
        trace('Song finished! Final Score: ${score}');
        
        haxe.Timer.delay(() -> {
            exitToVN();
        }, 2000);
    }
    
    private function exitToVN():Void {
        trace('Exiting to VN...');
        
        if (FlxG.sound.music != null) {
            FlxG.sound.music.stop();
        }
        
        characterSystem.disableRhythmMode();
        animBridge.resetAll();
        
        if (onSongComplete != null) {
            onSongComplete();
        } else {
            trace('No callback provided, returning to blank state');
            FlxG.switchState(new FlxState());
        }
    }
}
