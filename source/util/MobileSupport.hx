package util;

import flixel.FlxG;
import flixel.FlxSprite;

class MobileSupport
{
	public static inline function isMobile():Bool
	{
		return FlxG.onMobile;
	}

	// =========================================================================
	// Safe area insets
	// Safe areas account for display cutouts (notches/punch-holes) and system
	// bars on mobile devices. In landscape on Android the cutout is on the
	// left or right short edge; navigation gesture bars add bottom inset.
	// All layout functions below incorporate these automatically.
	// =========================================================================

	/**
	 * Horizontal safe inset (each side) in game pixels.
	 * Keeps UI away from left/right edge cutouts in landscape.
	 */
	public static inline function safeX():Float
	{
		return isMobile() ? 48 : 0;
	}

	/**
	 * Vertical safe inset (each side) in game pixels.
	 * Keeps UI away from top status bar remnants and bottom nav bar.
	 */
	public static inline function safeY():Float
	{
		return isMobile() ? 24 : 0;
	}

	// Shorthand accessors used internally
	private static inline function sw():Float { return FlxG.width; }
	private static inline function sh():Float { return FlxG.height; }

	// =========================================================================
	// Dialogue
	// =========================================================================

	public static inline function dialogueMargin():Float
	{
		// left/right margin: safe zone + inner padding
		return safeX() + (isMobile() ? 16 : 40);
	}

	public static inline function dialogueBottomMargin():Float
	{
		// keep dialogue box above nav bar
		return safeY() + (isMobile() ? 12 : 40);
	}

	public static inline function dialogueHeight():Int
	{
		return isMobile() ? 176 : 120;
	}

	public static inline function dialogueFontSize():Int
	{
		return isMobile() ? 28 : 20;
	}

	// =========================================================================
	// Title / menu
	// =========================================================================

	public static inline function titleMenuX():Float
	{
		// Push menu buttons away from left-edge cutout
		return safeX() + (isMobile() ? 24 : 40);
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

	// =========================================================================
	// Choices
	// =========================================================================

	public static inline function choiceSideMargin():Float
	{
		// Keep choice buttons away from side cutouts
		return safeX() + (isMobile() ? 20 : 60);
	}

	public static inline function choiceBottomMargin():Float
	{
		return safeY() + (isMobile() ? 20 : 36);
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

	// =========================================================================
	// Rhythm touch pads
	// =========================================================================

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
		// Keep pads above the bottom nav bar gesture area
		return safeY() + (isMobile() ? 10 : 0);
	}

	public static inline function rhythmPadIdleAlpha():Float
	{
		return isMobile() ? 0.24 : 0;
	}

	public static inline function rhythmPadPressedAlpha():Float
	{
		return isMobile() ? 0.55 : 0;
	}

	// =========================================================================
	// Pause / overlay buttons
	// =========================================================================

	/**
	 * X position for a top-right corner icon (pause button etc.).
	 * Pulled inward from the right edge to avoid cutout areas.
	 */
	public static inline function topRightIconX():Float
	{
		return FlxG.width - safeX() - (isMobile() ? 52 : 52);
	}

	/**
	 * Y position for a top-edge icon.
	 */
	public static inline function topIconY():Float
	{
		return safeY() + (isMobile() ? 12 : 12);
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
