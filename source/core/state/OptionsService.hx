package core.state;

import core.audio.AudioSystem;
import core.dialogue.DialogueSystem;
import flixel.FlxG;

typedef OptionsData = {
	var textSpeed:Float;
	var musicVolume:Float;
	var sfxVolume:Float;
	var autoAdvanceDelay:Float;
	var autoAdvanceEnabled:Bool;
	var fullscreen:Bool;
}

class OptionsService
{
	private static inline var SAVE_KEY:String = "dissonance_options";

	public static var textSpeed(default, null):Float = 30.0;
	public static var musicVolume(default, null):Float = 0.7;
	public static var sfxVolume(default, null):Float = 0.8;
	public static var autoAdvanceDelay(default, null):Float = 2.0;
	public static var autoAdvanceEnabled(default, null):Bool = false;
	public static var fullscreen(default, null):Bool = false;

	private static var loaded:Bool = false;

	public static function ensureLoaded():Void
	{
		if (loaded)
		{
			return;
		}

		FlxG.save.bind(SAVE_KEY);
		var data:Dynamic = Reflect.field(FlxG.save.data, "options");
		if (data != null)
		{
			if (data.textSpeed != null) textSpeed = data.textSpeed;
			if (data.musicVolume != null) musicVolume = data.musicVolume;
			if (data.sfxVolume != null) sfxVolume = data.sfxVolume;
			if (data.autoAdvanceDelay != null) autoAdvanceDelay = data.autoAdvanceDelay;
			if (data.autoAdvanceEnabled != null) autoAdvanceEnabled = data.autoAdvanceEnabled;
			if (data.fullscreen != null) fullscreen = data.fullscreen;
		}

		loaded = true;
		apply();
	}

	public static function snapshot():OptionsData
	{
		ensureLoaded();
		return {
			textSpeed: textSpeed,
			musicVolume: musicVolume,
			sfxVolume: sfxVolume,
			autoAdvanceDelay: autoAdvanceDelay,
			autoAdvanceEnabled: autoAdvanceEnabled,
			fullscreen: fullscreen
		};
	}

	public static function setTextSpeed(value:Float):Void
	{
		ensureLoaded();
		textSpeed = clamp(value, 10.0, 80.0);
		save();
	}

	public static function setMusicVolume(value:Float):Void
	{
		ensureLoaded();
		musicVolume = clamp(value, 0.0, 1.0);
		AudioSystem.setMusicVolume(musicVolume);
		save();
	}

	public static function setSfxVolume(value:Float):Void
	{
		ensureLoaded();
		sfxVolume = clamp(value, 0.0, 1.0);
		AudioSystem.setSfxVolume(sfxVolume);
		save();
	}

	public static function setAutoAdvanceDelay(value:Float):Void
	{
		ensureLoaded();
		autoAdvanceDelay = clamp(value, 0.25, 5.0);
		save();
	}

	public static function setAutoAdvanceEnabled(value:Bool):Void
	{
		ensureLoaded();
		autoAdvanceEnabled = value;
		DialogueSystem.setAutoAdvance(autoAdvanceEnabled);
		save();
	}

	public static function setFullscreen(value:Bool):Void
	{
		ensureLoaded();
		fullscreen = value;
		applyDisplay();
		save();
	}

	public static function toggleAutoAdvance():Bool
	{
		setAutoAdvanceEnabled(!autoAdvanceEnabled);
		return autoAdvanceEnabled;
	}

	public static function toggleFullscreen():Bool
	{
		setFullscreen(!fullscreen);
		return fullscreen;
	}

	public static function apply():Void
	{
		ensureLoaded();
		AudioSystem.setMusicVolume(musicVolume);
		AudioSystem.setSfxVolume(sfxVolume);
		DialogueSystem.setAutoAdvance(autoAdvanceEnabled);
		applyDisplay();
	}

	private static function applyDisplay():Void
	{
		#if !html5
		FlxG.fullscreen = fullscreen;
		#end
	}

	private static function save():Void
	{
		FlxG.save.bind(SAVE_KEY);
		Reflect.setField(FlxG.save.data, "options", snapshot());
		FlxG.save.flush();
	}

	private static function clamp(value:Float, min:Float, max:Float):Float
	{
		if (value < min) return min;
		if (value > max) return max;
		return value;
	}
}
