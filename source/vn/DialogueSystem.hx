package vn;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxTimer;
import vn.TextEffectSystem.TextEffect;

class DialogueSystem
{
	// UI attachment point (set from VNState)
	static var uiGroup:FlxGroup;

	// Reused UI elements
	static var box:FlxSprite;
	static var label:FlxText;
	static var timer:FlxTimer;
	
	// Text effect tracking
	static var currentEffect:TextEffect = None;
	static var originalX:Float = 0;
	static var originalY:Float = 0;
	static var autoAdvanceEnabled:Bool = true;

	// -------------------------------------------------
	//  INIT
	// -------------------------------------------------
	public static function init(group:FlxGroup):Void
	{
		uiGroup = group;

		// Create base box and label once
		box = new FlxSprite(40, FlxG.height - 160);
		box.makeGraphic(FlxG.width - 80, 120, 0xaa000000);
		box.scrollFactor.set(0, 0);

		label = new FlxText(60, FlxG.height - 150, FlxG.width - 120, "");
		label.setFormat(null, 20, 0xFFFFFFFF, "left");
		label.scrollFactor.set(0, 0);

		uiGroup.add(box);
		uiGroup.add(label);

		box.visible = false;
		label.visible = false;

		timer = new FlxTimer();
		
		originalX = label.x;
		originalY = label.y;
	}
	
	// -------------------------------------------------
	//  UPDATE (call this from VNState update)
	// -------------------------------------------------
	public static function update(elapsed:Float):Void
	{
		if (label.visible && currentEffect != None)
		{
			TextEffectSystem.update(elapsed);
			TextEffectSystem.applyEffect(label, currentEffect, elapsed);
		}
	}

	// -------------------------------------------------
	//  DIALOGUE
	// -------------------------------------------------
	public static function show(speaker:String, text:String, done:Void->Void, ?effectData:Dynamic):Void
	{
        trace("DIALOGUE: " + speaker + ": " + text);

		if (uiGroup == null)
		{
            done();
            return;
        }

		// Reset position and effect
		resetTextPosition();
		currentEffect = parseTextEffect(effectData);
		TextEffectSystem.reset();

		// Show box and text
		box.visible = true;
		label.visible = true;
		label.text = speaker + ": " + text;
		label.alpha = 1;
		label.color = 0xFFFFFFFF;

		// Auto advance or wait for typewriter completion
		timer.cancel();
		if (autoAdvanceEnabled)
		{
			timer.start(0.9, function(_)
			{
				hide();
				done();
			});
		}
    }

	// -------------------------------------------------
	//  NARRATION
	// -------------------------------------------------
	public static function showNarration(text:String, done:Void->Void, ?effectData:Dynamic):Void
	{
        trace("NARRATION: " + text);
		if (uiGroup == null)
		{
            done();
            return;
        }

		// Reset position and effect
		resetTextPosition();
		currentEffect = parseTextEffect(effectData);
		TextEffectSystem.reset();

		box.visible = true;
		label.visible = true;
		label.text = text;
		label.alpha = 1;
		label.color = 0xFFFFFFFF;

		timer.cancel();
		if (autoAdvanceEnabled)
		{
			timer.start(0.9, function(_)
			{
				hide();
				done();
			});
		}
    }
	
	// -------------------------------------------------
	//  TEXT EFFECT PARSING
	// -------------------------------------------------
	private static function parseTextEffect(effectData:Dynamic):TextEffect
	{
		if (effectData == null || effectData.text_effect == null)
		{
			return None;
		}
		
		var effectType:String = effectData.text_effect;
		
		switch(effectType)
		{
			case "shake":
				var intensity = effectData.effect_intensity != null ? effectData.effect_intensity : 2.0;
				return Shake(intensity);
				
			case "glitch":
				var intensity = effectData.effect_intensity != null ? effectData.effect_intensity : 5.0;
				return Glitch(intensity);
				
			case "wave":
				var speed = effectData.effect_speed != null ? effectData.effect_speed : 3.0;
				var amplitude = effectData.effect_amplitude != null ? effectData.effect_amplitude : 5.0;
				return Wave(speed, amplitude);
				
			case "rainbow":
				var speed = effectData.effect_speed != null ? effectData.effect_speed : 2.0;
				return Rainbow(speed);
				
			case "fade":
				var speed = effectData.effect_speed != null ? effectData.effect_speed : 2.0;
				return Fade(speed);
				
			case "typewriter":
				var speed = effectData.effect_speed != null ? effectData.effect_speed : 30.0;
				return Typewriter(speed);
				
			default:
				return None;
		}
	}
	
	// -------------------------------------------------
	//  UTILITY
	// -------------------------------------------------
	public static function hide():Void
	{
		box.visible = false;
		label.visible = false;
		resetTextPosition();
		currentEffect = None;
	}
	
	private static function resetTextPosition():Void
	{
		if (label != null)
		{
			label.x = originalX;
			label.y = originalY;
		}
	}
	
	public static function setEffect(effectData:Dynamic):Void
	{
		currentEffect = parseTextEffect(effectData);
		TextEffectSystem.reset();
	}
	
	public static function clearEffect():Void
	{
		currentEffect = None;
		resetTextPosition();
		if (label != null)
		{
			label.alpha = 1;
			label.color = 0xFFFFFFFF;
		}
	}
	
	public static function setAutoAdvance(enabled:Bool):Void
	{
		autoAdvanceEnabled = enabled;
	}
}
