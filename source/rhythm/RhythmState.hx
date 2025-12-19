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
 * 
 * This is the orchestrator that brings all systems together.
 * It manages the lifecycle of a rhythm game session.
 * 
 * Key responsibilities:
 * - Initialize all systems
 * - Load chart and music
 * - Handle input and map to lanes
 * - Update all systems every frame
 * - Manage score and combo
 * - Handle pause and completion
 * 
 * Usage:
 *   FlxG.switchState(new RhythmState("assets/data/charts/song.json", characterSystem));
 */
class RhythmState extends FlxState {
    // Core systems
    private var conductor:Conductor;
    private var chartHandler:ChartHandler;
    private var noteHandler:NoteHandler;
    private var judgement:JudgementSystem;
    private var renderer:ArrowRenderer;
    private var animBridge:CharacterAnimationBridge;
    
    // Reference to VN system
    private var characterSystem:CharacterSystem;
    
    // Configuration
    private var chartPath:String;
    private var scrollSpeed:Float = 400; // Pixels per second
    private var spawnTime:Float = 2000; // Milliseconds ahead to spawn
    
    // Input mapping (4-lane default)
    private var keyBindings:Array<FlxKey> = [
        FlxKey.A,     // Lane 0 (left)
        FlxKey.S,     // Lane 1 (down)
        FlxKey.W,     // Lane 2 (up)
        FlxKey.D      // Lane 3 (right)
    ];
    
    // Gameplay state
    private var score:Int = 0;
    private var combo:Int = 0;
    private var health:Float = 1.0;
    private var songStarted:Bool = false;
    
    // UI
    private var scoreText:FlxText;
    private var comboText:FlxText;
    
    /**
     * Constructor
     * @param chartPath Path to chart JSON file
     * @param characterSystem Reference to VN character system
     */
    public function new(chartPath:String, characterSystem:CharacterSystem) {
        super();
        this.chartPath = chartPath;
        this.characterSystem = characterSystem;
    }
    
    /**
     * Create - Initialize everything
     */
    override public function create():Void {
        super.create();
        
        // Set background color
        bgColor = FlxColor.fromRGB(20, 20, 30);
        
        // Load chart
        chartHandler = new ChartHandler(chartPath);
        
        // Initialize conductor
        conductor = new Conductor(chartHandler.getBPM(), chartHandler.getOffset());
        
        // Initialize judgement system
        judgement = new JudgementSystem();
        
        // Initialize note handler
        noteHandler = new NoteHandler(conductor, judgement);
        
        // Connect events
        noteHandler.onNoteHit.add(onNoteHit);
        noteHandler.onNoteMiss.add(onNoteMiss);
        noteHandler.onNPCNote.add(onNPCNote);
        noteHandler.onHoldReleased.add(onHoldReleased);
        
        // Initialize renderer (circle in center of screen)
        var centerX = FlxG.width / 2;
        var centerY = FlxG.height / 2;
        var radius = 200;
        renderer = new ArrowRenderer(4, centerX, centerY, radius);
        add(renderer);
        
        // Store conductor reference in renderer for updates
        Reflect.setField(renderer, "conductor", conductor);
        
        // Initialize animation bridge
        animBridge = new CharacterAnimationBridge(
            characterSystem,
            chartHandler.getPlayer(),
            chartHandler.getSingers()
        );
        
        // Create UI
        createUI();
        
        // Start music
        startSong();
    }
    
    /**
     * Create UI elements
     */
    private function createUI():Void {
        // Score display
        scoreText = new FlxText(10, 10, 200, "Score: 0");
        scoreText.setFormat(null, 20, FlxColor.WHITE);
        add(scoreText);
        
        // Combo display
        comboText = new FlxText(10, 40, 200, "");
        comboText.setFormat(null, 16, FlxColor.YELLOW);
        add(comboText);
    }
    
