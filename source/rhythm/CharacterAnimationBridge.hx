package rhythm;

import flixel.FlxBasic;
import rhythm.CharacterSpriteManager;
import rhythm.Conductor;
import rhythm.JudgementSystem.HitRating;
import rhythm.Note.NoteKind;
import rhythm.Note;

/**
 * CharacterAnimationBridge
 * ========================
 * Translates gameplay events into character animation triggers.
 *
 * NEW DESIGN (Post-Refactor):
 * - No role-based routing
 * - Uses note.characterID directly
 * - Simpler, more direct animation dispatch
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
    private var characterSprites:CharacterSpriteManager;
    private var lastBeat:Int = -1; // Track last beat to avoid spam
    
    // Track all loaded characters for idle bop
    private var loadedCharacters:Array<String> = [];
    private var sustainingCharacters:Map<String, Int> = [];

    public function new(conductor:Conductor, characterSprites:CharacterSpriteManager)
    {
        super();
        this.conductor = conductor;
        this.characterSprites = characterSprites;
    }
    
    /**
     * Register a character for idle animations.
     * Call this when loading characters in RhythmState.
     * 
     * @param characterID Actual character ID from chart ("hanami", "tiffany", etc.)
     */
    public function registerCharacter(characterID:String):Void
    {
        if (!loadedCharacters.contains(characterID))
        {
            loadedCharacters.push(characterID);
            trace('[CharacterAnimationBridge] Registered ${characterID}');
        }
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
        // All notes trigger animations the same way now
        playPerformerSing(note);
    }

    public function onNoteMiss(note:Note):Void
    {
        // Only judged notes can be "missed" in the gameplay sense
        if (note.isJudged && note.characterID != "")
        {
            clearSustain(note.characterID);
            triggerAnimation(note.characterID, "miss");
        }
    }

    // --------------------------------------------------
    // Beat-based idle animation
    // --------------------------------------------------

    private function updateIdle():Void
    {
        var beat = conductor.getBeatIndex();

        // Only trigger on beat change (avoid per-frame spam)
        if (beat != lastBeat && (beat & 1) == 0)
        {
            playIdleBop();
            lastBeat = beat;
        }
    }

    // --------------------------------------------------
    // Animation routing (SIMPLIFIED)
    // --------------------------------------------------

    private function playPerformerSing(note:Note):Void
    {
        // Skip if no character assigned (more notes than singers)
        if (note.characterID == "") return;
        
        switch (note.kind)
        {
            case TAP, HOLD_HEAD:
                if (note.kind == HOLD_HEAD)
                {
                    beginSustain(note.characterID);
                }
                triggerAnimation(note.characterID, animDirectionToName(note.animDirection));
            case HOLD_TICK:
                // HOLD_TICK doesn't trigger new animations
            case HOLD_TAIL:
                endSustain(note.characterID);
                triggerAnimation(note.characterID, "singRelease");
        }
    }

    private function playIdleBop():Void
    {
        // Trigger idle for all loaded characters
        for (characterID in loadedCharacters)
        {
            if (isSustaining(characterID))
            {
                continue;
            }

            triggerAnimation(characterID, "idle");
        }
    }

    private function animDirectionToName(animDirection:Int):String
    {
        return switch (animDirection)
        {
            case 0: "singLEFT";
            case 1: "singDOWN";
            case 2: "singUP";
            case 3: "singRIGHT";
            default: "idle";
        }
    }

    private function triggerAnimation(characterID:String, anim:String):Void
    {
        // Direct dispatch to character sprite manager
        characterSprites.play(characterID, anim);
    }

    private function beginSustain(characterID:String):Void
    {
        var count = sustainingCharacters.exists(characterID) ? sustainingCharacters.get(characterID) : 0;
        sustainingCharacters.set(characterID, count + 1);
    }

    private function endSustain(characterID:String):Void
    {
        if (!sustainingCharacters.exists(characterID))
        {
            return;
        }

        var nextCount = sustainingCharacters.get(characterID) - 1;
        if (nextCount <= 0)
        {
            sustainingCharacters.remove(characterID);
        }
        else
        {
            sustainingCharacters.set(characterID, nextCount);
        }
    }

    private function clearSustain(characterID:String):Void
    {
        sustainingCharacters.remove(characterID);
    }

    private function isSustaining(characterID:String):Bool
    {
        return sustainingCharacters.exists(characterID) && sustainingCharacters.get(characterID) > 0;
    }
}
