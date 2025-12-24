package rhythm;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import openfl.Assets;
import rhythm.Note;
import rhythm.JudgementSystem.HitRating;

/**
 * ArrowRenderer - Visual note rendering in circle layout
 */
class ArrowRenderer extends FlxSpriteGroup {
    public var laneCount:Int;
    public var centerX:Float;
    public var centerY:Float;
    public var radius:Float;
    
    private var receptors:Array<FlxSprite>;
    private var noteVisuals:Map<Note, NoteVisual>;
    
    public static var LANE_COLORS:Array<FlxColor> = [
        0xFFC24B99, // Purple (left)
        0xFF00FFFF, // Cyan (down)
        0xFF12FA05, // Green (up)
        0xFFF9393F  // Red (right)
    ];
    
    public var conductor:Conductor;
    public var scrollSpeed:Float = 400;
    
    public function new(laneCount:Int, centerX:Float, centerY:Float, radius:Float) {
        super();
        
        this.laneCount = laneCount;
        this.centerX = centerX;
        this.centerY = centerY;
        this.radius = radius;
        
        this.receptors = [];
        this.noteVisuals = new Map();
        
        createReceptors();
    }
    
    private function createReceptors():Void {
        for (lane in 0...laneCount) {
            var angle = getLaneAngle(lane);
            var receptor = createReceptorSprite(lane);
            
            // Position on circle - AFTER sprite is fully created
            receptor.x = centerX + Math.cos(angle) * radius - receptor.width / 2;
            receptor.y = centerY + Math.sin(angle) * radius - receptor.height / 2;
            
            receptors.push(receptor);
            add(receptor);
        }
    }
    
    private function createReceptorSprite(lane:Int):FlxSprite {
        var sprite = new FlxSprite();
        var loaded = false;
        
        // Try to load asset
        var assetPath = 'assets/images/rhythm/receptor_${lane}.png';
        
        try {
            if (Assets.exists(assetPath)) {
                sprite.loadGraphic(assetPath);
                loaded = true;
                trace('Loaded receptor asset: ${assetPath} (${sprite.width}x${sprite.height})');
            }
        } catch (e:Dynamic) {
            // Asset doesn't exist, will use fallback
        }
        
        // Fallback: draw a shape
        if (!loaded) {
            sprite.makeGraphic(64, 64, FlxColor.TRANSPARENT);
            var color = LANE_COLORS[lane % LANE_COLORS.length];
            drawArrow(sprite, color, lane);
            trace('Created fallback receptor for lane ${lane} (64x64)');
        }
        
        return sprite;
    }
    
    private function drawArrow(sprite:FlxSprite, color:FlxColor, direction:Int):Void {
        // Draw filled rectangle as base
        for (x in 20...44) {
            for (y in 20...44) {
                sprite.pixels.setPixel32(x, y, color);
            }
        }
        
        // Draw arrow tip based on direction
        switch (direction % 4) {
            case 0: // Left arrow
                for (y in 24...40) {
                    for (x in (10 + Std.int((y - 24) / 2))...(20)) {
                        sprite.pixels.setPixel32(x, y, color);
                    }
                    for (x in (10 + Std.int((39 - y) / 2))...(20)) {
                        sprite.pixels.setPixel32(x, y, color);
                    }
                }
            case 1: // Down arrow
                for (x in 24...40) {
                    for (y in 44...(54 - Std.int(Math.abs(32 - x) / 2))) {
                        sprite.pixels.setPixel32(x, y, color);
                    }
                }
            case 2: // Up arrow
                for (x in 24...40) {
                    for (y in (10 + Std.int(Math.abs(32 - x) / 2))...20) {
                        sprite.pixels.setPixel32(x, y, color);
                    }
                }
            case 3: // Right arrow
                for (y in 24...40) {
                    for (x in 44...(54 - Std.int((y - 24) / 2))) {
                        sprite.pixels.setPixel32(x, y, color);
                    }
                    for (x in 44...(54 - Std.int((39 - y) / 2))) {
                        sprite.pixels.setPixel32(x, y, color);
                    }
                }
        }
        
        // Update the graphic
        sprite.dirty = true;
        sprite.updateFramePixels();
    }
    
    public function getLaneAngle(lane:Int):Float {
        var startAngle = -Math.PI / 2;
        var angleStep = (Math.PI * 2) / laneCount;
        return startAngle + (lane * angleStep);
    }
    
    public function updateLaneCount(newCount:Int):Void {
        if (newCount == laneCount) return;
        
        for (receptor in receptors) {
            remove(receptor);
            receptor.destroy();
        }
        receptors = [];
        
        laneCount = newCount;
        createReceptors();
        
        for (note => visual in noteVisuals) {
            visual.updateLane(this);
        }
    }
    
    public function addNote(note:Note):Void {
        var visual = new NoteVisual(note, this);
        noteVisuals.set(note, visual);
        add(visual);
    }
    
