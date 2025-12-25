package rhythm;

import flixel.FlxBasic;
import rhythm.Conductor;
import rhythm.JudgementSystem.HitRating;
import rhythm.Note.NoteKind;
import rhythm.Note.NoteOwner;
import rhythm.Note;

/**
 * CharacterAnimationBridge
 * ========================
 * Translates gameplay events into character animation triggers.
 *
 * This class:
 * - Reacts to note hit / miss events
 * - Uses beat position for idle / bop animations
 * - Does NOT affect gameplay state
 *
 * Think of this as a "signal router" between the rhythm engine
 * and character renderers.
 */
class CharacterAnimationBridge extends FlxBasic
{
    private var conductor:Conductor;

    public function new(conductor:Conductor)
    {
        super();
        this.conductor = conductor;
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        updateIdle();
    }

    // --------------------------------------------------
    // Gameplay event hooks
    // --------------------------------------------------

    public function onNoteHit(note:Note, rating:HitRating):Void
    {
        switch (note.owner)
        {
            case PLAYER:
                playPlayerSing(note);
            case OPPONENT:
                playOpponentSing(note);
        }
    }

    public function onNoteMiss(note:Note):Void
    {
        if (note.owner == PLAYER)
        {
            playPlayerMiss(note);
        }
    }

    // --------------------------------------------------
    // Beat-based idle animation
    // --------------------------------------------------

    private function updateIdle():Void
    {
        var beat = conductor.getBeatIndex();

        if ((beat & 1) == 0)
        {
            playIdleBop();
        }
    }

    // --------------------------------------------------
    // Animation routing
    // --------------------------------------------------

    private function playPlayerSing(note:Note):Void
    {
        switch (note.kind)
        {
            case TAP, HOLD_HEAD:
                triggerAnimation("player", animIndexToName(note.animLane));
            case HOLD_TICK:
            case HOLD_TAIL:
                triggerAnimation("player", "singRelease");
        }
    }

    private function playOpponentSing(note:Note):Void
    {
        // Route to specific NPC singer for duets/trios
        var character = note.singerIndex == 0 ? "opponent" : 'opponent${note.singerIndex}';

        switch (note.kind)
        {
            case TAP, HOLD_HEAD:
                triggerAnimation(character, animIndexToName(note.animLane));
            case HOLD_TICK, HOLD_TAIL:
        }
    }

    private function playPlayerMiss(note:Note):Void
    {
        triggerAnimation("player", "miss");
    }

    private function playIdleBop():Void
    {
        triggerAnimation("player", "idle");
        triggerAnimation("opponent", "idle");
    }

    private function animIndexToName(animLane:Int):String
    {
        return switch (animLane)
        {
            case 0: "singLEFT";
            case 1: "singDOWN";
            case 2: "singUP";
            case 3: "singRIGHT";
            default: "idle";
        }
    }

    private function triggerAnimation(character:String, anim:String):Void
    {
        // Hook into your actual character renderer here
    }
}
