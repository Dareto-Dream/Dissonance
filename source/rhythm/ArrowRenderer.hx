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
 * 
 * This class handles all visual aspects of the rhythm game.
 * Notes are positioned in a circle around the center of the screen.
 * 
 * Key features:
 * - Circle-based layout
 * - Dynamic lane count support
 * - Asset loading with fallback rendering
 * - Position-based scrolling (not frame-based)
 * 
 * Layout:
 * - Receptors are placed on a circle at fixed radius
 * - Notes spawn outside the circle and move inward
 * - Hit point is when note reaches receptor
 * 
 * Usage:
 *   renderer = new ArrowRenderer(4, centerX, centerY, 200);
 *   renderer.addNote(note);
 *   renderer.update(elapsed, scrollSpeed, songPosition);
 */
class ArrowRenderer extends FlxSpriteGroup {
    // Configuration
    public var laneCount:Int;
    public var centerX:Float;
    public var centerY:Float;
    public var radius:Float;
    
    // Visual elements
    private var receptors:Array<FlxSprite>;
    private var noteVisuals:Map<Note, NoteVisual>;
    
    // Colors for fallback rendering
    public static var LANE_COLORS:Array<FlxColor> = [
        0xFFC24B99, // Purple (left)
        0xFF00FFFF, // Cyan (down)
        0xFF12FA05, // Green (up)
        0xFFF9393F  // Red (right)
    ];
    public var conductor:Conductor;
    
    /**
     * Constructor
     * @param laneCount Number of lanes (typically 4)
     * @param centerX X position of circle center
     * @param centerY Y position of circle center
     * @param radius Radius of circle in pixels
     */
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
    
    /**
     * Create receptor sprites
     * Tries to load art, falls back to drawing shapes
     */
    private function createReceptors():Void {
        for (lane in 0...laneCount) {
            var angle = getLaneAngle(lane);
            var receptor = createReceptorSprite(lane);
            
            // Position on circle
            receptor.x = centerX + Math.cos(angle) * radius - receptor.width / 2;
            receptor.y = centerY + Math.sin(angle) * radius - receptor.height / 2;
            
            receptors.push(receptor);
            add(receptor);
        }
    }
    
    /**
     * Create a single receptor sprite
     * Tries to load from assets, draws fallback if missing
     */
    private function createReceptorSprite(lane:Int):FlxSprite {
        var sprite = new FlxSprite();
        
        // Try to load asset
        var assetPath = 'assets/images/rhythm/receptor_${lane}.png';
        var loaded = false;
        
        try {
            if (Assets.exists(assetPath)) {
                sprite.loadGraphic(assetPath);
                loaded = true;
            }
        } catch (e:Dynamic) {
            trace('Could not load receptor asset: ${assetPath}');
        }
        
        // Fallback: draw a shape
        if (!loaded) {
            sprite.makeGraphic(64, 64, FlxColor.TRANSPARENT);
            
            // Draw arrow shape
            var color = LANE_COLORS[lane % LANE_COLORS.length];
            drawArrow(sprite, color, lane);
        }
        
        return sprite;
    }
    
    /**
     * Draw a fallback arrow on sprite
     */
    private function drawArrow(sprite:FlxSprite, color:FlxColor, direction:Int):Void {
        // Simple arrow drawing
        // This creates a basic arrow shape pointing in the direction
        sprite.makeGraphic(64, 64, FlxColor.TRANSPARENT);
        
        // Draw filled rectangle as base
        for (x in 20...44) {
            for (y in 20...44) {
                sprite.pixels.setPixel32(x, y, color);
            }
        }
        
        // Draw arrow tip based on direction
        // 0=left, 1=down, 2=up, 3=right
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
    }
    
    /**
     * Get the angle for a lane on the circle
     * @param lane Lane index
     * @return Angle in radians
     */
    public function getLaneAngle(lane:Int):Float {
        // Start at top (-90°), distribute evenly
        var startAngle = -Math.PI / 2;
        var angleStep = (Math.PI * 2) / laneCount;
        return startAngle + (lane * angleStep);
    }
    
    /**
     * Update lane count (for dynamic sections)
     * Recreates receptors in new layout
     */
    public function updateLaneCount(newCount:Int):Void {
        if (newCount == laneCount) return;
        
        // Remove old receptors
        for (receptor in receptors) {
            remove(receptor);
            receptor.destroy();
        }
        receptors = [];
        
        laneCount = newCount;
        createReceptors();
        
        // Update existing note positions
        for (note => visual in noteVisuals) {
            visual.updateLane(this);
        }
    }
    
