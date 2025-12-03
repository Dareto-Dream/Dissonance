package vn;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxTimer;

class DialogueSystem
{
	// UI attachment point (set from VNState)
	static var uiGroup:FlxGroup;

	// Reused UI elements
	static var box:FlxSprite;
	static var label:FlxText;
	static var timer:FlxTimer;

	// -------------------------------------------------
	//  INIT
	// -------------------------------------------------
	public static function init(group:FlxGroup):Void
	{
		uiGroup = group;

		// Create base box and label once
		box = new FlxSprite(40, FlxG.height - 160);
		box.makeGraphic(FlxG.width - 80, 120, 0xaa000000);
		box.scrollFactor.set(0, 0);

		label = new FlxText(60, FlxG.height - 150, FlxG.width - 120, "");
		label.setFormat(null, 20, 0xFFFFFFFF, "left");
		label.scrollFactor.set(0, 0);

		uiGroup.add(box);
		uiGroup.add(label);

		box.visible = false;
		label.visible = false;

		timer = new FlxTimer();
	}

	// -------------------------------------------------
	//  DIALOGUE
	// -------------------------------------------------
	public static function show(speaker:String, text:String, done:Void->Void):Void
	{
        trace("DIALOGUE: " + speaker + ": " + text);

		if (uiGroup == null)
		{
            done();
            return;
        }

		// Show box and text
		box.visible = true;
		label.visible = true;
		label.text = speaker + ": " + text;

		// Debug auto advance
		timer.cancel();
		timer.start(0.9, function(_)
		{
			box.visible = false;
			label.visible = false;
            done();
        });
    }

	// -------------------------------------------------
	//  NARRATION
	// -------------------------------------------------
	public static function showNarration(text:String, done:Void->Void):Void
	{
        trace("NARRATION: " + text);
		if (uiGroup == null)
		{
            done();
            return;
        }

		box.visible = true;
		label.visible = true;
		label.text = text;

		timer.cancel();
		timer.start(0.9, function(_)
		{
			box.visible = false;
			label.visible = false;
            done();
        });
    }
}
