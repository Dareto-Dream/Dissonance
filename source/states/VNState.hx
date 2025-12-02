package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.FlxSprite;
import vn.SceneRunner;

class VNState extends FlxState {
    public var bgGroup:FlxSpriteGroup;
    public var uiGroup:FlxGroup;
    public var runner:SceneRunner;

    override public function create():Void {
        super.create();

        FlxG.mouse.visible = true;

        // Background layer (sprite-only group)
        bgGroup = new FlxSpriteGroup();
        add(bgGroup);

        // UI layer (simple group for debug UI)
        uiGroup = new FlxGroup();
        add(uiGroup);

        // Add a simple debug background so we can visually verify the game starts
        var debugBG = new FlxSprite(0, 0);
        debugBG.makeGraphic(FlxG.width, FlxG.height, 0xff111111);
        bgGroup.add(debugBG);

        runner = new SceneRunner("scenes/act1/scene1.json");
        runner.next();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        runner.update();
    }
}
