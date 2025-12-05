package vn;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;

enum TextEffect {
    None;
    Shake(intensity:Float);
    Glitch(intensity:Float);
    Wave(speed:Float, amplitude:Float);
    Rainbow(speed:Float);
    Fade(speed:Float);
    Typewriter(charsPerSecond:Float);
}

class TextEffectSystem {
    private static var effectTime:Float = 0;
    private static var typewriterProgress:Float = 0;
    private static var typewriterSpeed:Float = 30;
    private static var originalPositions:Array<{x:Float, y:Float}> = [];
    private static var fullText:String = "";
    private static var isTypewriterActive:Bool = false;
    
    public static function update(elapsed:Float):Void {
        effectTime += elapsed;
    }
    
    public static function reset():Void {
        effectTime = 0;
        typewriterProgress = 0;
        originalPositions = [];
        fullText = "";
        isTypewriterActive = false;
    }
    
    public static function applyEffect(textField:FlxText, effect:TextEffect, elapsed:Float):Void {
        switch(effect) {
            case None:
                // Do nothing
                
            case Shake(intensity):
                applyShake(textField, intensity);
                
            case Glitch(intensity):
                applyGlitch(textField, intensity);
                
            case Wave(speed, amplitude):
                applyWave(textField, speed, amplitude);
                
            case Rainbow(speed):
                applyRainbow(textField, speed);
                
            case Fade(speed):
                applyFade(textField, speed);
                
            case Typewriter(charsPerSecond):
                applyTypewriter(textField, charsPerSecond, elapsed);
        }
    }
    
    private static function applyShake(textField:FlxText, intensity:Float):Void {
        if (originalPositions.length == 0) {
            originalPositions.push({x: textField.x, y: textField.y});
        }
        
        var offsetX = (Math.random() - 0.5) * intensity * 2;
        var offsetY = (Math.random() - 0.5) * intensity * 2;
        
        textField.x = originalPositions[0].x + offsetX;
        textField.y = originalPositions[0].y + offsetY;
    }
    
    private static function applyGlitch(textField:FlxText, intensity:Float):Void {
        if (Math.random() < 0.1) {
            var offsetX = (Math.random() - 0.5) * intensity * 4;
            var offsetY = (Math.random() - 0.5) * intensity * 2;
            
            if (originalPositions.length == 0) {
                originalPositions.push({x: textField.x, y: textField.y});
            }
            
            textField.x = originalPositions[0].x + offsetX;
            textField.y = originalPositions[0].y + offsetY;
            
            // Random color tint for glitch effect
            if (Math.random() < 0.3) {
                var colors = [0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFFFFFF00, 0xFFFF00FF];
                textField.color = colors[Math.floor(Math.random() * colors.length)];
            } else {
                textField.color = 0xFFFFFFFF;
            }
        } else {
            if (originalPositions.length > 0) {
                textField.x = originalPositions[0].x;
                textField.y = originalPositions[0].y;
            }
            textField.color = 0xFFFFFFFF;
        }
    }
    
    private static function applyWave(textField:FlxText, speed:Float, amplitude:Float):Void {
        if (originalPositions.length == 0) {
            originalPositions.push({x: textField.x, y: textField.y});
        }
        
        var wave = Math.sin(effectTime * speed) * amplitude;
        textField.y = originalPositions[0].y + wave;
    }
    
    private static function applyRainbow(textField:FlxText, speed:Float):Void {
        var hue = (effectTime * speed * 100) % 360;
        textField.color = FlxColor.fromHSB(hue, 1.0, 1.0);
    }
    
    private static function applyFade(textField:FlxText, speed:Float):Void {
        var fade = (Math.sin(effectTime * speed) + 1) / 2;
        textField.alpha = 0.3 + (fade * 0.7);
    }
    
    private static function applyTypewriter(textField:FlxText, charsPerSecond:Float, elapsed:Float):Void {
        if (!isTypewriterActive || fullText == "") {
            fullText = textField.text;
            typewriterProgress = 0;
            typewriterSpeed = charsPerSecond;
            isTypewriterActive = true;
            trace("TYPEWRITER START: " + fullText.length + " chars at " + charsPerSecond + " cps");
        }
        
        if (typewriterProgress < fullText.length) {
            typewriterProgress += charsPerSecond * elapsed;
            
            var currentLength = Math.floor(Math.min(typewriterProgress, fullText.length));
            textField.text = fullText.substr(0, currentLength);
            
            // Debug trace every 10 characters
            if (currentLength % 10 == 0 && currentLength > 0) {
                trace("TYPEWRITER: " + currentLength + "/" + fullText.length);
            }
        } else {
            textField.text = fullText;
        }
    }
    
    public static function isTypewriterComplete():Bool {
        if (!isTypewriterActive) return true;
        return fullText == "" || typewriterProgress >= fullText.length;
    }
    
    public static function completeTypewriter(textField:FlxText):Void {
        if (fullText != "") {
            textField.text = fullText;
            typewriterProgress = fullText.length;
        }
    }
}
