package editor;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import util.MobileSupport;

class EditorButton extends FlxGroup
{
	private var bg:FlxSprite;
	private var label:FlxText;
	private var onClick:Void->Void;
	private var selected:Bool = false;

	public function new(x:Int, y:Int, w:Int, h:Int, text:String, onClick:Void->Void)
	{
		super();
		this.onClick = onClick;

		bg = new FlxSprite(x, y);
		bg.makeGraphic(w, h, FlxColor.fromRGB(24, 18, 36));
		bg.scrollFactor.set(0, 0);
		add(bg);

		label = new FlxText(x + 8, y, w - 16, text);
		label.setFormat(null, 14, FlxColor.fromRGB(210, 200, 245), CENTER);
		label.scrollFactor.set(0, 0);
		label.y = y + (h - label.height) / 2;
		add(label);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!visible)
		{
			return;
		}

		var hovered = MobileSupport.pointerOverlaps(bg) || MobileSupport.pointerOverlaps(label);
		if (hovered)
		{
			bg.color = FlxColor.fromRGB(52, 38, 78);
			label.color = FlxColor.WHITE;
			if (MobileSupport.pointerJustPressedOver(bg) || MobileSupport.pointerJustPressedOver(label))
			{
				if (onClick != null)
				{
					onClick();
				}
			}
		}
		else if (!selected)
		{
			bg.color = FlxColor.fromRGB(24, 18, 36);
			label.color = FlxColor.fromRGB(210, 200, 245);
		}
	}

	public function setSelected(value:Bool):Void
	{
		selected = value;
		bg.color = value ? FlxColor.fromRGB(76, 54, 118) : FlxColor.fromRGB(24, 18, 36);
		label.color = value ? FlxColor.WHITE : FlxColor.fromRGB(210, 200, 245);
	}

	public function setText(text:String):Void
	{
		label.text = text;
		label.y = bg.y + (bg.height - label.height) / 2;
	}
}
