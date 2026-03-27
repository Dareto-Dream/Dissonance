package rhythm;

import flixel.FlxG;

/**
 * Conductor
 * =========
 * Single authoritative timing source for the rhythm engine.
 *
 * HARD RULES:
 * - All gameplay timing is milliseconds (ms)
 * - No other class calculates time deltas
 * - No frame-based timing is allowed outside rendering
 *
 * Everything else derives from this.
 */
class Conductor
{
    // --- Chart-defined ---
    public var bpm:Float;
    public var offsetMs:Float;

    // --- Derived beat lengths ---
    public var crochetMs:Float;       // One beat
    public var stepCrochetMs:Float;   // One step (1/4 beat, FNF-style)

    // --- Authoritative song position ---
    public var songPositionMs:Float = 0;

    // --- Derived (read-only, for visuals / animation) ---
    public var songPositionBeats:Float = 0;
    public var songPositionSteps:Float = 0;

    // --- Internal ---
    private var started:Bool = false;

    public function new(bpm:Float, offsetMs:Float = 0)
    {
        this.bpm = bpm;
        this.offsetMs = offsetMs;

        recalcTimings();
    }

    /**
     * Recalculate beat lengths.
     * Safe to call if BPM changes mid-song later.
     */
    public function recalcTimings():Void
    {
        crochetMs = 60000.0 / bpm;
        stepCrochetMs = crochetMs / 4.0;
    }

    /**
     * Call once when the song actually starts playing.
     */
    public function start():Void
    {
        started = true;
    }

    /**
     * Update every frame.
     * This is the ONLY place where song time is read.
     */
    public function update():Void
    {
        if (!started) return;
        if (FlxG.sound.music == null) return;

        // FlxSound.time is already milliseconds; clamp to 0 to avoid negative positions
        songPositionMs = Math.max(0, FlxG.sound.music.time - offsetMs);

        // Derived values (never used for gameplay decisions)
        songPositionBeats = songPositionMs / crochetMs;
        songPositionSteps = songPositionMs / stepCrochetMs;
    }

    // ------------------------------------------------------------------
    // Helper accessors (safe, deterministic)
    // ------------------------------------------------------------------

    /** Current whole beat index */
    public inline function getBeatIndex():Int
    {
        return Std.int(Math.floor(songPositionBeats));
    }

    /** Current whole step index */
    public inline function getStepIndex():Int
    {
        return Std.int(Math.floor(songPositionSteps));
    }

    /** Convert a beat index to absolute ms */
    public inline function beatToMs(beat:Int):Float
    {
        return beat * crochetMs;
    }

    /** Convert a step index to absolute ms */
    public inline function stepToMs(step:Int):Float
    {
        return step * stepCrochetMs;
    }
}