    public function removeNote(note:Note):Void {
        if (!noteVisuals.exists(note)) return;
        
        var visual = noteVisuals.get(note);
        remove(visual);
        visual.destroy();
        noteVisuals.remove(note);
    }
    
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        if (conductor != null) {
            var songPosMs = conductor.songPosition * 1000;
            
            for (note => visual in noteVisuals) {
                visual.updatePosition(songPosMs, scrollSpeed);
            }
        }
        
        // Cull notes that are far off screen
        var toRemove = [];
        for (note => visual in noteVisuals) {
            if (visual.y < -200 || visual.y > 1000 || visual.x < -200 || visual.x > 1600) {
                toRemove.push(note);
            }
        }
        
        for (note in toRemove) {
            removeNote(note);
        }
    }
    
    public function playHitAnimation(lane:Int, rating:HitRating):Void {
        if (lane < 0 || lane >= receptors.length) return;
        
        var receptor = receptors[lane];
        
        var scale = switch (rating) {
            case PERFECT: 1.3;
            case GREAT: 1.2;
            case GOOD: 1.1;
            default: 1.0;
        }
        
        FlxTween.tween(receptor.scale, {x: scale, y: scale}, 0.1, {
            onComplete: (_) -> {
                FlxTween.tween(receptor.scale, {x: 1.0, y: 1.0}, 0.1);
            }
        });
        
        receptor.color = FlxColor.WHITE;
        FlxTween.color(receptor, 0.2, FlxColor.WHITE, LANE_COLORS[lane % LANE_COLORS.length]);
    }
    
    public function getReceptorPosition(lane:Int):{x:Float, y:Float} {
        var angle = getLaneAngle(lane);
        return {
            x: centerX + Math.cos(angle) * radius,
            y: centerY + Math.sin(angle) * radius
        };
    }
    
    public function clearNotes():Void {
        for (note => visual in noteVisuals) {
            remove(visual);
            visual.destroy();
        }
        noteVisuals.clear();
    }
}

/**
 * NoteVisual - Individual note sprite
 */
class NoteVisual extends FlxSprite {
    private var note:Note;
    private var renderer:ArrowRenderer;
    private var targetAngle:Float;
    
    public function new(note:Note, renderer:ArrowRenderer) {
        super();
        
        this.note = note;
        this.renderer = renderer;
        this.targetAngle = renderer.getLaneAngle(note.lane);
        
        // Create the graphic FIRST
        loadGraphicForType(note.noteType);
        
        // THEN set initial position (now that width/height are known)
        var initialPosition = calculatePosition(10000); // Start far out
        this.x = initialPosition.x;
        this.y = initialPosition.y;
    }
    
    private function loadGraphicForType(type:Int):Void {
        var typeName = switch (type) {
            case 0: "normal";
            case 1: "swing";
            case 2: "orbit";
            case 3: "glitch";
            case 4: "forced";
            default: "normal";
        }
        
        var assetPath = 'assets/images/rhythm/note_${typeName}.png';
        var loaded = false;
        
        try {
            if (Assets.exists(assetPath)) {
                loadGraphic(assetPath);
                loaded = true;
                trace('Loaded note graphic: ${assetPath} (${width}x${height})');
            }
        } catch (e:Dynamic) {
            // Asset doesn't exist, will use fallback
        }
        
        if (!loaded) {
            // Fallback: draw a circle
            makeGraphic(48, 48, FlxColor.TRANSPARENT);
            
            var color = ArrowRenderer.LANE_COLORS[note.lane % ArrowRenderer.LANE_COLORS.length];
            
            // Draw filled circle
            for (x in 0...48) {
                for (y in 0...48) {
                    var dx = x - 24;
                    var dy = y - 24;
                    if (dx * dx + dy * dy <= 20 * 20) {
                        pixels.setPixel32(x, y, color);
                    }
                }
            }
            
            // Update the graphic
            dirty = true;
            updateFramePixels();
            
            trace('Created fallback note for lane ${note.lane} (48x48)');
        }
    }
    
    /**
     * Calculate position based on time until hit
     * Returns {x, y} coordinates
     */
    private function calculatePosition(songPositionMs:Float):{x:Float, y:Float} {
        var timeUntilHit = (note.time - songPositionMs) / 1000;
        var distanceFromCenter = timeUntilHit * renderer.scrollSpeed;
        var currentRadius = renderer.radius + distanceFromCenter;
        
        return {
            x: renderer.centerX + Math.cos(targetAngle) * currentRadius - width / 2,
            y: renderer.centerY + Math.sin(targetAngle) * currentRadius - height / 2
        };
    }
    
    public function updatePosition(songPositionMs:Float, scrollSpeed:Float):Void {
        var pos = calculatePosition(songPositionMs);
        this.x = pos.x;
        this.y = pos.y;
    }
    
    public function updateLane(renderer:ArrowRenderer):Void {
        this.renderer = renderer;
        this.targetAngle = renderer.getLaneAngle(note.lane);
    }
}
