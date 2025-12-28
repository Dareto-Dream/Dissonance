package states;

import core.audio.AudioSystem;
import core.dialogue.ChoiceSystem;
import core.dialogue.DialogueSystem;
import core.effects.EffectSystem;
import core.rendering.BackgroundSystem;
import core.rendering.CharacterSystem;
import core.scene.SceneRunner;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import rhythm.RhythmCompletionBridge;
import vn.VNCommands;
import vn.VNConfig;
import vn.VNReturnContext;

class VNState extends FlxState
{
	public var bgGroup:FlxSpriteGroup;
	public var charGroup:FlxGroup;
	public var uiGroup:FlxGroup;

	public var runner:SceneRunner;
	// Scene path to load
	private var scenePath:String;
	// Optional default background music
	private var defaultBGM:String;

	public function new(scenePath:String = "scenes/act1/scene1.json", ?defaultBGM:String)
	{
		super();
		this.scenePath = scenePath;
		this.defaultBGM = defaultBGM;
	}

	override public function create():Void
	{
		super.create();

		FlxG.mouse.visible = true;

		// --------------------------------------------------
		// CRITICAL: ESTABLISH SCENE CONTEXT FIRST
		// --------------------------------------------------
		// Scene data and narrative identifiers MUST be valid
		// BEFORE any add() calls or system initializations
		
		// Check if we're returning from rhythm gameplay
		var returnContext:VNReturnContext = null;
		if (VNReturnContext.hasPending())
		{
			trace('[VNState] Detected return from rhythm gameplay');
			returnContext = VNReturnContext.consume();
		}
		
		// Determine which scene to load
		var sceneToLoad:String;
		var resumeNode:String = null;
		
		if (returnContext != null)
		{
			// Returning from rhythm - use context scene path
			sceneToLoad = returnContext.scenePath;
			resumeNode = returnContext.resumeNodeId;
			trace('[VNState] Resuming scene: ${sceneToLoad} at node: ${resumeNode}');
		}
		else
		{
			// Normal VN start - use constructor scene path
			sceneToLoad = scenePath;
			trace('[VNState] Starting new scene: ${sceneToLoad}');
		}
		
		// Create SceneRunner FIRST - this loads and parses scene data
		// All narrative identifiers are now valid
		runner = new SceneRunner(sceneToLoad);
		
		// If resuming from rhythm, position at correct node
		if (resumeNode != null)
		{
			runner.currentNode = resumeNode;
			trace('[VNState] SceneRunner positioned at resume node: ${resumeNode}');
		}
		
		// --------------------------------------------------
		// NOW SAFE: Scene data is loaded, identifiers are valid
		// Systems can now safely reference scene-specific data
		// --------------------------------------------------
		
		// Reset static systems
		BackgroundSystem.reset();
		
		// Set VN state reference for rhythm transitions
		VNCommands.setVNState(this);

		// --------------------------------------------------
		// BACKGROUND LAYER
		// --------------------------------------------------
		bgGroup = new FlxSpriteGroup();
		add(bgGroup);

		// Simple debug background so you never get pure black
		var debugBG = new FlxSprite(0, 0);
		debugBG.makeGraphic(FlxG.width, FlxG.height, 0xff111111);
		debugBG.scrollFactor.set(0, 0);
		bgGroup.add(debugBG);

		// --------------------------------------------------
		// CHARACTER LAYER
		// --------------------------------------------------
		charGroup = new FlxGroup();
		add(charGroup);

		// Load character definitions from data
		var charDefsMap = VNConfig.loadCharacterDefs();

		// Convert CharacterDefMap to Array<Dynamic>
		var charDefs:Array<Dynamic> = [];
		for (key in charDefsMap.keys())
		{
			charDefs.push(charDefsMap.get(key));
		}

		// Let CharacterSystem build sprites/renderers and attach to charGroup
		// Safe now - SceneRunner exists, scene identifiers are valid
		CharacterSystem.init(charGroup, charDefs);

		// --------------------------------------------------
		// UI LAYER
		// --------------------------------------------------
		uiGroup = new FlxGroup();
		add(uiGroup);

		// Hook VN subsystems to UI layer as needed
		DialogueSystem.init(uiGroup);
		ChoiceSystem.init(uiGroup);
		EffectSystem.init(uiGroup);
		AudioSystem.init();

		// --------------------------------------------------
		// BACKGROUND MUSIC
		// --------------------------------------------------
		// Start default background music if specified
		if (defaultBGM != null && defaultBGM != "")
		{
			AudioSystem.setDefaultBGM(defaultBGM, 0.7);
		}

		// --------------------------------------------------
		// RHYTHM CALLBACK EXECUTION
		// --------------------------------------------------
		// CRITICAL: Execute rhythm callback AFTER all systems are initialized
		// and SceneRunner is positioned at the correct node
		if (RhythmCompletionBridge.hasPendingCallback())
		{
			trace('[VNState] Executing pending rhythm completion callback');
			
			// This will call the callback that was passed to RhythmBridge.start()
			// At this point:
			// - Scene data is fully loaded and parsed
			// - SceneRunner is positioned at the correct resume node
			// - VN renderers are fully initialized
			// - CharacterSystem is valid
			// - All narrative identifiers are valid
			// - Safe to execute VN logic
			RhythmCompletionBridge.executePendingCallback();
			
			trace('[VNState] Rhythm callback executed successfully');
		}

		// --------------------------------------------------
		// START SCENE EXECUTION
		// --------------------------------------------------
		// Now safe to start scene runner
		// If we came from rhythm, we're already at the correct node
		// If new scene, we start from the beginning
		runner.next();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (runner != null)
			runner.update();
		ChoiceSystem.update();
		DialogueSystem.update(elapsed);
		DialogueSystem.handleInput();
	}
}
