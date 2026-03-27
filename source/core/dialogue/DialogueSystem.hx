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
	static var uiGroup:FlxGroup;
	static var box:FlxSprite;
	static var label:FlxText;
	static var timer:FlxTimer;

	static var currentEffect:TextEffect = None;
	static var persistentEffect:TextEffect = None;
	static var originalX:Float = 0;
	static var originalY:Float = 0;
	static var autoAdvanceEnabled:Bool = false;
	static var doneCallback:Void->Void = null;
	static var typewriterCompleted:Bool = false;
	static var canManualAdvance:Bool = false;

	/** Recent dialogue entries for history/backlog. */
	public static var history:Array<DialogueEntry> = [];
	private static inline var MAX_HISTORY:Int = 100;

	// Cache box dimensions to avoid makeGraphic on every node
	private static var _lastBoxW:Int = -1;
	private static var _lastBoxH:Int = -1;

	// -------------------------------------------------
	//  INIT
	// -------------------------------------------------
	public static function init(group:FlxGroup):Void
	{
		uiGroup = group;

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
		history = [];
		_lastBoxW = -1;
		_lastBoxH = -1;
	}

	// -------------------------------------------------
	//  UPDATE
	// -------------------------------------------------
	public static function update(elapsed:Float):Void
	{
		if (label.visible && currentEffect != None)
		{
			TextEffectSystem.update(elapsed);
			TextEffectSystem.applyEffect(label, currentEffect, elapsed);

			if (isTypewriterEffect(currentEffect) && TextEffectSystem.isTypewriterComplete())
			{
				if (autoAdvanceEnabled && doneCallback != null && !typewriterCompleted)
				{
					typewriterCompleted = true;
					timer.start(0.5, function(_)
					{
						hide();
						var callback = doneCallback;
						doneCallback = null;
						if (callback != null) callback();
					});
				}
				else if (!autoAdvanceEnabled && !typewriterCompleted)
				{
					typewriterCompleted = true;
					canManualAdvance = true;
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
			return;

		var confirmPressed = false;

		#if FLX_KEYBOARD
		confirmPressed = FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ENTER;
		#end

		if (!confirmPressed)
			confirmPressed = MobileSupport.anyPointerJustPressed();

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
				canManualAdvance = false;
				hide();
				var callback = doneCallback;
				doneCallback = null;
				if (callback != null) callback();
			}
		}
	}

	// -------------------------------------------------
	//  DIALOGUE
	// -------------------------------------------------
	public static function show(speaker:String, text:String, done:Void->Void, ?effectData:Dynamic):Void
	{
		history.push({speaker: speaker, text: text});
		if (history.length > MAX_HISTORY) history.splice(0, history.length - MAX_HISTORY);

		_displayText(speaker + ": " + text, done, effectData);
	}

	// -------------------------------------------------
	//  NARRATION
	// -------------------------------------------------
	public static function showNarration(text:String, done:Void->Void, ?effectData:Dynamic):Void
	{
		history.push({speaker: null, text: text});
		if (history.length > MAX_HISTORY) history.splice(0, history.length - MAX_HISTORY);

		_displayText(text, done, effectData);
	}

	// -------------------------------------------------
	//  SHARED DISPLAY LOGIC
	// -------------------------------------------------
	private static function _displayText(displayText:String, done:Void->Void, effectData:Dynamic):Void
	{
		if (uiGroup == null)
		{
			done();
			return;
		}

		applyLayout();
		resetTextPosition();

		var nodeEffect = parseTextEffect(effectData);
		currentEffect = (nodeEffect != None) ? nodeEffect : persistentEffect;

		TextEffectSystem.reset();
		doneCallback = done;
		typewriterCompleted = false;
		canManualAdvance = false;

		box.visible = true;
		label.visible = true;
		label.text = displayText;
		label.alpha = 1;
		label.color = 0xFFFFFFFF;

		timer.cancel();
		if (autoAdvanceEnabled && !isTypewriterEffect(currentEffect))
		{
			timer.start(0.9, function(_)
			{
				hide();
				var callback = doneCallback;
				doneCallback = null;
				if (callback != null) callback();
			});
		}
		else if (!autoAdvanceEnabled && !isTypewriterEffect(currentEffect))
		{
			canManualAdvance = true;
		}
	}

	// -------------------------------------------------
	//  TEXT EFFECT PARSING
	// -------------------------------------------------
	private static function parseTextEffect(effectData:Dynamic):TextEffect
	{
		if (effectData == null || effectData.text_effect == null)
			return None;

		var effectType:String = effectData.text_effect;

		return switch (effectType)
		{
			case "shake":
				var intensity = effectData.effect_intensity != null ? effectData.effect_intensity : 2.0;
				Shake(intensity);

			case "glitch":
				var intensity = effectData.effect_intensity != null ? effectData.effect_intensity : 5.0;
				Glitch(intensity);

			case "wave":
				var speed = effectData.effect_speed != null ? effectData.effect_speed : 3.0;
				var amplitude = effectData.effect_amplitude != null ? effectData.effect_amplitude : 5.0;
				Wave(speed, amplitude);

			case "rainbow":
				var speed = effectData.effect_speed != null ? effectData.effect_speed : 2.0;
				Rainbow(speed);

			case "fade":
				var speed = effectData.effect_speed != null ? effectData.effect_speed : 2.0;
				Fade(speed);

			case "typewriter":
				var speed = effectData.effect_speed != null ? effectData.effect_speed : 30.0;
				Typewriter(speed);

			default: None;
		};
	}

	// -------------------------------------------------
	//  UTILITY
	// -------------------------------------------------
	public static function hide():Void
	{
		if (timer != null) timer.cancel();
		if (box == null || label == null) return;

		box.visible = false;
		label.visible = false;
		label.text = "";
		resetTextPosition();
		currentEffect = persistentEffect;
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
		if (box == null || label == null) return;

		var margin = MobileSupport.dialogueMargin();
		var bottomMargin = MobileSupport.dialogueBottomMargin();
		var boxHeight = MobileSupport.dialogueHeight();
		var padding = MobileSupport.isMobile() ? 24 : 20;
		var boxWidth = FlxG.width - (margin * 2);

		box.x = margin;
		box.y = FlxG.height - boxHeight - bottomMargin;
		var bw = Std.int(boxWidth);
		if (bw != _lastBoxW || boxHeight != _lastBoxH) {
			box.makeGraphic(bw, boxHeight, 0xaa000000);
			_lastBoxW = bw;
			_lastBoxH = boxHeight;
		}
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
			return false;

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
		if (callback != null) callback();

		return true;
	}

	private static function isTypewriterEffect(effect:TextEffect):Bool
	{
		return switch (effect)
		{
			case Typewriter(_): true;
			default: false;
		};
	}
}

typedef DialogueEntry = {
	speaker:String,
	text:String
};
