package rhythm;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import openfl.Assets;
import rhythm.ArrowRenderer;
import rhythm.CharacterAnimationBridge;
import rhythm.CharacterSpriteManager;
import rhythm.ChartData;
import rhythm.ChartHandler;
import rhythm.Conductor;
import rhythm.JudgementSystem.HitRating;
import rhythm.JudgementSystem;
import rhythm.Note;
import rhythm.NoteHandler;
import rhythm.NoteRenderer;

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
    public var returnStateFactory:Void->flixel.FlxState; // Factory to rebuild VN state after completion
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
    private var noteRenderer:NoteRenderer;
    private var characterSprites:CharacterSpriteManager;
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
        // Load background stage (if provided)
        // --------------------------------------------------

        var stageSprite = createStageSprite(chart.song.stage);
        if (stageSprite != null)
        {
            add(stageSprite);
        }

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
        noteRenderer = new NoteRenderer(conductor, arrowRenderer);
        
        // --------------------------------------------------
        // Initialize character sprites
        // --------------------------------------------------
        
        characterSprites = new CharacterSpriteManager();
        
        // NEW DESIGN: Load all unique characters from ALL sections
        // Collect unique character IDs from all section singers arrays
        var allCharacterIDs:Array<String> = [];
        
        for (section in chart.song.notes)
        {
            if (section.singers != null)
            {
                for (singerID in section.singers)
                {
                    if (!allCharacterIDs.contains(singerID))
                    {
                        allCharacterIDs.push(singerID);
                    }
                }
            }
        }
        
        trace('[RhythmState] Loading ${allCharacterIDs.length} unique characters');
        
        // Load and position each character
        for (i in 0...allCharacterIDs.length)
        {
            var characterID = allCharacterIDs[i];
            trace('[RhythmState] Loading character: ${characterID}');
            
            var sprite = characterSprites.loadCharacter(characterID);
            if (sprite != null)
            {
                // Apply position from character data
                var basePos = characterSprites.getBasePosition(characterID);
                
                // Offset positions for multiple characters (simple horizontal spacing)
                var xOffset = i * 100;
                sprite.setPosition(basePos.x + xOffset, basePos.y);
                trace('[RhythmState]   Positioned at: [${basePos.x + xOffset}, ${basePos.y}]');
                
                add(sprite);
            }
        }
        
        // Initialize animation bridge (with character sprite manager)
        characterBridge = new CharacterAnimationBridge(conductor, characterSprites);
        
        // Register all loaded characters with animation bridge
        for (characterID in allCharacterIDs)
        {
            characterBridge.registerCharacter(characterID);
            trace('[RhythmState] Registered character for animations: ${characterID}');
        }
        
        add(arrowRenderer);
        add(noteRenderer);
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
        noteRenderer.spawnNote(note);
    }

    private function onNoteHit(note:Note, rating:HitRating):Void
    {
        noteRenderer.removeNote(note);
        arrowRenderer.onNoteHit(note, rating);
        characterBridge.onNoteHit(note, rating);
    }

    private function onNoteMiss(note:Note):Void
    {
        noteRenderer.removeNote(note);
        arrowRenderer.onNoteMiss(note);
        characterBridge.onNoteMiss(note);
    }

    private function onGhostTap(lane:Int):Void
    {
        arrowRenderer.onGhostTap(lane);
    }

    // --------------------------------------------------
    // Stage background loading
    // --------------------------------------------------

    private function createStageSprite(stageId:String):FlxSprite
    {
        if (stageId == null || stageId == "")
        {
            trace("[RhythmState] No stage specified in chart; skipping stage background");
            return null;
        }

        var stagePath = 'assets/images/stages/${stageId}.png';
        var sprite = new FlxSprite(0, 0);

        if (Assets.exists(stagePath))
        {
            trace('[RhythmState] Loading stage background: ${stagePath}');
            sprite.loadGraphic(stagePath);
        }
        else
        {
            trace('[RhythmState] Stage image not found at ${stagePath}, using placeholder');
            sprite.makeGraphic(FlxG.width, FlxG.height, 0xff101018);
        }

        // Fit to screen and keep static
        sprite.setGraphicSize(FlxG.width, FlxG.height);
        sprite.updateHitbox();
        sprite.scrollFactor.set(0, 0);
        sprite.antialiasing = true;

        return sprite;
    }

    // --------------------------------------------------
    // Completion
    // --------------------------------------------------

    private function finishSong():Void
    {
        trace("[RhythmState] Song complete");

        // Build result
        var result = {
            score: 0,
            combo: 0,
            accuracy: 0.0,
            health: 1.0,
            completed: true
        };

        if (onComplete != null)
        {
            // CRITICAL FIX: Store callback for deferred execution
            // Do NOT call onComplete here - VN renderers don't exist yet
            rhythm.RhythmCompletionBridge.storeResult(result, onComplete);
            
            trace("[RhythmState] Stored completion callback for deferred execution");
        }

        // Switch back to VN state
        // VN state's create/resume will:
        // 1. Initialize VN renderers
        // 2. Call RhythmCompletionBridge.executePendingCallback()
        // 3. Execute callback safely with valid renderers
        
        if (returnStateFactory != null)
        {
            trace("[RhythmState] Returning to VN state (rebuilding new instance)");
            FlxG.switchState(() -> returnStateFactory());
        }
        else
        {
            trace("[RhythmState] WARNING: No returnStateFactory provided, cannot transition back to VN");
            // Fallback: Call immediately (will likely crash)
            if (onComplete != null)
            {
                onComplete(result);
            }
        }
    }
}
