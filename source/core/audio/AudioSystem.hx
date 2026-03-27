package core.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import openfl.utils.Assets;

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

	/**
	 * Called by VNState.create() each time a VN scene loads.
	 * Clears stale tween/transition state left over from a state switch,
	 * and removes dead sound references so playMusic() can reload cleanly.
	 */
	public static function init():Void
	{
		// Tweens are destroyed on state switch — clear the dead references
		if (isTransitioning)
		{
			musicTween = null;
			nextMusicTween = null;
			isTransitioning = false;
		}

		// nextMusic is not persisted — it gets destroyed on state switch
		if (nextMusic != null && !nextMusic.alive)
			nextMusic = null;

		// If our persisted music reference is dead, reset so playMusic() reloads it
		if (music != null && !music.alive)
		{
			music = null;
			currentTrack = "";
		}
	}

	/**
	 * Call this when returning from the rhythm game to VNState.
	 * RhythmState uses FlxG.sound.playMusic() directly (its own channel).
	 * That sound is NOT persisted, so it is already dead after the state switch.
	 * This method just ensures AudioSystem's own state is consistent.
	 */
	public static function onRhythmReturn():Void
	{
		// RhythmState stops FlxG.sound.music before switching, but guard here too
		// in case the state switch happened via an unexpected path (e.g. pause→quit).
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			FlxG.sound.music.destroy();
			FlxG.sound.music = null;
		}
		init();
	}

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
		if (sound == null || sound == "") return;
		if (!Assets.exists(sound)) {
			trace("[AudioSystem] WARNING: Sound not found: " + sound);
			return;
		}
		FlxG.sound.play(sound, volume);
	}

	public static function playMusic(track:String, volume:Float = 1, ?transition:String, ?duration:Float):Void
	{
		if (transition == null) transition = transitionType;
		if (duration == null) duration = transitionDuration;

		if (currentTrack == track && music != null && music.alive && music.playing && !isTransitioning)
			return;

		if (!Assets.exists(track)) {
			trace("[AudioSystem] WARNING: Music not found: " + track);
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
			music.persist = true; // survive scene switches within VN
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

		nextMusic.persist = true; // survive scene switches within VN
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
