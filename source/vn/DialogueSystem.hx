package vn;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxTimer;
import states.VNState;

class DialogueSystem {
    public static function show(speaker:String, text:String, done:Void->Void):Void {
        trace("DIALOGUE: " + speaker + ": " + text);

        var state = cast(FlxG.state, VNState);
        if (state == null) {
            done();
            return;
        }

        var box = new FlxSprite(40, FlxG.height - 160);
        box.makeGraphic(FlxG.width - 80, 120, 0xaa000000);
        state.uiGroup.add(box);

        var label = new FlxText(60, FlxG.height - 150, FlxG.width - 120, speaker + ": " + text);
        label.setFormat(null, 20, 0xFFFFFFFF, "left");
        state.uiGroup.add(label);

        // Remove after a short timeout for debug purposes
        var t = new FlxTimer();
        t.start(0.9, 1, (_:FlxTimer) -> {
            state.uiGroup.remove(box);
            state.uiGroup.remove(label);
            done();
        });
    }

    public static function showNarration(text:String, done:Void->Void):Void {
        trace("NARRATION: " + text);
        var state = cast(FlxG.state, VNState);
        if (state == null) {
            done();
            return;
        }

        var box = new FlxSprite(40, FlxG.height - 160);
        box.makeGraphic(FlxG.width - 80, 120, 0xaa000000);
        state.uiGroup.add(box);

        var label = new FlxText(60, FlxG.height - 150, FlxG.width - 120, text);
        label.setFormat(null, 20, 0xFFFFFFFF, "left");
        state.uiGroup.add(label);

        var t = new FlxTimer();
        t.start(0.9, 1, (_:FlxTimer) -> {
            state.uiGroup.remove(box);
            state.uiGroup.remove(label);
            done();
        });
    }
}
