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
import vn.VNConfig;

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

		// Reset static systems when creating a new state
		BackgroundSystem.reset();

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
		// START SCENE
		// --------------------------------------------------
		runner = new SceneRunner(scenePath);
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
