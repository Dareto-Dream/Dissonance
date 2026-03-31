package core.state;

import flixel.FlxG;

typedef ProgressData = {
	var gameCompleted:Bool;
	var endingsSeen:Array<String>;
	var extrasUnlocked:Bool;
	var lastCompletionTimestamp:String;
}

class ProgressService
{
	private static inline var SAVE_KEY:String = "dissonance_progress";

	public static var gameCompleted(default, null):Bool = false;
	public static var extrasUnlocked(default, null):Bool = false;
	public static var endingsSeen(default, null):Array<String> = [];
	public static var lastCompletionTimestamp(default, null):String = "";

	private static var loaded:Bool = false;

	public static function ensureLoaded():Void
	{
		if (loaded)
		{
			return;
		}

		FlxG.save.bind(SAVE_KEY);
		var data:Dynamic = Reflect.field(FlxG.save.data, "progress");
		if (data != null)
		{
			if (data.gameCompleted != null) gameCompleted = data.gameCompleted;
			if (data.extrasUnlocked != null) extrasUnlocked = data.extrasUnlocked;
			if (data.lastCompletionTimestamp != null) lastCompletionTimestamp = data.lastCompletionTimestamp;
			if (data.endingsSeen != null && Std.isOfType(data.endingsSeen, Array))
			{
				endingsSeen = cast data.endingsSeen;
			}
		}

		loaded = true;
	}

	public static function unlockMainEnding(?endingId:String = "main"):Void
	{
		ensureLoaded();
		gameCompleted = true;
		extrasUnlocked = true;
		lastCompletionTimestamp = Date.now().toString();
		recordEnding(endingId);
		save();
	}

	public static function recordEnding(id:String):Void
	{
		ensureLoaded();
		if (id == null || id == "")
		{
			return;
		}

		if (!endingsSeen.contains(id))
		{
			endingsSeen.push(id);
			endingsSeen.sort(sortStrings);
		}

		save();
	}

	public static function hasEnding(id:String):Bool
	{
		ensureLoaded();
		return endingsSeen.contains(id);
	}

	public static function snapshot():ProgressData
	{
		ensureLoaded();
		return {
			gameCompleted: gameCompleted,
			endingsSeen: endingsSeen.copy(),
			extrasUnlocked: extrasUnlocked,
			lastCompletionTimestamp: lastCompletionTimestamp
		};
	}

	private static function save():Void
	{
		FlxG.save.bind(SAVE_KEY);
		Reflect.setField(FlxG.save.data, "progress", snapshot());
		FlxG.save.flush();
	}

	private static function sortStrings(a:String, b:String):Int
	{
		if (a < b) return -1;
		if (a > b) return 1;
		return 0;
	}
}
