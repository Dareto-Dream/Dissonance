package core.dialogue;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxTimer;
import core.rendering.TextEffectSystem;
import core.rendering.TextEffectSystem.TextEffect;
import util.MobileSupport;

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
	static var persistentEffect:TextEffect = None;
	static var originalX:Float = 0;
	static var originalY:Float = 0;
	static var autoAdvanceEnabled:Bool = false;
	static var doneCallback:Void->Void = null;
	static var typewriterCompleted:Bool = false;
	static var canManualAdvance:Bool = false;

	// -------------------------------------------------
	//  INIT
	// -------------------------------------------------
	public static function init(group:FlxGroup):Void
	{
		uiGroup = group;

		// Create base box and label once
		box = new FlxSprite();
		box.scrollFactor.set(0, 0);

		label = new FlxText();
		label.scrollFactor.set(0, 0);
		applyLayout();

		uiGroup.add(box);
		uiGroup.add(label);

		box.visible = false;
		label.visible = false;

		timer = new FlxTimer();

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

			// Check if typewriter is complete and needs to advance
			if (isTypewriterEffect(currentEffect) && TextEffectSystem.isTypewriterComplete())
			{
				// Auto advance after typewriter completes (only once)
				if (autoAdvanceEnabled && doneCallback != null && !typewriterCompleted)
				{
					typewriterCompleted = true;
					trace("TYPEWRITER COMPLETE - Starting auto-advance timer");
					timer.start(0.5, function(_)
					{
						trace("TYPEWRITER AUTO-ADVANCE - Calling callback");
						hide();
						var callback = doneCallback;
						doneCallback = null;
						if (callback != null)
						{
							trace("TYPEWRITER - Executing callback");
							callback();
						}
						else
						{
							trace("TYPEWRITER ERROR - Callback was null!");
						}
					});
				}
				else if (!autoAdvanceEnabled && !typewriterCompleted)
				{
					// Enable manual advancement after typewriter completes
					typewriterCompleted = true;
					canManualAdvance = true;
					trace("TYPEWRITER COMPLETE - Manual advance enabled");
				}
			}
		}
	}

	// -------------------------------------------------
	//  MANUAL PROGRESSION
	// -------------------------------------------------
	public static function handleInput():Void
	{
		if (label == null || !label.visible || autoAdvanceEnabled || doneCallback == null)
		{
			return;
		}

		var confirmPressed = false;

		#if FLX_KEYBOARD
		confirmPressed = FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ENTER;
		#end

		if (!confirmPressed)
		{
			confirmPressed = MobileSupport.anyPointerJustPressed();
		}

		if (confirmPressed)
		{
			if (isTypewriterEffect(currentEffect) && !TextEffectSystem.isTypewriterComplete())
			{
				TextEffectSystem.completeTypewriter(label);
				typewriterCompleted = true;
				canManualAdvance = true;
				return;
			}

			if (canManualAdvance)
			{
				trace("MANUAL ADVANCE - Space/Enter pressed");
				canManualAdvance = false;
				hide();
				var callback = doneCallback;
				doneCallback = null;
				if (callback != null)
				{
					callback();
				}
			}
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
		applyLayout();
		resetTextPosition();

		// If there's a persistent effect and no node-specific effect, use persistent
		var nodeEffect = parseTextEffect(effectData);
		currentEffect = (nodeEffect != None) ? nodeEffect : persistentEffect;

		TextEffectSystem.reset();
		doneCallback = done;
		typewriterCompleted = false;
		canManualAdvance = false;

		// Show box and text
		box.visible = true;
		label.visible = true;
		label.text = speaker + ": " + text;
		label.alpha = 1;
		label.color = 0xFFFFFFFF;

		// Auto advance (unless it's typewriter - that handles its own timing in update())
		timer.cancel();
		if (autoAdvanceEnabled && !isTypewriterEffect(currentEffect))
		{
			timer.start(0.9, function(_)
			{
				trace("NORMAL AUTO-ADVANCE");
				hide();
				var callback = doneCallback;
				doneCallback = null;
				if (callback != null) callback();
			});
		}
		else if (isTypewriterEffect(currentEffect))
		{
			trace("TYPEWRITER EFFECT - Waiting for completion in update()");
		}
		else if (!autoAdvanceEnabled)
		{
			// Enable manual advancement immediately for non-typewriter effects
			canManualAdvance = true;
			trace("MANUAL ADVANCE ENABLED - Waiting for Space/Enter");
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
		applyLayout();
		resetTextPosition();

		// If there's a persistent effect and no node-specific effect, use persistent
		var nodeEffect = parseTextEffect(effectData);
		currentEffect = (nodeEffect != None) ? nodeEffect : persistentEffect;

		TextEffectSystem.reset();
		doneCallback = done;
		typewriterCompleted = false;
		canManualAdvance = false;

		box.visible = true;
		label.visible = true;
		label.text = text;
		label.alpha = 1;
		label.color = 0xFFFFFFFF;

		timer.cancel();
		if (autoAdvanceEnabled && !isTypewriterEffect(currentEffect))
		{
			timer.start(0.9, function(_)
			{
				trace("NORMAL AUTO-ADVANCE");
				hide();
				var callback = doneCallback;
				doneCallback = null;
				if (callback != null) callback();
			});
		}
		else if (isTypewriterEffect(currentEffect))
		{
			trace("TYPEWRITER EFFECT - Waiting for completion in update()");
		}
		else if (!autoAdvanceEnabled)
		{
			// Enable manual advancement immediately for non-typewriter effects
			canManualAdvance = true;
			trace("MANUAL ADVANCE ENABLED - Waiting for Space/Enter");
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
		if (timer != null)
		{
			timer.cancel();
		}

		if (box == null || label == null)
		{
			return;
		}

		box.visible = false;
		label.visible = false;
		label.text = "";
		resetTextPosition();
		currentEffect = persistentEffect; // Keep persistent effect
		canManualAdvance = false;
	}

	private static function resetTextPosition():Void
	{
		if (label != null)
		{
			label.x = originalX;
			label.y = originalY;
		}
	}

	private static function applyLayout():Void
	{
		if (box == null || label == null)
		{
			return;
		}

		var margin = MobileSupport.dialogueMargin();
		var bottomMargin = MobileSupport.dialogueBottomMargin();
		var boxHeight = MobileSupport.dialogueHeight();
		var padding = MobileSupport.isMobile() ? 24 : 20;
		var boxWidth = FlxG.width - (margin * 2);

		box.x = margin;
		box.y = FlxG.height - boxHeight - bottomMargin;
		box.makeGraphic(Std.int(boxWidth), boxHeight, 0xaa000000);
		box.scrollFactor.set(0, 0);

		label.x = box.x + padding;
		label.y = box.y + (MobileSupport.isMobile() ? 18 : 10);
		label.fieldWidth = boxWidth - (padding * 2);
		label.setFormat(null, MobileSupport.dialogueFontSize(), 0xFFFFFFFF, "left");
		label.scrollFactor.set(0, 0);

		originalX = label.x;
		originalY = label.y;
	}

	public static function setEffect(effectData:Dynamic):Void
	{
		persistentEffect = parseTextEffect(effectData);
		currentEffect = persistentEffect;
		TextEffectSystem.reset();
		trace("SET PERSISTENT EFFECT: " + persistentEffect);
	}

	public static function clearEffect():Void
	{
		persistentEffect = None;
		currentEffect = None;
		resetTextPosition();
		if (label != null)
		{
			label.alpha = 1;
			label.color = 0xFFFFFFFF;
		}
		trace("CLEARED PERSISTENT EFFECT");
	}

	public static function setAutoAdvance(enabled:Bool):Void
	{
		autoAdvanceEnabled = enabled;
	}

	public static function isAutoAdvanceEnabled():Bool
	{
		return autoAdvanceEnabled;
	}

	public static function isVisible():Bool
	{
		return label != null && label.visible;
	}

	public static function forceAdvance():Bool
	{
		if (label == null || !label.visible || doneCallback == null)
		{
			return false;
		}

		if (isTypewriterEffect(currentEffect) && !TextEffectSystem.isTypewriterComplete())
		{
			TextEffectSystem.completeTypewriter(label);
			typewriterCompleted = true;
			canManualAdvance = true;
			return true;
		}

		hide();
		var callback = doneCallback;
		doneCallback = null;
		if (callback != null)
		{
			callback();
		}

		return true;
	}

	private static function isTypewriterEffect(effect:TextEffect):Bool
	{
		return switch(effect)
		{
			case Typewriter(_): true;
			default: false;
		}
	}
}
