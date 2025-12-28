package rhythm;

import flixel.util.FlxSignal;
import rhythm.ChartHandler;
import rhythm.Conductor;
import rhythm.JudgementSystem.HitRating;
import rhythm.JudgementSystem;
import rhythm.Note.NoteKind;
import rhythm.Note.NoteOwner;
import rhythm.Note;

/**
 * NoteHandler
 * ===========
 * Core gameplay logic.
 *
 * Notes flow:
 *   ChartHandler -> ACTIVE -> JUDGED -> REMOVED
 *
 * Every note is handled exactly once.
 */
class NoteHandler
{
    // Active (spawned) notes
    private var activeNotes:Array<Note> = [];

    // External systems
    private var chart:ChartHandler;
    private var conductor:Conductor;
    private var judgement:JudgementSystem;

    // Spawn configuration
    public var spawnAheadMs:Float = 2000;

    // Input state
    private var heldLanes:Map<Int, Bool> = [];

    // ------------------------------------------------------------------
    // Events (consumed by renderer / animation / scoring)
    // ------------------------------------------------------------------

    public var onNoteSpawn:FlxTypedSignal<Note->Void>;
    public var onNoteHit:FlxTypedSignal<Note->HitRating->Void>;
    public var onNoteMiss:FlxTypedSignal<Note->Void>;
    public var onGhostTap:FlxTypedSignal<Int->Void>;

    public function new(
        chart:ChartHandler,
        conductor:Conductor,
        judgement:JudgementSystem
    )
    {
        this.chart = chart;
        this.conductor = conductor;
        this.judgement = judgement;

        onNoteSpawn = new FlxTypedSignal();
        onNoteHit   = new FlxTypedSignal();
        onNoteMiss  = new FlxTypedSignal();
        onGhostTap  = new FlxTypedSignal();
    }

    // ------------------------------------------------------------------
    // Update loop
    // ------------------------------------------------------------------

    public function update():Void
    {
        var nowMs = conductor.songPositionMs;

        spawnNotes(nowMs);
        handleOpponentAutoplay(nowMs);
        handleMisses(nowMs);
    }

    // ------------------------------------------------------------------
    // Spawning
    // ------------------------------------------------------------------

    private function spawnNotes(nowMs:Float):Void
    {
        var cutoff = nowMs + spawnAheadMs;

        while (chart.hasNext() && chart.peek().timeMs <= cutoff)
        {
            var note = chart.pop();
            activeNotes.push(note);
            onNoteSpawn.dispatch(note);
        }
    }

    // ------------------------------------------------------------------
    // Input handling
    // ------------------------------------------------------------------

    public function onKeyPress(inputLane:Int):Void
    {
        heldLanes.set(inputLane, true);

        var nowMs = conductor.songPositionMs;
        var target = findHittableNote(inputLane, nowMs);

        if (target == null)
        {
            onGhostTap.dispatch(inputLane);
            return;
        }

        var delta = nowMs - target.timeMs;
        var rating = judgement.judge(delta);

        if (rating == MISS)
        {
            onGhostTap.dispatch(inputLane);
            return;
        }

        consumeNote(target);
        onNoteHit.dispatch(target, rating);
    }

    public function onKeyRelease(inputLane:Int):Void
    {
        heldLanes.set(inputLane, false);

        var nowMs = conductor.songPositionMs;

        // Handle HOLD_TAIL release judgement
        var tail = findTailForLane(inputLane, nowMs);
        if (tail == null) return;

        var delta = nowMs - tail.timeMs;
        var rating = judgement.judgeRelease(delta);

        consumeNote(tail);
        onNoteHit.dispatch(tail, rating);
    }

    // ------------------------------------------------------------------
    // Opponent autoplay
    // ------------------------------------------------------------------

    /**
     * Handle opponent notes automatically on timing.
     * Opponents "auto-hit" notes when their scheduled time arrives.
     * This is separate from player hit/miss logic.
     */
    private function handleOpponentAutoplay(nowMs:Float):Void
    {
        var autoplayWindow = 50.0; // Small window around note time for autoplay
        var toAutoplay:Array<Note> = [];

        for (note in activeNotes)
        {
            // Only process opponent notes
            if (note.isPlayerNote()) continue;
            if (note.judged) continue;

            // Check if note time has been reached (within small window)
            var timeDiff = Math.abs(nowMs - note.timeMs);
            
            if (timeDiff <= autoplayWindow && nowMs >= note.timeMs)
            {
                toAutoplay.push(note);
            }
        }

        for (note in toAutoplay)
        {
            // Only trigger animations for TAP and HOLD_HEAD
            // HOLD_TICK and HOLD_TAIL don't trigger sing animations
            if (note.kind == NoteKind.TAP || note.kind == NoteKind.HOLD_HEAD)
            {
                // Trigger animation event with perfect rating (autoplay)
                onNoteHit.dispatch(note, HitRating.SICK);
            }

            // Consume the note
            consumeNote(note);
        }
    }

    // ------------------------------------------------------------------
    // Miss handling
    // ------------------------------------------------------------------

    private function handleMisses(nowMs:Float):Void
    {
        var missWindow = judgement.maxHitWindowMs();
        var toRemove:Array<Note> = [];

        for (note in activeNotes)
        {
            if (!note.isPlayerNote()) continue;
            if (note.judged) continue;

            if (nowMs > note.timeMs + missWindow)
            {
                toRemove.push(note);
            }
        }

        for (note in toRemove)
        {
            consumeNote(note);
            onNoteMiss.dispatch(note);
        }
    }

    // ------------------------------------------------------------------
    // Note lookup helpers
    // ------------------------------------------------------------------

    private function findHittableNote(inputLane:Int, nowMs:Float):Note
    {
        var window = judgement.maxHitWindowMs();
        var best:Note = null;
        var bestDiff = Math.POSITIVE_INFINITY;

        for (note in activeNotes)
        {
            if (!note.isPlayerNote()) continue;
            if (note.judged) continue;
            if (note.inputLane != inputLane) continue;

            // HOLD_TAILs are judged on release, not press
            if (note.kind == NoteKind.HOLD_TAIL) continue;

            var diff = Math.abs(note.timeMs - nowMs);
            if (diff <= window && diff < bestDiff)
            {
                best = note;
                bestDiff = diff;
            }
        }

        return best;
    }

    private function findTailForLane(inputLane:Int, nowMs:Float):Note
    {
        var window = judgement.maxHitWindowMs();

        for (note in activeNotes)
        {
            if (!note.isPlayerNote()) continue;
            if (note.judged) continue;
            if (note.inputLane != inputLane) continue;
            if (note.kind != NoteKind.HOLD_TAIL) continue;

            if (Math.abs(note.timeMs - nowMs) <= window)
                return note;
        }

        return null;
    }

    // ------------------------------------------------------------------
    // Consumption
    // ------------------------------------------------------------------

    private function consumeNote(note:Note):Void
    {
        note.judged = true;
        activeNotes.remove(note);
    }

    // ------------------------------------------------------------------
    // Debug / inspection
    // ------------------------------------------------------------------

    public inline function getActiveCount():Int
    {
        return activeNotes.length;
    }
}
