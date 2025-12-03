package vn;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.text.FlxText;

// Optional helper typedef for clarity
typedef ChoiceEntry =
{
	var textObj:FlxText;
	var target:String;
};

class ChoiceSystem
{
	static var uiGroup:FlxGroup;

	// Stored clickable choices for manual mouse detection
	static var choiceTexts:Array<ChoiceEntry> = [];

	// Callback to run when a choice is selected
	static var choiceCallback:String->Void;

	// Temporary debug mode: auto-pick the first choice
	public static var debugAuto:Bool = true;

	public static function init(group:FlxGroup):Void
	{
		uiGroup = group;
	}

	/**
	 * choices: [{ text: "...", target: "..." }, ...]
	 */
	public static function show(choices:Array<Dynamic>, callback:String->Void):Void
	{
		// Clear any previous choice UI
		clearChoices();

		if (choices == null || choices.length == 0)
		{
			trace("[ChoiceSystem] No choices defined.");
			callback(null);
			return;
		}

		// Debug mode: auto-pick first choice like your original stub
		if (debugAuto)
		{
			trace("CHOICE: Selected " + choices[0].text);
			callback(choices[0].target);
			return;
		}

		// Store callback for when player actually clicks something
		choiceCallback = callback;

		var yStart = FlxG.height - 220;
		var spacing = 40;

		for (i in 0...choices.length)
		{
			var c = choices[i];

			var txt = new FlxText(60, yStart + i * spacing, FlxG.width - 120, "> " + c.text);
			txt.setFormat(null, 24, 0xffffff, "left");
			txt.scrollFactor.set(0, 0);
			uiGroup.add(txt);

			choiceTexts.push({
				textObj: txt,
				target: c.target
			});
		}
	}

	static function clearChoices():Void
	{
		if (uiGroup != null)
		{
			// Remove only our choice texts
			for (entry in choiceTexts)
			{
				if (entry != null && entry.textObj != null)
				{
					entry.textObj.kill();
					uiGroup.remove(entry.textObj);
				}
			}
		}

		choiceTexts = [];
		choiceCallback = null;
	}

	// Call this from VNState.update()
	public static function update():Void
	{
		if (choiceCallback == null || choiceTexts == null || choiceTexts.length == 0)
			return;

		// On mouse click, see if we clicked any choice text
		if (FlxG.mouse.justPressed)
		{
			for (entry in choiceTexts)
			{
				if (entry != null && entry.textObj != null && FlxG.mouse.overlaps(entry.textObj))
				{
					trace("CHOICE SELECTED: " + entry.textObj.text);

					var target = entry.target;

					// Clear UI
					clearChoices();

					// Call scene callback
					choiceCallback(target);
					break;
				}
			}
		}
    }
}