    /**
     * Add a note to be rendered
     * @param note The note to render
     */
    public function addNote(note:Note):Void {
        var visual = new NoteVisual(note, this);
        noteVisuals.set(note, visual);
        add(visual);
    }
    
    /**
     * Remove a note from rendering
     * @param note The note to remove
     */
    public function removeNote(note:Note):Void {
        if (!noteVisuals.exists(note)) return;
        
        var visual = noteVisuals.get(note);
        remove(visual);
        visual.destroy();
        noteVisuals.remove(note);
    }
    
    /**
     * Update all note positions
     * CRITICAL: Uses song position, NOT frame time
     * 
     * @param elapsed Frame time (for sprite animation only)
     * @param scrollSpeed Scroll speed in pixels per second
     * @param songPosition Current song position in MILLISECONDS
     */
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        // Note: Actual position updates happen in NoteVisual
        // This just checks for culling
        var toRemove = [];
        for (note => visual in noteVisuals) {
            // Cull if too far off screen
            if (visual.y < -100 || visual.y > 800 || visual.x < -100 || visual.x > 1400) {
                toRemove.push(note);
            }
        }
        
        for (note in toRemove) {
            removeNote(note);
        }
    }
    
    /**
     * Play hit animation on receptor
     * @param lane Which lane was hit
     * @param rating How accurate the hit was
     */
    public function playHitAnimation(lane:Int, rating:HitRating):Void {
        if (lane < 0 || lane >= receptors.length) return;
        
        var receptor = receptors[lane];
        
        // Scale based on rating
        var scale = switch (rating) {
            case PERFECT: 1.3;
            case GREAT: 1.2;
            case GOOD: 1.1;
            default: 1.0;
        }
        
        // Tween animation
        FlxTween.tween(receptor.scale, {x: scale, y: scale}, 0.1, {
            onComplete: (_) -> {
                FlxTween.tween(receptor.scale, {x: 1.0, y: 1.0}, 0.1);
            }
        });
        
        // Flash color
        receptor.color = FlxColor.WHITE;
        FlxTween.color(receptor, 0.2, FlxColor.WHITE, LANE_COLORS[lane % LANE_COLORS.length]);
    }
    
    /**
     * Get receptor position for a lane
     * Used by NoteVisual for positioning
     */
    public function getReceptorPosition(lane:Int):{x:Float, y:Float} {
        var angle = getLaneAngle(lane);
        return {
            x: centerX + Math.cos(angle) * radius,
            y: centerY + Math.sin(angle) * radius
        };
    }
    
    /**
     * Clear all notes (for restarts)
     */
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
 * Handles position updates and rendering for a single note
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
        
        loadGraphicForType(note.noteType);
    }
    
    /**
     * Load graphic based on note type
     * Falls back to drawn shape if asset missing
     */
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
            }
        } catch (e:Dynamic) {
            trace('Could not load note asset: ${assetPath}');
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
        }
    }
    
    /**
     * Update position based on song position
     * CRITICAL: Position is derived from time difference, not frame movement
     * 
     * @param songPosition Current song position in MILLISECONDS
     * @param scrollSpeed Pixels per second
     */
    public function updatePosition(songPosition:Float, scrollSpeed:Float):Void {
        // Time until note should be hit
        var timeUntilHit = (note.time - songPosition) / 1000; // Convert to seconds
        
        // Distance from center based on time
        var distanceFromCenter = timeUntilHit * scrollSpeed;
        
        // Current radius (spawn far out, move inward)
        var currentRadius = renderer.radius + distanceFromCenter;
        
        // Position on circle arc
        x = renderer.centerX + Math.cos(targetAngle) * currentRadius - width / 2;
        y = renderer.centerY + Math.sin(targetAngle) * currentRadius - height / 2;
    }
    
    /**
     * Update lane angle (when lane count changes)
     */
    public function updateLane(renderer:ArrowRenderer):Void {
        this.renderer = renderer;
        this.targetAngle = renderer.getLaneAngle(note.lane);
    }
    
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        // Update position every frame based on current song time
        // This is retrieved from the parent state
        var songPos = renderer.conductor != null ? renderer.conductor.songPosition * 1000 : 0;
        updatePosition(songPos, 400); // Default scroll speed, override from state
    }
}