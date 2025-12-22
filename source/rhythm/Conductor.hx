package rhythm;

import flixel.FlxG;

/**
 * Conductor - The rhythm game's timing authority
 * 
 * This class manages all time-based calculations for the rhythm game.
 * It synchronizes with the audio system's DSP time to ensure accurate timing.
 * 
 * Key concepts:
 * - songPosition: Current position in the song (seconds)
 * - crotchet: Duration of one beat (60 / bpm)
 * - stepCrotchet: Duration of one step (crotchet / 4)
 * 
 * Usage:
 *   conductor.start(FlxG.sound.music.time);
 *   conductor.update(); // Call every frame
 *   var pos = conductor.songPosition; // Use for all timing calculations
 */
class Conductor {
    // Beats per minute
    public var bpm:Float;
    
    // Duration of one beat in seconds
    public var crotchet:Float;
    
    // Duration of one step (1/4 beat) in seconds
    public var stepCrotchet:Float;
    
    // Offset to compensate for MP3 silence at start
    public var offset:Float;
    
    // Current song position in seconds
    public var songPosition:Float = 0;
    
    // Song position in beats (for visual effects)
    public var songPositionInBeats:Float = 0;
    
    // Song position in steps (finer granularity)
    public var songPositionInSteps:Float = 0;
    
    // When the song started (DSP time)
    private var dspSongStart:Float = 0;
    
    /**
     * Constructor
     * @param bpm Beats per minute of the song
     * @param offset Audio offset in seconds (usually 0.0 to 0.1)
     */
    public function new(bpm:Float, offset:Float = 0.0) {
        this.bpm = bpm;
        this.offset = offset;
        
        // Calculate beat and step durations
        // crotchet = 60 seconds / bpm
        this.crotchet = 60 / bpm;
        
        // A step is 1/4 of a beat
        this.stepCrotchet = crotchet / 4;
    }
    
    /**
     * Start timing from a specific audio time
     * Call this when the music starts playing
     * 
     * @param musicTime Current music time from FlxG.sound.music.time
     */
    public function start(musicTime:Float):Void {
        // Store the DSP time when song started
        // We'll use this as our reference point
        dspSongStart = musicTime;
    }
    
    /**
     * Update song position
     * Call this every frame in your state's update()
     * 
     * This is where the magic happens - we derive position from audio time,
     * NOT from accumulated deltaTime, which prevents drift.
     */
    public function update():Void {
        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            return;
        }
        
        // Get current audio time and subtract start time
        // This gives us the song position
        songPosition = (FlxG.sound.music.time / 1000) - offset;
        
        // Calculate beat and step positions
        songPositionInBeats = songPosition / crotchet;
        songPositionInSteps = songPosition / stepCrotchet;
    }
    
    /**
     * Get which step a time value corresponds to
     * Useful for calculating note positions
     * 
     * @param time Time in seconds
     * @return Step number (as float for precision)
     */
    public function getStepAtTime(time:Float):Float {
        return time / stepCrotchet;
    }
    
    /**
     * Get which beat a time value corresponds to
     * 
     * @param time Time in seconds
     * @return Beat number (as float for precision)
     */
    public function getBeatAtTime(time:Float):Float {
        return time / crotchet;
    }
    
    /**
     * Convert milliseconds to seconds
     * Helper for chart parsing
     */
    public static inline function msToSeconds(ms:Float):Float {
        return ms / 1000;
    }
}