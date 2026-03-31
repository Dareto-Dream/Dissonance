package core.state;

typedef SystemOverrideRule = {
	var id:String;
	var blockPause:Bool;
	var blockManualAdvance:Bool;
	var ignoreChoices:Bool;
	var fakeSpeaker:String;
	var forceAutoAdvance:Null<Bool>;
	var glitchMultiplier:Float;
}

class SystemOverrideService
{
	private static var overrides:Map<String, SystemOverrideRule> = new Map();

	public static function applyFromNode(node:Dynamic):Void
	{
		var id = node.override_id != null ? Std.string(node.override_id) : "global";
		overrides.set(id, {
			id: id,
			blockPause: readBool(node.block_pause),
			blockManualAdvance: readBool(node.block_manual_advance),
			ignoreChoices: readBool(node.ignore_choices),
			fakeSpeaker: node.fake_speaker != null ? Std.string(node.fake_speaker) : null,
			forceAutoAdvance: node.force_auto_advance != null ? readBool(node.force_auto_advance) : null,
			glitchMultiplier: node.glitch_multiplier != null ? readFloat(node.glitch_multiplier, 1.0) : 1.0
		});
	}

	public static function clear(?id:String):Void
	{
		if (id == null || id == "")
		{
			overrides.clear();
			return;
		}

		overrides.remove(id);
	}

	public static function clearAll():Void
	{
		overrides.clear();
	}

	public static function canPause():Bool
	{
		for (rule in overrides)
		{
			if (rule.blockPause)
			{
				return false;
			}
		}
		return true;
	}

	public static function canManualAdvance():Bool
	{
		for (rule in overrides)
		{
			if (rule.blockManualAdvance)
			{
				return false;
			}
		}
		return true;
	}

	public static function canChoose():Bool
	{
		for (rule in overrides)
		{
			if (rule.ignoreChoices)
			{
				return false;
			}
		}
		return true;
	}

	public static function resolveSpeaker(original:String):String
	{
		for (rule in overrides)
		{
			if (rule.fakeSpeaker != null && rule.fakeSpeaker != "")
			{
				return rule.fakeSpeaker;
			}
		}
		return original;
	}

	public static function forceAutoAdvanceEnabled():Null<Bool>
	{
		for (rule in overrides)
		{
			if (rule.forceAutoAdvance != null)
			{
				return rule.forceAutoAdvance;
			}
		}
		return null;
	}

	public static function getGlitchMultiplier():Float
	{
		var multiplier = 1.0;
		for (rule in overrides)
		{
			multiplier *= rule.glitchMultiplier;
		}
		return multiplier;
	}

	private static function readBool(value:Dynamic):Bool
	{
		return value == true || Std.string(value).toLowerCase() == "true";
	}

	private static function readFloat(value:Dynamic, fallback:Float):Float
	{
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}
