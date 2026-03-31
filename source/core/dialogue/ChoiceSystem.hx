package core.dialogue;

import core.state.SystemOverrideService;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import util.MobileSupport;

// Optional helper typedef for clarity
typedef ChoiceEntry =
{
	var background:FlxSprite;
	var textObj:FlxText;
	var target:String;
};

class ChoiceSystem
{
	static var uiGroup:FlxGroup;

	// Stored clickable choices for manual pointer detection
	static var choiceTexts:Array<ChoiceEntry> = [];

	// Callback to run when a choice is selected
	static var choiceCallback:String->Void;

	// Temporary debug mode: auto-pick the first choice
	public static var debugAuto:Bool = false;

	public static function init(group:FlxGroup):Void
	{
		uiGroup = group;
	}

	public static function hasActiveChoices():Bool
	{
		return choiceCallback != null && choiceTexts != null && choiceTexts.length > 0;
	}

	public static function getChoiceLabels():Array<String>
	{
		var labels:Array<String> = [];
		for (entry in choiceTexts)
		{
			if (entry != null && entry.textObj != null)
			{
				labels.push(entry.textObj.text);
			}
		}
		return labels;
	}

	public static function selectChoice(index:Int):Bool
	{
		if (!SystemOverrideService.canChoose())
		{
			return false;
		}

		if (!hasActiveChoices())
		{
			return false;
		}

		if (index < 0 || index >= choiceTexts.length)
		{
			return false;
		}

		var entry = choiceTexts[index];
		if (entry == null)
		{
			return false;
		}

		var target = entry.target;
		var cb = choiceCallback;
		clearChoices();
		if (cb != null)
		{
			cb(target);
		}

		return true;
	}

	public static function clear():Void
	{
		clearChoices();
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

		var sideMargin = MobileSupport.choiceSideMargin();
		var spacing = MobileSupport.choiceSpacing();
		var buttonHeight = MobileSupport.choiceButtonHeight();
		var totalHeight = (choices.length * buttonHeight) + ((choices.length - 1) * (spacing - buttonHeight));
		var yStart = FlxG.height - MobileSupport.choiceBottomMargin() - totalHeight;
		var buttonWidth = FlxG.width - (sideMargin * 2);

		for (i in 0...choices.length)
		{
			var c = choices[i];
			var y = yStart + i * spacing;

			var background = new FlxSprite(sideMargin, y);
			background.makeGraphic(Std.int(buttonWidth), Std.int(buttonHeight), FlxColor.fromRGB(16, 12, 28));
			background.scrollFactor.set(0, 0);
			background.alpha = MobileSupport.isMobile() ? 0.88 : 0.72;
			uiGroup.add(background);

			var txt = new FlxText(sideMargin + 18, y + (MobileSupport.isMobile() ? 12 : 8), buttonWidth - 36, "> " + c.text);
			txt.setFormat(null, MobileSupport.choiceFontSize(), 0xffffff, "left");
			txt.scrollFactor.set(0, 0);
			uiGroup.add(txt);

			choiceTexts.push({
				background: background,
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
				if (entry != null && entry.background != null)
				{
					entry.background.kill();
					uiGroup.remove(entry.background);
					entry.background.destroy();
				}

				if (entry != null && entry.textObj != null)
				{
					entry.textObj.kill();
					uiGroup.remove(entry.textObj);
					entry.textObj.destroy();
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

		if (!SystemOverrideService.canChoose())
		{
			return;
		}

		for (entry in choiceTexts)
		{
			if (entry == null || entry.background == null || entry.textObj == null)
			{
				continue;
			}

			var highlighted = MobileSupport.pointerOverlaps(entry.background) || MobileSupport.pointerOverlaps(entry.textObj);
			entry.background.alpha = highlighted ? 0.96 : (MobileSupport.isMobile() ? 0.88 : 0.72);
			entry.textObj.color = highlighted ? FlxColor.WHITE : FlxColor.fromRGB(232, 232, 255);
		}

		for (entry in choiceTexts)
		{
			if (entry == null || entry.background == null || entry.textObj == null)
			{
				continue;
			}

			if (MobileSupport.pointerJustPressedOver(entry.background) || MobileSupport.pointerJustPressedOver(entry.textObj))
			{
				trace("CHOICE SELECTED: " + entry.textObj.text);

				var target = entry.target;
				var cb = choiceCallback;
				clearChoices();
				if (cb != null)
				{
					cb(target);
				}
				break;
			}
		}
	}
}
