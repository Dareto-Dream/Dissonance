package core.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;

class AudioSystem
{
	static var music:FlxSound; // currently playing BGM reference

	public static function init():Void
	{
		// Nothing required yet, here for symmetry with other systems
	}

	// --------------------------------------------------------
	//  SOUND EFFECTS
	// --------------------------------------------------------
	public static function playSound(sound:String, volume:Float = 1):Void
	{
        trace("PLAY SOUND " + sound);
		// Uses Flixel’s simple SFX playback (non-looping)
		FlxG.sound.play(sound, volume);
    }

	// --------------------------------------------------------
	//  BACKGROUND MUSIC (BGM)
	// --------------------------------------------------------
	public static function playMusic(track:String, volume:Float = 1):Void
	{
        trace("PLAY MUSIC " + track);
		// Stop previous BGM
		if (music != null)
		{
			music.stop();
			music.destroy();
			music = null;
		}

		// Load and play new BGM
		music = FlxG.sound.load(track, volume, true); // true = loop
		if (music != null)
			music.play();
		else
			trace("[AudioSystem] ERROR: Could not load music track: " + track);
	}

	// --------------------------------------------------------
	//  OPTIONAL FUTURE FEATURES
	// --------------------------------------------------------

	public static function stopMusic():Void
	{
		if (music != null)
		{
			music.stop();
			music = null;
		}
	}

	public static function fadeOutMusic(duration:Float = 1):Void
	{
		if (music != null)
			music.fadeOut(duration, 0);
    }
}
