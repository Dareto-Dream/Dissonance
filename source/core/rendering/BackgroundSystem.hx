package core.rendering;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxTween;
import states.VNState;

class BackgroundSystem {
    private static var currentBG:FlxSprite = null;
    private static var nextBG:FlxSprite = null;

    private static var bgGroup:FlxSpriteGroup = null;

    private static function getGroup():FlxSpriteGroup {
        if (bgGroup == null) {
            var state = cast(FlxG.state, VNState);
			bgGroup = state.bgGroup;
        }
        return bgGroup;
    }

	// Reset state when switching scenes
	public static function reset():Void
	{
		currentBG = null;
		nextBG = null;
		bgGroup = null;
	}

    public static function set(bg:String, transition:String = "cut", duration:Float = 0.5):Void {
        var group = getGroup();

        try {
            nextBG = new FlxSprite(0, 0, bg);
        } catch(e:Dynamic) {
            trace("[BackgroundSystem] Warning: could not load background '" + bg + "'. Using placeholder instead.");
            nextBG = new FlxSprite(0, 0);
            nextBG.makeGraphic(FlxG.width, FlxG.height, 0xff222244);
        }
        nextBG.scrollFactor.set(0, 0);
        scaleToScreen(nextBG);

        switch (transition) {
            case "cut":         applyCut(group);
            case "fade":        applyFade(group, duration);
            case "crossfade":   applyCrossfade(group, duration);
            case "slide_left":  applySlide(group, -FlxG.width, 0, duration);
            case "slide_right": applySlide(group, FlxG.width, 0, duration);
            case "slide_up":    applySlide(group, 0, -FlxG.height, duration);
            case "slide_down":  applySlide(group, 0, FlxG.height, duration);

            default:
                trace("[BackgroundSystem] Unknown transition: " + transition);
                applyCut(group);
        }
    }

    private static function scaleToScreen(bg:FlxSprite):Void {
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
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
