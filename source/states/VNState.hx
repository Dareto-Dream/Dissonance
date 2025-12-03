package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import vn.AudioSystem;
import vn.CharacterSystem;
import vn.ChoiceSystem;
import vn.DialogueSystem;
import vn.EffectSystem;
import vn.SceneRunner;
import vn.VNConfig; // will provide loadCharacterDefs()

/**
 * VNState
 * Root state for the visual novel layer.
 * Owns render layers and wires VN systems together.
 */
class VNState extends FlxState
{
	// Render layers (bottom → top)
	public var bgGroup:FlxSpriteGroup; // backgrounds (used by BackgroundSystem)
	public var charGroup:FlxGroup; // characters
	public var uiGroup:FlxGroup; // dialogue / choices / overlays

    public var runner:SceneRunner;

	override public function create():Void
	{
        super.create();

        FlxG.mouse.visible = true;

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

		// BackgroundSystem will bind to bgGroup via:
		//   cast(FlxG.state, VNState).bgGroup

		// --------------------------------------------------
		// CHARACTER LAYER
		// --------------------------------------------------
		charGroup = new FlxGroup();
		add(charGroup);

		// Load character definitions from data
		// (e.g. assets/data/characters/characters.json)
		var charDefs = VNConfig.loadCharacterDefs();

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
		// START FIRST SCENE
		// --------------------------------------------------
		// You are preloading:
		//   assets/data/scenes/act1/scene1.json
		// SceneRunner should resolve that internally from this id/path.
        runner = new SceneRunner("scenes/act1/scene1.json");
        runner.next();
    }

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (runner != null)
			runner.update();
		ChoiceSystem.update();
	}
}
