package rhythm;

import flixel.util.FlxSignal;
import rhythm.ChartHandler;
import rhythm.Conductor;
import rhythm.JudgementSystem.HitRating;
import rhythm.JudgementSystem;
import rhythm.Note.NoteKind;
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
    private var activeNotes:Array<Note> = [];

    private var chart:ChartHandler;
    private var conductor:Conductor;
    private var judgement:JudgementSystem;

    public var spawnAheadMs:Float = 2000;

    private var heldLanes:Map<Int, Bool> = [];
    private var sustainingLanes:Map<Int, Bool> = [];

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
        onNoteHit = new FlxTypedSignal();
        onNoteMiss = new FlxTypedSignal();
        onGhostTap = new FlxTypedSignal();
    }

    public function update():Void
    {
        var nowMs = conductor.songPositionMs;

        spawnNotes(nowMs);
        handleAnimationOnlyNotes(nowMs);
        handleSustainTicks(nowMs);
        handleMisses(nowMs);
    }

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
        if (target.kind == NoteKind.HOLD_HEAD)
        {
            sustainingLanes.set(inputLane, true);
        }

        onNoteHit.dispatch(target, rating);
    }

    public function onKeyRelease(inputLane:Int):Void
    {
        var wasSustaining = sustainingLanes.exists(inputLane) && sustainingLanes.get(inputLane);
        heldLanes.set(inputLane, false);

        if (!wasSustaining)
        {
            return;
        }

        var nowMs = conductor.songPositionMs;
        var tail = findTailForLane(inputLane, nowMs);

        if (tail == null)
        {
            sustainingLanes.remove(inputLane);
            return;
        }

        consumeNote(tail);
        sustainingLanes.remove(inputLane);
        onNoteHit.dispatch(tail, judgement.judgeRelease(nowMs - tail.timeMs));
    }

    private function handleAnimationOnlyNotes(nowMs:Float):Void
    {
        var autoplayWindow = 50.0;
        var toAutoplay:Array<Note> = [];

        for (note in activeNotes)
        {
            if (note.isJudged) continue;
            if (note.judged) continue;

            var timeDiff = Math.abs(nowMs - note.timeMs);
            if (timeDiff <= autoplayWindow && nowMs >= note.timeMs)
            {
                toAutoplay.push(note);
            }
        }

        for (note in toAutoplay)
        {
            if (note.kind == NoteKind.TAP || note.kind == NoteKind.HOLD_HEAD)
            {
                onNoteHit.dispatch(note, HitRating.SICK);
            }

            consumeNote(note);
        }
    }

    private function handleSustainTicks(nowMs:Float):Void
    {
        var missWindow = judgement.maxHitWindowMs();
        var toMiss:Array<Note> = [];

        for (note in activeNotes)
        {
            if (!note.isJudged) continue;
            if (note.judged) continue;
            if (note.kind != NoteKind.HOLD_TICK) continue;
            if (nowMs < note.timeMs) continue;

            var isSustaining = sustainingLanes.exists(note.inputLane) && sustainingLanes.get(note.inputLane);
            var keyHeld = heldLanes.exists(note.inputLane) && heldLanes.get(note.inputLane);

            if (isSustaining && keyHeld)
            {
                consumeNote(note);
            }
            else if (nowMs > note.timeMs + missWindow)
            {
                toMiss.push(note);
            }
        }

        for (note in toMiss)
        {
            sustainingLanes.remove(note.inputLane);
            consumeNote(note);
            onNoteMiss.dispatch(note);
        }
    }

    private function handleMisses(nowMs:Float):Void
    {
        var missWindow = judgement.maxHitWindowMs();
        var toRemove:Array<Note> = [];

        for (note in activeNotes)
        {
            if (!note.isJudged) continue;
            if (note.judged) continue;
            if (note.kind == NoteKind.HOLD_TICK) continue;

            if (nowMs > note.timeMs + missWindow)
            {
                toRemove.push(note);
            }
        }

        for (note in toRemove)
        {
            if (note.kind == NoteKind.HOLD_HEAD || note.kind == NoteKind.HOLD_TAIL)
            {
                sustainingLanes.remove(note.inputLane);
            }

            consumeNote(note);
            onNoteMiss.dispatch(note);
        }
    }

    private function findHittableNote(inputLane:Int, nowMs:Float):Note
    {
        var window = judgement.maxHitWindowMs();
        var best:Note = null;
        var bestDiff = Math.POSITIVE_INFINITY;

        for (note in activeNotes)
        {
            if (!note.isJudged) continue;
            if (note.judged) continue;
            if (note.inputLane != inputLane) continue;
            if (note.kind == NoteKind.HOLD_TICK || note.kind == NoteKind.HOLD_TAIL) continue;

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
            if (!note.isJudged) continue;
            if (note.judged) continue;
            if (note.inputLane != inputLane) continue;
            if (note.kind != NoteKind.HOLD_TAIL) continue;

            if (Math.abs(note.timeMs - nowMs) <= window)
            {
                return note;
            }
        }

        return null;
    }

    private function consumeNote(note:Note):Void
    {
        note.judged = true;
        activeNotes.remove(note);
    }

    public inline function getActiveCount():Int
    {
        return activeNotes.length;
    }

    public function getHittableNoteForLane(inputLane:Int):Note
    {
        return findHittableNote(inputLane, conductor.songPositionMs);
    }

    public function getTailInWindow(inputLane:Int):Note
    {
        return findTailForLane(inputLane, conductor.songPositionMs);
    }

    public function isLaneSustaining(inputLane:Int):Bool
    {
        return sustainingLanes.exists(inputLane) && sustainingLanes.get(inputLane);
    }

    public function isLaneHeld(inputLane:Int):Bool
    {
        return heldLanes.exists(inputLane) && heldLanes.get(inputLane);
    }
}
