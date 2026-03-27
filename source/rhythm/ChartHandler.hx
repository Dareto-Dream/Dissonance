package rhythm;

import rhythm.ChartData;
import rhythm.Note.NoteKind;
import rhythm.Note;

/**
 * ChartHandler
 * ============
 * Expands Psych-style chart data into a flat, deterministic list of
 * runtime Notes.
 *
 * NEW DESIGN (Post-Refactor):
 * - No "player vs opponent" lanes
 * - Positive lanes (≥0) drive judgement + animation
 * - Negative lanes (<0) drive animation only
 * - Performers assigned from singers array
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
            
            // Track positive note counter per timestamp for sequential assignment
            var positiveCounterByTimestamp:Map<String, Int> = new Map();

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
                // DECODE LANE (NEW SEMANTICS)
                // ------------------------------------------------------------------
                var decoded = decodeLane(
                    lane,
                    section.mustHitSection,
                    section.singers,
                    positiveCounterByTimestamp,
                    timeMs
                );

                if (holdMs <= 0)
                {
                    // --------------------
                    // TAP NOTE
                    // --------------------
                    var tap = new Note(
                        timeMs,
                        lane,
                        NoteKind.TAP,
                        isSwing
                    );

                    tap.sectionIndex = sectionIndex;
                    tap.chartIndex = chartIndex++;

                    // Set decoded fields
                    tap.isJudged = decoded.isJudged;
                    tap.characterID = decoded.characterID;
                    tap.performerIndex = decoded.performerIndex;
                    tap.animDirection = decoded.animDirection;
                    tap.inputLane = decoded.inputLane;

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
                        isSwing
                    );

                    head.sectionIndex = sectionIndex;
                    head.chartIndex = chartIndex++;

                    // Set decoded fields
                    head.isJudged = decoded.isJudged;
                    head.characterID = decoded.characterID;
                    head.performerIndex = decoded.performerIndex;
                    head.animDirection = decoded.animDirection;
                    head.inputLane = decoded.inputLane;

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
                            isSwing
                        );

                        tick.sectionIndex = sectionIndex;
                        tick.chartIndex = chartIndex++;

                        // Set decoded fields (same as head)
                        tick.isJudged = decoded.isJudged;
                        tick.characterID = decoded.characterID;
                        tick.performerIndex = decoded.performerIndex;
                        tick.animDirection = decoded.animDirection;
                        tick.inputLane = decoded.inputLane;

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
                        isSwing
                    );

                    tail.sectionIndex = sectionIndex;
                    tail.chartIndex = chartIndex++;

                    // Set decoded fields (same as head)
                    tail.isJudged = decoded.isJudged;
                    tail.characterID = decoded.characterID;
                    tail.performerIndex = decoded.performerIndex;
                    tail.animDirection = decoded.animDirection;
                    tail.inputLane = decoded.inputLane;

                    notes.push(tail);
                }
            }

            sectionIndex++;
        }

        // CRITICAL: deterministic global ordering
        notes.sort(sortNotes);
    }

    // ------------------------------------------------------------------
    // Canonical lane decoder (NEW SEMANTICS)
    // ------------------------------------------------------------------

    /**
     * Decode raw lane index into semantic gameplay fields.
     * 
     * NEW DESIGN:
     * - mustHitSection determines if POSITIVE lanes are judged
     * - Positive lanes (≥0) animate from START of singers list (sequential per timestamp)
     * - Negative lanes (<0) animate from END of singers list (grouped by 4)
     * 
     * This is the SINGLE SOURCE OF TRUTH for lane interpretation.
     * All gameplay logic MUST use decoded fields, never raw lane.
     */
    private static function decodeLane(
        lane:Int,
        mustHitSection:Bool,
        singers:Array<String>,
        positiveCounterByTimestamp:Map<String, Int>,
        timeMs:Float
    ):{ isJudged:Bool, characterID:String, performerIndex:Int, animDirection:Int, inputLane:Int }
    {
        var isJudged:Bool;
        var performerIndex:Int;
        var characterID:String = "";
        var animDirection:Int;
        var inputLane:Int;
        
        // Determine if note is judged
        isJudged = mustHitSection && (lane >= 0);
        
        // Determine animation direction
        animDirection = Std.int(Math.abs(lane)) % 4;
        
        // Determine performer
        if (lane >= 0)
        {
            // POSITIVE LANE: Animate from START of singers list, sequential per timestamp

            // Convert timestamp to string key for Map lookup
            var timeKey = Std.string(timeMs);

            // Get current counter for this timestamp
            var count = positiveCounterByTimestamp.exists(timeKey)
                ? positiveCounterByTimestamp.get(timeKey)
                : 0;

            performerIndex = count;

            // Increment counter for next positive note at this timestamp
            positiveCounterByTimestamp.set(timeKey, count + 1);

            // Resolve character ID
            if (performerIndex < singers.length)
            {
                characterID = singers[performerIndex];
            }
            else
            {
                // More notes than singers - wrap or ignore (design choice: ignore animation)
                characterID = "";  // No character (will be skipped by animation bridge)
                trace('[ChartHandler] WARNING: More positive notes than singers at time ${timeMs}');
            }

            // Input lane: map to 0-3 range so keyboard bindings always work.
            // Multiple singers share the same 4 input slots (their notes don't overlap).
            inputLane = isJudged ? (lane % 4) : -1;
        }
        else
        {
            // NEGATIVE LANE: Animate from END of singers list, grouped by 4
            // Lanes -1..-4  → last singer  (all 4 directions)
            // Lanes -5..-8  → second-to-last singer
            // Formula: groupIndex = floor((absLane - 1) / 4)

            var absLane = Std.int(Math.abs(lane));
            var groupIndex = Std.int(Math.floor((absLane - 1) / 4));

            performerIndex = (singers.length - 1) - groupIndex;
            
            // Resolve character ID
            if (performerIndex >= 0 && performerIndex < singers.length)
            {
                characterID = singers[performerIndex];
            }
            else
            {
                // Group index out of range
                characterID = "";  // No character
                trace('[ChartHandler] WARNING: Negative lane group ${groupIndex} out of range for singers at time ${timeMs}');
            }
            
            // Negative lanes are never judged
            inputLane = -1;
        }
        
        return {
            isJudged: isJudged,
            characterID: characterID,
            performerIndex: performerIndex,
            animDirection: animDirection,
            inputLane: inputLane
        };
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
