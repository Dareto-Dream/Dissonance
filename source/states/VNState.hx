package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import vn.SceneRunner;

class VNState extends FlxState
{
	// Render layers (bottom → top)
	public var bgGroup:FlxSpriteGroup; // backgrounds
	public var charGroup:FlxGroup; // characters (added)
	public var uiGroup:FlxGroup; // UI / dialogue

    public var runner:SceneRunner;

	override public function create():Void
	{
        super.create();

        FlxG.mouse.visible = true;

		// --- Background layer ---
        bgGroup = new FlxSpriteGroup();
        add(bgGroup);

		// Add debug background
        var debugBG = new FlxSprite(0, 0);
        debugBG.makeGraphic(FlxG.width, FlxG.height, 0xff111111);
        bgGroup.add(debugBG);

		// --- Character layer ---
		charGroup = new FlxGroup();
		add(charGroup);

		// --- UI layer ---
		uiGroup = new FlxGroup();
		add(uiGroup);

		// Start first scene
        runner = new SceneRunner("scenes/act1/scene1.json");
        runner.next();
    }

	override public function update(elapsed:Float):Void
	{
        super.update(elapsed);
        runner.update();
    }
}
