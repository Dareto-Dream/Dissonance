package util;

import flixel.FlxG;
import flixel.FlxSprite;

class MobileSupport
{
	public static inline function isMobile():Bool
	{
		return FlxG.onMobile;
	}

	public static inline function dialogueMargin():Float
	{
		return isMobile() ? 24 : 40;
	}

	public static inline function dialogueBottomMargin():Float
	{
		return isMobile() ? 20 : 40;
	}

	public static inline function dialogueHeight():Int
	{
		return isMobile() ? 176 : 120;
	}

	public static inline function dialogueFontSize():Int
	{
		return isMobile() ? 28 : 20;
	}

	public static inline function titleMenuX():Float
	{
		return isMobile() ? 60 : 40;
	}

	public static inline function titleButtonWidth():Int
	{
		return isMobile() ? 420 : 320;
	}

	public static inline function titleButtonHeight():Int
	{
		return isMobile() ? 72 : 50;
	}

	public static inline function titleButtonSpacing():Float
	{
		return isMobile() ? 86 : 70;
	}

	public static inline function titleSubtitleFontSize():Int
	{
		return isMobile() ? 24 : 16;
	}

	public static inline function titleStatusFontSize():Int
	{
		return isMobile() ? 22 : 14;
	}

	public static inline function choiceSideMargin():Float
	{
		return isMobile() ? 36 : 60;
	}

	public static inline function choiceBottomMargin():Float
	{
		return isMobile() ? 32 : 36;
	}

	public static inline function choiceButtonHeight():Float
	{
		return isMobile() ? 68 : 42;
	}

	public static inline function choiceSpacing():Float
	{
		return isMobile() ? 82 : 50;
	}

	public static inline function choiceFontSize():Int
	{
		return isMobile() ? 30 : 24;
	}

	public static inline function rhythmPadHeight():Float
	{
		return isMobile() ? 128 : 0;
	}

	public static inline function rhythmPadGap():Float
	{
		return isMobile() ? 14 : 0;
	}

	public static inline function rhythmPadBottomMargin():Float
	{
		return isMobile() ? 18 : 0;
	}

	public static inline function rhythmPadIdleAlpha():Float
	{
		return isMobile() ? 0.24 : 0;
	}

	public static inline function rhythmPadPressedAlpha():Float
	{
		return isMobile() ? 0.55 : 0;
	}

	public static function anyPointerJustPressed():Bool
	{
		#if FLX_TOUCH
		if (FlxG.touches.justStarted().length > 0)
		{
			return true;
		}
		#end

		#if FLX_MOUSE
		if (FlxG.mouse.justPressed)
		{
			return true;
		}
		#end

		return false;
	}

	public static function pointerOverlaps(target:FlxSprite):Bool
	{
		if (target == null || !target.visible)
		{
			return false;
		}

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch != null && touch.pressed && touch.overlaps(target))
			{
				return true;
			}
		}
		#end

		#if FLX_MOUSE
		if (FlxG.mouse.overlaps(target))
		{
			return true;
		}
		#end

		return false;
	}

	public static function pointerJustPressedOver(target:FlxSprite):Bool
	{
		if (target == null || !target.visible)
		{
			return false;
		}

		#if FLX_TOUCH
		for (touch in FlxG.touches.justStarted())
		{
			if (touch != null && touch.overlaps(target))
			{
				return true;
			}
		}
		#end

		#if FLX_MOUSE
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(target))
		{
			return true;
		}
		#end

		return false;
	}

	public static function pointerPressedOver(target:FlxSprite):Bool
	{
		if (target == null || !target.visible)
		{
			return false;
		}

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch != null && touch.pressed && touch.overlaps(target))
			{
				return true;
			}
		}
		#end

		#if FLX_MOUSE
		if (FlxG.mouse.pressed && FlxG.mouse.overlaps(target))
		{
			return true;
		}
		#end

		return false;
	}
}
