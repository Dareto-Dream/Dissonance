package rhythm;

import rhythm.ChartData;
import rhythm.Note.NoteKind;
import rhythm.Note.NoteOwner;
import rhythm.Note;

/**
 * ChartHandler
 * ============
 * Expands Psych-style chart data into a flat, deterministic list of
 * runtime Notes.
 *
 * After construction:
 * - Notes are absolute-time (ms)
 * - Notes are fully split (no lengths)
 * - Notes are globally sorted
 *
 * Gameplay systems never touch raw chart data again.
 */
class ChartHandler
{
    private var notes:Array<Note>;
    private var index:Int = 0;

    public function new(chart:ChartData, conductor:Conductor)
    {
        notes = [];

        var sectionIndex = 0;
        var chartIndex = 0;

        for (section in chart.song.notes)
        {
            // Section-local BPM override (future-proof)
            var sectionBpm =
                section.bpm != null ? section.bpm : chart.song.bpm;

            // Pre-calc step length for this section
            var crochetMs = 60000.0 / sectionBpm;
            var stepMs = crochetMs / 4.0;

            for (raw in section.sectionNotes)
            {
                var timeMs:Float = raw[ChartConstants.IDX_TIME];
                var lane:Int = Std.int(raw[ChartConstants.IDX_LANE]);

                var holdMs:Float =
                    raw.length > ChartConstants.IDX_HOLD
                        ? raw[ChartConstants.IDX_HOLD]
                        : 0;

                var noteType:Int =
                    raw.length > ChartConstants.IDX_TYPE
                        ? Std.int(raw[ChartConstants.IDX_TYPE])
                        : ChartConstants.NOTE_NORMAL;

                var isSwing = (noteType == ChartConstants.NOTE_SWING);

                // ------------------------------------------------------------------
                // DECODE LANE (canonical interpretation)
                // ------------------------------------------------------------------
                var decoded = decodeLane(lane, section.mustHitSection, section.playerLaneCount);

                if (holdMs <= 0)
                {
                    // --------------------
                    // TAP NOTE
                    // --------------------
                    var tap = new Note(
                        timeMs,
                        lane,
                        NoteKind.TAP,
                        decoded.owner,
                        isSwing
                    );

                    tap.sectionIndex = sectionIndex;
                    tap.chartIndex = chartIndex++;

                    // Set decoded fields
                    tap.inputLane = decoded.inputLane;
                    tap.animLane = decoded.animLane;
                    tap.singerIndex = decoded.singerIndex;

                    notes.push(tap);
                }
                else
                {
                    // --------------------
                    // HOLD HEAD
                    // --------------------
                    var head = new Note(
                        timeMs,
                        lane,
                        NoteKind.HOLD_HEAD,
                        decoded.owner,
                        isSwing
                    );

                    head.sectionIndex = sectionIndex;
                    head.chartIndex = chartIndex++;

                    // Set decoded fields
                    head.inputLane = decoded.inputLane;
                    head.animLane = decoded.animLane;
                    head.singerIndex = decoded.singerIndex;

                    notes.push(head);

                    // --------------------
                    // HOLD TICKS (per step)
                    // --------------------
                    var t = timeMs + stepMs;
                    var endTime = timeMs + holdMs;

                    while (t < endTime - stepMs)
                    {
                        var tick = new Note(
                            t,
                            lane,
                            NoteKind.HOLD_TICK,
                            decoded.owner,
                            isSwing
                        );

                        tick.sectionIndex = sectionIndex;
                        tick.chartIndex = chartIndex++;

                        // Set decoded fields
                        tick.inputLane = decoded.inputLane;
                        tick.animLane = decoded.animLane;
                        tick.singerIndex = decoded.singerIndex;

                        notes.push(tick);
                        t += stepMs;
                    }

                    // --------------------
                    // HOLD TAIL
                    // --------------------
                    var tail = new Note(
                        endTime,
                        lane,
                        NoteKind.HOLD_TAIL,
                        decoded.owner,
                        isSwing
                    );

                    tail.sectionIndex = sectionIndex;
                    tail.chartIndex = chartIndex++;

                    // Set decoded fields
                    tail.inputLane = decoded.inputLane;
                    tail.animLane = decoded.animLane;
                    tail.singerIndex = decoded.singerIndex;

                    notes.push(tail);
                }
            }

            sectionIndex++;
        }

        // CRITICAL: deterministic global ordering
        notes.sort(sortNotes);
    }

    // ------------------------------------------------------------------
    // Canonical lane decoder
    // ------------------------------------------------------------------

    /**
     * Decode raw lane index into semantic gameplay fields.
     * 
     * This is the SINGLE SOURCE OF TRUTH for lane interpretation.
     * All gameplay logic MUST use decoded fields, never raw lane.
     */
    private static function decodeLane(
        lane:Int,
        mustHitSection:Bool,
        playerLaneCount:Null<Int>
    ):{ owner:NoteOwner, inputLane:Int, animLane:Int, singerIndex:Int }
    {
        var result:{ owner:NoteOwner, inputLane:Int, animLane:Int, singerIndex:Int };
        
        if (mustHitSection)
        {
            // Player section - playerLaneCount MUST be present
            if (playerLaneCount == null)
            {
                throw 'Chart error: playerLaneCount missing in mustHitSection (lane ${lane})';
            }

            if (lane < playerLaneCount)
            {
                // Player note
                result = {
                    owner: PLAYER,
                    inputLane: lane,
                    animLane: lane % 4,
                    singerIndex: -1
                };
            }
            else
            {
                // NPC note in player section
                var npcLane = lane - playerLaneCount;
                result = {
                    owner: OPPONENT,
                    inputLane: -1,
                    animLane: npcLane % 4,
                    singerIndex: Std.int(Math.floor(npcLane / 4))
                };
            }
        }
        else
        {
            // NPC section - playerLaneCount NOT consulted
            result = {
                owner: OPPONENT,
                inputLane: -1,
                animLane: lane % 4,
                singerIndex: Std.int(Math.floor(lane / 4))
            };
        }
        
        // DIAGNOSTIC: Log decode results
        var ownerStr = result.owner == PLAYER ? "PLAYER" : "OPPONENT";
        trace('[ChartHandler.decodeLane] lane=${lane}, mustHit=${mustHitSection}, playerLanes=${playerLaneCount} => owner=${ownerStr}, inputLane=${result.inputLane}, animLane=${result.animLane}, singerIndex=${result.singerIndex}');
        
        return result;
    }

    // ------------------------------------------------------------------
    // Sorting
    // ------------------------------------------------------------------

    private static function sortNotes(a:Note, b:Note):Int
    {
        if (a.timeMs < b.timeMs) return -1;
        if (a.timeMs > b.timeMs) return 1;

        // Same timestamp: use kind priority
        var pa = a.sortPriority();
        var pb = b.sortPriority();

        if (pa != pb) return pa - pb;

        // Final tie-breaker: original chart order
        return a.chartIndex - b.chartIndex;
    }

    // ------------------------------------------------------------------
    // Public API (read-only tape)
    // ------------------------------------------------------------------

    public inline function hasNext():Bool
    {
        return index < notes.length;
    }

    public inline function peek():Note
    {
        return notes[index];
    }

    public inline function pop():Note
    {
        return notes[index++];
    }

    public inline function reset():Void
    {
        index = 0;
    }

    public inline function remainingCount():Int
    {
        return notes.length - index;
    }
}
