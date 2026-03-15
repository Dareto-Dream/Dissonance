package core.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;

class AudioSystem
{
	static var music:FlxSound;
	static var nextMusic:FlxSound;
	static var defaultBGM:String = "";
	static var currentTrack:String = "";
	static var isTransitioning:Bool = false;
	static var musicTween:FlxTween;
	static var nextMusicTween:FlxTween;

	public static var transitionType:String = "fade";
	public static var transitionDuration:Float = 2.0;

	public static function init():Void {}

	public static function setDefaultBGM(track:String, volume:Float = 1):Void
	{
		defaultBGM = track;

		if (music == null || !music.playing)
		{
			playMusic(track, volume, "cut");
		}
	}

	public static function playDefaultBGM(volume:Float = 1):Void
	{
		if (defaultBGM != "")
		{
			playMusic(defaultBGM, volume, "cut");
		}
	}

	public static function playSound(sound:String, volume:Float = 1):Void
	{
		trace("[AudioSystem] PLAY SOUND " + sound);
		FlxG.sound.play(sound, volume);
	}

	public static function playMusic(track:String, volume:Float = 1, ?transition:String, ?duration:Float):Void
	{
		if (transition == null) transition = transitionType;
		if (duration == null) duration = transitionDuration;

		trace("[AudioSystem] PLAY MUSIC " + track + " (transition: " + transition + ")");

		if (currentTrack == track && music != null && music.playing && !isTransitioning)
		{
			trace("[AudioSystem] Same track already playing, skipping");
			return;
		}

		if (isTransitioning)
		{
			cancelTransition();
		}

		currentTrack = track;

		switch (transition)
		{
			case "cut":
				applyCut(track, volume);
			case "fade":
				applyFade(track, volume, duration);
			case "wait_till_end":
				applyWaitTillEnd(track, volume);
			default:
				trace("[AudioSystem] Unknown transition type: " + transition + ", using fade");
				applyFade(track, volume, duration);
		}
	}

	private static function applyCut(track:String, volume:Float):Void
	{
		cancelTransition();
		destroySound(music);
		music = null;

		music = FlxG.sound.load(track, volume, true);
		if (music != null)
		{
			music.onComplete = null;
			music.play();
		}
		else
		{
			trace("[AudioSystem] ERROR: Could not load music track: " + track);
		}
	}

	private static function applyFade(track:String, volume:Float, duration:Float):Void
	{
		cancelTransition();
		isTransitioning = true;

		nextMusic = FlxG.sound.load(track, 0, true);
		if (nextMusic == null)
		{
			trace("[AudioSystem] ERROR: Could not load music track: " + track);
			isTransitioning = false;
			return;
		}

		nextMusic.onComplete = null;
		nextMusic.play();

		if (music != null && music.playing)
		{
			var oldMusic = music;
			musicTween = FlxTween.tween(oldMusic, {volume: 0}, duration, {
				onComplete: function(_) {
					destroySound(oldMusic);
					if (music == oldMusic)
					{
						music = null;
					}
					musicTween = null;
				}
			});
		}

		var incomingMusic = nextMusic;
		nextMusicTween = FlxTween.tween(incomingMusic, {volume: volume}, duration, {
			onComplete: function(_) {
				if (nextMusic == incomingMusic)
				{
					music = incomingMusic;
					nextMusic = null;
				}
				else
				{
					music = incomingMusic;
				}

				nextMusicTween = null;
				isTransitioning = false;
			}
		});
	}

	private static function applyWaitTillEnd(track:String, volume:Float):Void
	{
		cancelTransition();

		if (music != null && music.playing)
		{
			isTransitioning = true;
			nextMusic = FlxG.sound.load(track, volume, true);
			if (nextMusic == null)
			{
				trace("[AudioSystem] ERROR: Could not load music track: " + track);
				isTransitioning = false;
				return;
			}

			nextMusic.onComplete = null;

			var currentMusic = music;
			currentMusic.looped = false;
			currentMusic.onComplete = function() {
				if (music == currentMusic)
				{
					destroySound(currentMusic);
				}

				music = nextMusic;
				nextMusic = null;

				if (music != null)
				{
					music.onComplete = null;
					music.play();
				}

				isTransitioning = false;
			};
		}
		else
		{
			applyCut(track, volume);
		}
	}

	private static function cancelTransition():Void
	{
		cancelTween(musicTween);
		cancelTween(nextMusicTween);
		musicTween = null;
		nextMusicTween = null;

		if (music != null)
		{
			music.onComplete = null;
		}

		if (nextMusic != null)
		{
			destroySound(nextMusic);
			nextMusic = null;
		}

		isTransitioning = false;
	}

	public static function stopMusic():Void
	{
		cancelTransition();
		destroySound(music);
		music = null;

		currentTrack = "";
		isTransitioning = false;
	}

	public static function fadeOutMusic(duration:Float = 1):Void
	{
		cancelTransition();

		if (music != null && music.playing)
		{
			var currentMusic = music;
			musicTween = FlxTween.tween(currentMusic, {volume: 0}, duration, {
				onComplete: function(_) {
					destroySound(currentMusic);
					if (music == currentMusic)
					{
						music = null;
					}
					musicTween = null;
					currentTrack = "";
				}
			});
		}
		else
		{
			currentTrack = "";
		}
	}

	public static function getCurrentTrack():String
	{
		return currentTrack;
	}

	public static function isMusicPlaying():Bool
	{
		return music != null && music.playing;
	}

	private static function cancelTween(tween:FlxTween):Void
	{
		if (tween != null)
		{
			tween.cancel();
			tween.destroy();
		}
	}

	private static function destroySound(sound:FlxSound):Void
	{
		if (sound == null)
		{
			return;
		}

		sound.onComplete = null;
		sound.stop();
		sound.destroy();
	}
}
