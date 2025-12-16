package core.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;

class AudioSystem
{
	static var music:FlxSound; // currently playing BGM reference
	static var nextMusic:FlxSound; // for crossfading
	static var defaultBGM:String = ""; // default background music path
	static var currentTrack:String = ""; // track currently playing
	static var isTransitioning:Bool = false;
	
	// Transition type for music changes
	public static var transitionType:String = "fade"; // fade, cut, wait_till_end
	public static var transitionDuration:Float = 2.0; // duration in seconds

	public static function init():Void
	{
		// Nothing required yet, here for symmetry with other systems
	}

	// --------------------------------------------------------
	//  DEFAULT BACKGROUND MUSIC
	// --------------------------------------------------------
	
	/**
	 * Set the default background music that plays continuously
	 * @param track Path to the music file
	 * @param volume Volume level (0-1)
	 */
	public static function setDefaultBGM(track:String, volume:Float = 1):Void
	{
		defaultBGM = track;
		
		// If no music is playing, start the default
		if (music == null || !music.playing)
		{
			playMusic(track, volume, "cut");
		}
	}
	
	/**
	 * Start playing the default BGM if set
	 */
	public static function playDefaultBGM(volume:Float = 1):Void
	{
		if (defaultBGM != "")
		{
			playMusic(defaultBGM, volume, "cut");
		}
	}

	// --------------------------------------------------------
	//  SOUND EFFECTS
	// --------------------------------------------------------
	public static function playSound(sound:String, volume:Float = 1):Void
	{
		trace("[AudioSystem] PLAY SOUND " + sound);
		// Uses Flixel's simple SFX playback (non-looping)
		FlxG.sound.play(sound, volume);
	}

	// --------------------------------------------------------
	//  BACKGROUND MUSIC (BGM) WITH TRANSITIONS
	// --------------------------------------------------------
	
	/**
	 * Play background music with transition support
	 * @param track Path to the music file
	 * @param volume Volume level (0-1)
	 * @param transition Transition type: "fade", "cut", "wait_till_end"
	 * @param duration Duration of fade transition in seconds
	 */
	public static function playMusic(track:String, volume:Float = 1, ?transition:String, ?duration:Float):Void
	{
		// Use stored transition type if not specified
		if (transition == null) transition = transitionType;
		if (duration == null) duration = transitionDuration;
		
		trace("[AudioSystem] PLAY MUSIC " + track + " (transition: " + transition + ")");
		
		// If same track is already playing, do nothing
		if (currentTrack == track && music != null && music.playing)
		{
			trace("[AudioSystem] Same track already playing, skipping");
			return;
		}
		
		// If already transitioning, cancel the previous transition
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
	
	/**
	 * Instant cut to new track
	 */
	private static function applyCut(track:String, volume:Float):Void
	{
		// Stop and destroy current music
		if (music != null)
		{
			music.stop();
			music.destroy();
			music = null;
		}
		
		// Load and play new track immediately
		music = FlxG.sound.load(track, volume, true); // true = loop
		if (music != null)
			music.play();
		else
			trace("[AudioSystem] ERROR: Could not load music track: " + track);
	}
	
	/**
	 * Crossfade between tracks
	 */
	private static function applyFade(track:String, volume:Float, duration:Float):Void
	{
		isTransitioning = true;
		
		// Load the next track but don't play it yet
		nextMusic = FlxG.sound.load(track, 0, true); // start at 0 volume
		if (nextMusic == null)
		{
			trace("[AudioSystem] ERROR: Could not load music track: " + track);
			isTransitioning = false;
			return;
		}
		
		nextMusic.play();
		
		// Fade out current music (if any)
		if (music != null && music.playing)
		{
			FlxTween.tween(music, {volume: 0}, duration, {
				onComplete: function(_) {
					music.stop();
					music.destroy();
					music = null;
				}
			});
		}
		
		// Fade in next music
		FlxTween.tween(nextMusic, {volume: volume}, duration, {
			onComplete: function(_) {
				music = nextMusic;
				nextMusic = null;
				isTransitioning = false;
			}
		});
	}
	
	/**
	 * Wait for current track to finish, then play next
	 */
	private static function applyWaitTillEnd(track:String, volume:Float):Void
	{
		if (music != null && music.playing)
		{
			isTransitioning = true;
			
			// Load next track but don't play it
			nextMusic = FlxG.sound.load(track, volume, true);
			if (nextMusic == null)
			{
				trace("[AudioSystem] ERROR: Could not load music track: " + track);
				isTransitioning = false;
				return;
			}
			
			// Wait for current track to finish
			// Check in onComplete callback
			music.onComplete = function() {
				music.destroy();
				music = nextMusic;
				nextMusic = null;
				
				if (music != null)
					music.play();
				
				isTransitioning = false;
			};
		}
		else
		{
			// No music playing, just start the new one
			applyCut(track, volume);
		}
	}
	
	/**
	 * Cancel any ongoing transition
	 */
	private static function cancelTransition():Void
	{
		if (nextMusic != null)
		{
			nextMusic.stop();
			nextMusic.destroy();
			nextMusic = null;
		}
		isTransitioning = false;
	}

	// --------------------------------------------------------
	//  MUSIC CONTROL
	// --------------------------------------------------------

	public static function stopMusic():Void
	{
		if (music != null)
		{
			music.stop();
			music.destroy();
			music = null;
		}
		
		if (nextMusic != null)
		{
			nextMusic.stop();
			nextMusic.destroy();
			nextMusic = null;
		}
		
		currentTrack = "";
		isTransitioning = false;
	}

	public static function fadeOutMusic(duration:Float = 1):Void
	{
		if (music != null && music.playing)
		{
			FlxTween.tween(music, {volume: 0}, duration, {
				onComplete: function(_) {
					music.stop();
					music.destroy();
					music = null;
					currentTrack = "";
				}
			});
		}
	}
	
	/**
	 * Get the currently playing track path
	 */
	public static function getCurrentTrack():String
	{
		return currentTrack;
	}
	
	/**
	 * Check if music is currently playing
	 */
	public static function isMusicPlaying():Bool
	{
		return music != null && music.playing;
	}
}
