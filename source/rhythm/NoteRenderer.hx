package rhythm;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import rhythm.ArrowRenderer;
import rhythm.Conductor;
import rhythm.Note.NoteKind;
import rhythm.Note;

/**
 * NoteRenderer
 * ============
 * Visual-only note renderer.
 */
class NoteRenderer extends FlxGroup
{
    public static var NOTE_ASSET_PATH:String = "assets/images/ui/arrows/note.png";
    public static var NOTE_WIDTH:Int = 32;
    public static var NOTE_HEIGHT:Int = 32;
    public static var VISUAL_SCALE:Float = 1.0;
    public static var DEBUG_FALLBACK:Bool = true;

    public static var SPAWN_AHEAD_MS:Float = 2000;
    public static var SPAWN_RADIUS:Float = 400;

    private var conductor:Conductor;
    private var arrowRenderer:ArrowRenderer;

    private var activeNotes:Map<Note, FlxSprite> = [];

    public function new(conductor:Conductor, arrowRenderer:ArrowRenderer)
    {
        super();

        this.conductor = conductor;
        this.arrowRenderer = arrowRenderer;

        trace("[NoteRenderer] Initialized");
        trace("[NoteRenderer] Asset path: ${NOTE_ASSET_PATH}");
        trace("[NoteRenderer] Spawn ahead: ${SPAWN_AHEAD_MS}ms at radius ${SPAWN_RADIUS}");
    }

    public function spawnNote(note:Note):Void
    {
        // Skip hold ticks — too many, handled implicitly via hold body rendering
        if (note.kind == NoteKind.HOLD_TICK) return;

        var sprite = new FlxSprite();
        var loadSuccess = tryLoadNoteAsset(sprite);

        if (!loadSuccess && DEBUG_FALLBACK)
        {
            createDebugNote(sprite, note);
        }

        // Animation-only notes render as translucent "ghost" notes so the
        // charter and developer can see which characters are animating without
        // cluttering the judged note lane.
        if (!note.isJudged)
        {
            sprite.alpha = 0.38;
        }

        applyVisualScale(sprite);

        activeNotes.set(note, sprite);
        add(sprite);

        trace('[NoteRenderer] Spawned note: lane=${note.inputLane}, judged=${note.isJudged}, time=${note.timeMs}');
    }

    public function removeNote(note:Note):Void
    {
        if (!activeNotes.exists(note)) return;

        var sprite = activeNotes.get(note);
        activeNotes.remove(note);
        remove(sprite);
        sprite.destroy();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        var nowMs = conductor.songPositionMs;
        for (note => sprite in activeNotes)
        {
            updateNotePosition(note, sprite, nowMs);
        }
    }

    private function updateNotePosition(note:Note, sprite:FlxSprite, nowMs:Float):Void
    {
        var timeUntilHit = note.timeMs - nowMs;
        var progress = timeUntilHit / SPAWN_AHEAD_MS;
        progress = Math.max(0, Math.min(1, progress));

        var centerX = ArrowRenderer.LAYOUT_CENTER_X >= 0
            ? ArrowRenderer.LAYOUT_CENTER_X
            : flixel.FlxG.width / 2;
        var centerY = ArrowRenderer.LAYOUT_CENTER_Y >= 0
            ? ArrowRenderer.LAYOUT_CENTER_Y
            : (flixel.FlxG.height / 2) + ArrowRenderer.LAYOUT_CENTER_Y_OFFSET;

        var anglePerLane = (Math.PI * 2) / 4;

        // For judged notes use inputLane (0-3) to align with the actual receptor.
        // For animation-only notes (inputLane == -1) use animDirection so they still
        // travel along the correct radial track, just rendered at reduced alpha.
        var visualLane = note.isJudged ? note.inputLane : note.animDirection;

        var receptorPos = arrowRenderer.getReceptorPosition(visualLane);
        var angle = ArrowRenderer.LAYOUT_START_ANGLE + (visualLane * anglePerLane);

        var spawnX = centerX + Math.cos(angle) * SPAWN_RADIUS;
        var spawnY = centerY + Math.sin(angle) * SPAWN_RADIUS;

        var currentX = spawnX + (receptorPos.x - spawnX) * (1 - progress);
        var currentY = spawnY + (receptorPos.y - spawnY) * (1 - progress);

        sprite.x = currentX - (sprite.width / 2);
        sprite.y = currentY - (sprite.height / 2);
    }

    private function tryLoadNoteAsset(sprite:FlxSprite):Bool
    {
        try
        {
            sprite.loadGraphic(NOTE_ASSET_PATH, false, NOTE_WIDTH, NOTE_HEIGHT);
            return sprite.frames != null;
        }
        catch (e:Dynamic)
        {
            trace('[NoteRenderer] Asset load failed: ${e}');
            return false;
        }
    }

    private function createDebugNote(sprite:FlxSprite, note:Note):Void
    {
        var color = switch (note.inputLane)
        {
            case 0: 0xFFFF0000;
            case 1: 0xFF00FF00;
            case 2: 0xFF0000FF;
            case 3: 0xFFFFFF00;
            default: 0xFFFFFFFF;
        };

        sprite.makeGraphic(NOTE_WIDTH, NOTE_HEIGHT, color);
    }

    private function applyVisualScale(sprite:FlxSprite):Void
    {
        if (sprite == null || VISUAL_SCALE == 1.0)
        {
            return;
        }

        sprite.setGraphicSize(Std.int(NOTE_WIDTH * VISUAL_SCALE), Std.int(NOTE_HEIGHT * VISUAL_SCALE));
        sprite.updateHitbox();
    }
}
