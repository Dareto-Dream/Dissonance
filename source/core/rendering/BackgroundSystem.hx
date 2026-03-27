package core.rendering;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxTween;

class BackgroundSystem {
    private static var currentBG:FlxSprite = null;
    private static var nextBG:FlxSprite = null;
    private static var bgGroup:FlxSpriteGroup = null;

    /** Current background path (for save/load snapshots). */
    public static var currentPath:String = "";

    /**
     * Initialize with a reference to the background sprite group.
     * Must be called before set().
     */
    public static function init(group:FlxSpriteGroup):Void {
        bgGroup = group;
    }

    public static function reset():Void {
        currentBG = null;
        nextBG = null;
        bgGroup = null;
        currentPath = "";
    }

    public static function set(bg:String, transition:String = "cut", duration:Float = 0.5):Void {
        if (bgGroup == null) {
            trace("[BackgroundSystem] WARNING: bgGroup not initialized. Call init() first.");
            return;
        }

        currentPath = bg;

        try {
            nextBG = new FlxSprite(0, 0, bg);
        } catch(e:Dynamic) {
            trace("[BackgroundSystem] Warning: could not load background '" + bg + "'. Using placeholder.");
            nextBG = new FlxSprite(0, 0);
            nextBG.makeGraphic(FlxG.width, FlxG.height, 0xff222244);
        }
        nextBG.scrollFactor.set(0, 0);
        scaleToScreen(nextBG);

        switch (transition) {
            case "cut":         applyCut(bgGroup);
            case "fade":        applyFade(bgGroup, duration);
            case "crossfade":   applyCrossfade(bgGroup, duration);
            case "slide_left":  applySlide(bgGroup, -FlxG.width, 0, duration);
            case "slide_right": applySlide(bgGroup, FlxG.width, 0, duration);
            case "slide_up":    applySlide(bgGroup, 0, -FlxG.height, duration);
            case "slide_down":  applySlide(bgGroup, 0, FlxG.height, duration);
            default:
                trace("[BackgroundSystem] Unknown transition: " + transition);
                applyCut(bgGroup);
        }
    }

    private static function scaleToScreen(spr:FlxSprite):Void {
        if (spr.frameWidth <= 0 || spr.frameHeight <= 0) return;
        var scaleX = FlxG.width / spr.frameWidth;
        var scaleY = FlxG.height / spr.frameHeight;
        var scale = Math.max(scaleX, scaleY); // cover, not stretch
        spr.scale.set(scale, scale);
        spr.updateHitbox();
        // Center the sprite
        spr.x = (FlxG.width - spr.width) / 2;
        spr.y = (FlxG.height - spr.height) / 2;
    }

    private static function applyCut(group:FlxSpriteGroup):Void {
        if (currentBG != null) {
            currentBG.kill();
            group.remove(currentBG, true);
        }
        currentBG = nextBG;
        group.add(currentBG);
    }

    private static function applyFade(group:FlxSpriteGroup, duration:Float):Void {
        if (currentBG != null) {
            currentBG.kill();
            group.remove(currentBG, true);
        }
        nextBG.alpha = 0;
        group.add(nextBG);
        FlxTween.tween(nextBG, { alpha: 1 }, duration, {
            onComplete: (_) -> currentBG = nextBG
        });
    }

    private static function applyCrossfade(group:FlxSpriteGroup, duration:Float):Void {
        if (currentBG != null) {
            FlxTween.tween(currentBG, { alpha: 0 }, duration, {
                onComplete: (_) -> {
                    currentBG.kill();
                    group.remove(currentBG, true);
                }
            });
        }
        nextBG.alpha = 0;
        group.add(nextBG);
        FlxTween.tween(nextBG, { alpha: 1 }, duration, {
            onComplete: (_) -> currentBG = nextBG
        });
    }

    private static function applySlide(group:FlxSpriteGroup, dx:Float, dy:Float, duration:Float):Void {
        nextBG.x = dx;
        nextBG.y = dy;
        group.add(nextBG);

        if (currentBG != null) {
            FlxTween.tween(currentBG, {
                x: -dx,
                y: -dy,
                alpha: 0
            }, duration, {
                onComplete: (_) -> {
                    currentBG.kill();
                    group.remove(currentBG, true);
                }
            });
        }

        FlxTween.tween(nextBG, {
            x: 0,
            y: 0,
            alpha: 1
        }, duration, {
            onComplete: (_) -> currentBG = nextBG
        });
    }
}