    /**
     * Start the song
     */
    private function startSong():Void {
        // Load and play music
        var musicPath = 'assets/music/${chartHandler.getSongName()}.ogg';
        
        try {
            FlxG.sound.playMusic(musicPath, 1.0);
            conductor.start(FlxG.sound.music.time);
            songStarted = true;
            trace('Song started: ${chartHandler.getSongName()}');
        } catch (e:Dynamic) {
            trace('ERROR: Could not load music at ${musicPath}: ${e}');
            // Continue without music for testing
        }
    }
    
    /**
     * Main update loop
     */
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        if (!songStarted) return;
        
        // Update conductor (timing authority)
        conductor.update();
        
        // Spawn new notes
        spawnNotes();
        
        // Handle input
        handleInput();
        
        // Update note handler
        noteHandler.update();
        
        // Update note visuals
        updateNoteVisuals();
        
        // Check for song end
        checkSongEnd();
        
        // ESC to quit
        if (FlxG.keys.justPressed.ESCAPE) {
            exitToVN();
        }
    }
    
    /**
     * Spawn notes that need to appear
     */
    private function spawnNotes():Void {
        var songPosMs = conductor.songPosition * 1000;
        var newNotes = chartHandler.getNotesToSpawn(songPosMs, spawnTime);
        
        for (chartNote in newNotes) {
            var note = noteHandler.spawnNote(chartNote);
            
            // Only render player notes
            if (chartNote.isPlayer) {
                renderer.addNote(note);
            }
        }
    }
    
    /**
     * Handle player input
     */
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
    
    /**
     * Update note visual positions
     * CRITICAL: Pass song position, not frame time
     */
    private function updateNoteVisuals():Void {
        var songPosMs = conductor.songPosition * 1000;
        
        // Renderer handles its own update, just make sure conductor is accessible
        // Note positions are calculated from song position inside NoteVisual
    }
    
    /**
     * Callback: Note was hit
     */
    private function onNoteHit(note:Note, rating:HitRating):Void {
        // Update score
        var points = judgement.getScoreForRating(rating);
        score += points;
        combo++;
        
        // Update UI
        scoreText.text = 'Score: ${score}';
        comboText.text = combo > 0 ? 'Combo: ${combo}' : '';
        
        // Play hit animation
        renderer.playHitAnimation(note.lane, rating);
        
        // Trigger character animation
        animBridge.onPlayerNoteHit(note.lane, note.isHold);
        
        // Health bonus
        health = Math.min(1.0, health + 0.02);
    }
    
    /**
     * Callback: Note was missed
     */
    private function onNoteMiss(note:Note):Void {
        combo = 0;
        comboText.text = '';
        
        // Trigger miss animation
        animBridge.onPlayerNoteMiss(note.lane);
        
        // Health penalty
        health = Math.max(0, health - 0.05);
        
        // Remove from renderer
        renderer.removeNote(note);
    }
    
    /**
     * Callback: NPC note triggered
     */
    private function onNPCNote(singerIndex:Int, poseIndex:Int, isHold:Bool):Void {
        animBridge.onNPCNote(singerIndex, poseIndex, isHold);
    }
    
    /**
     * Callback: Hold released
     */
    private function onHoldReleased(note:Note, accuracy:Float):Void {
        animBridge.onPlayerNoteRelease();
        
        // Bonus points for good hold accuracy
        if (accuracy > 0.9) {
            score += 50;
            scoreText.text = 'Score: ${score}';
        }
    }
    
    /**
     * Check if song has ended
     */
    private function checkSongEnd():Void {
        if (FlxG.sound.music != null && FlxG.sound.music.playing) {
            return;
        }
        
        // Song finished
        finishSong();
    }
    
    /**
     * Finish song and return to VN
     */
    private function finishSong():Void {
        trace('Song complete! Score: ${score}');
        exitToVN();
    }
    
    /**
     * Exit back to VN
     */
    private function exitToVN():Void {
        // Clean up
        if (FlxG.sound.music != null) {
            FlxG.sound.music.stop();
        }
        
        animBridge.resetAll();
        
        // Return to VN (this would call the callback in actual integration)
        // For now, just close state
        FlxG.switchState(()->new FlxState()); // Placeholder
    }
}