package rhythm;

import flixel.FlxG;
import flixel.FlxState;
import openfl.Assets;
import rhythm.ArrowRenderer;
import rhythm.CharacterAnimationBridge;
import rhythm.ChartData;
import rhythm.ChartHandler;
import rhythm.Conductor;
import rhythm.JudgementSystem.HitRating;
import rhythm.JudgementSystem;
import rhythm.Note;
import rhythm.NoteHandler;

/**
 * RhythmState
 * ===========
 * Main gameplay state for the rhythm engine.
 *
 * Data is injected BEFORE create() by RhythmBridge.
 * This keeps the state reusable and decoupled.
 */
class RhythmState extends FlxState
{
    // --------------------------------------------------
    // Injected by RhythmBridge
    // --------------------------------------------------

    public var song:String;
    public var chartPath:String;
    public var onComplete:Dynamic; // RhythmResult -> Void (kept loose for now)

    // --------------------------------------------------
    // Core systems
    // --------------------------------------------------

    private var conductor:Conductor;
    private var chartHandler:ChartHandler;
    private var judgement:JudgementSystem;
    private var noteHandler:NoteHandler;

    // --------------------------------------------------
    // Presentation systems
    // --------------------------------------------------

    private var arrowRenderer:ArrowRenderer;
    private var characterBridge:CharacterAnimationBridge;

    // --------------------------------------------------
    // Lifecycle
    // --------------------------------------------------

    override public function create():Void
    {
        super.create();

        // --------------------------------------------------
        // Validation
        // --------------------------------------------------

        if (chartPath == null)
            throw "RhythmState started without chartPath";

        // --------------------------------------------------
        // Load chart
        // --------------------------------------------------

        var chart:ChartData = cast haxe.Json.parse(
            Assets.getText(chartPath)
        );

        // --------------------------------------------------
        // Load music
        // --------------------------------------------------

        FlxG.sound.playMusic(
            'assets/music/${chart.song.song}.ogg',
            1.0,
            false
        );

        // --------------------------------------------------
        // Initialize core systems
        // --------------------------------------------------

        conductor = new Conductor(chart.song.bpm, chart.song.offset);
        judgement = new JudgementSystem();
        chartHandler = new ChartHandler(chart, conductor);
        noteHandler = new NoteHandler(chartHandler, conductor, judgement);

        // --------------------------------------------------
        // Initialize presentation systems
        // --------------------------------------------------

        arrowRenderer = new ArrowRenderer();
        characterBridge = new CharacterAnimationBridge(conductor);

        add(arrowRenderer);
        add(characterBridge);

        // --------------------------------------------------
        // Event wiring
        // --------------------------------------------------

        noteHandler.onNoteSpawn.add(onNoteSpawn);
        noteHandler.onNoteHit.add(onNoteHit);
        noteHandler.onNoteMiss.add(onNoteMiss);
        noteHandler.onGhostTap.add(onGhostTap);

        // --------------------------------------------------
        // Start timing AFTER music begins
        // --------------------------------------------------

        conductor.start();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        // --------------------------------------------------
        // Authoritative update order
        // --------------------------------------------------

        conductor.update();
        noteHandler.update();

        // --------------------------------------------------
        // Input forwarding (event-based)
        // --------------------------------------------------

        handleInput();

        // --------------------------------------------------
        // Song completion check (simple for now)
        // --------------------------------------------------

        if (FlxG.sound.music != null && !FlxG.sound.music.playing)
        {
            finishSong();
        }
    }

    // --------------------------------------------------
    // Input handling
    // --------------------------------------------------

    private function handleInput():Void
    {
        // Input lane mapping (0..playerLaneCount-1)
        // These values are passed as inputLane indices, NOT global lane indices
        // TODO: Make this data-driven to support variable playerLaneCount
        if (FlxG.keys.justPressed.A) noteHandler.onKeyPress(0);
        if (FlxG.keys.justPressed.S) noteHandler.onKeyPress(1);
        if (FlxG.keys.justPressed.D) noteHandler.onKeyPress(2);
        if (FlxG.keys.justPressed.F) noteHandler.onKeyPress(3);

        if (FlxG.keys.justReleased.A) noteHandler.onKeyRelease(0);
        if (FlxG.keys.justReleased.S) noteHandler.onKeyRelease(1);
        if (FlxG.keys.justReleased.D) noteHandler.onKeyRelease(2);
        if (FlxG.keys.justReleased.F) noteHandler.onKeyRelease(3);
    }

    // --------------------------------------------------
    // Gameplay → Presentation bridge
    // --------------------------------------------------

    private function onNoteSpawn(note:Note):Void
    {
        arrowRenderer.spawnNote(note);
    }

    private function onNoteHit(note:Note, rating:HitRating):Void
    {
        arrowRenderer.onNoteHit(note, rating);
        characterBridge.onNoteHit(note, rating);
    }

    private function onNoteMiss(note:Note):Void
    {
        arrowRenderer.onNoteMiss(note);
        characterBridge.onNoteMiss(note);
    }

    private function onGhostTap(lane:Int):Void
    {
        arrowRenderer.onGhostTap(lane);
    }

    // --------------------------------------------------
    // Completion
    // --------------------------------------------------

    private function finishSong():Void
    {
        trace("[RhythmState] Song complete");

        if (onComplete != null)
        {
            // Stub result for now — scoring comes later
            onComplete({
                score: 0,
                combo: 0,
                accuracy: 0.0,
                health: 1.0,
                completed: true
            });
        }
    }
}
