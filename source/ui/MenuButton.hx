package ui;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import util.MobileSupport;

/**
 * MenuButton - Reusable styled menu button.
 *
 * Used in TitleState, PauseOverlay, and other menus.
 * Supports keyboard selection and mouse/touch hover.
 */
class MenuButton extends FlxSprite
{
	private var text:FlxText;
	private var indicator:FlxSprite;
	private var callback:Void->Void;
	private var baseColor:FlxColor = FlxColor.fromRGB(138, 43, 226);
	private var hoverColor:FlxColor = FlxColor.fromRGB(168, 73, 255);
	private var isSelected:Bool = false;

	public function new(x:Float, y:Float, label:String, callback:Void->Void)
	{
		super(x, y);

		this.callback = callback;

		var buttonWidth = MobileSupport.titleButtonWidth();
		var buttonHeight = MobileSupport.titleButtonHeight();
		var fontSize = MobileSupport.isMobile() ? 28 : 20;

		makeGraphic(buttonWidth, buttonHeight, FlxColor.fromRGB(18, 12, 32));
		alpha = 0.82;

		indicator = new FlxSprite(x - 15, y + 10);
		indicator.makeGraphic(6, Std.int(buttonHeight - 20), baseColor);
		indicator.visible = false;

		text = new FlxText(x + 20, y, buttonWidth - 28, label);
		text.setFormat(null, fontSize, baseColor, LEFT);
		text.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		text.alpha = alpha;
		indicator.alpha = alpha;

		indicator.x = x - 15;
		indicator.y = y + 10;

		if (MobileSupport.pointerOverlaps(this))
		{
			text.color = hoverColor;
			text.scale.set(1.05, 1.05);

			if (MobileSupport.pointerJustPressedOver(this))
			{
				onClick();
			}
		}
		else if (!isSelected)
		{
			text.color = baseColor;
			text.scale.set(1, 1);
		}

		text.x = x + 20;
		text.y = y + (height - text.height) / 2;
	}

	override public function draw():Void
	{
		super.draw();

		if (indicator != null && indicator.visible)
		{
			indicator.draw();
		}

		if (text != null)
		{
			text.draw();
		}
	}

	public function setSelected(selected:Bool):Void
	{
		isSelected = selected;
		indicator.visible = selected;

		if (selected)
		{
			text.color = hoverColor;
		}
		else
		{
			text.color = baseColor;
		}
	}

	public function onClick():Void
	{
		FlxTween.tween(this.scale, {x: 0.95, y: 0.95}, 0.1, {
			onComplete: function(_) {
				FlxTween.tween(this.scale, {x: 1, y: 1}, 0.1);
			}
		});

		if (callback != null)
		{
			callback();
		}
	}

	override public function destroy():Void
	{
		super.destroy();

		if (text != null)
		{
			text.destroy();
			text = null;
		}

		if (indicator != null)
		{
			indicator.destroy();
			indicator = null;
		}
	}
}
