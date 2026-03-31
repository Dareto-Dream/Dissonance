package editor;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;

class EditorTextArea
{
	private var field:TextField;

	public function new(x:Int, y:Int, w:Int, h:Int, editable:Bool = true)
	{
		field = new TextField();
		field.defaultTextFormat = new TextFormat("Consolas", 14, 0xE8E6FF);
		field.type = editable ? TextFieldType.INPUT : TextFieldType.DYNAMIC;
		field.multiline = true;
		field.wordWrap = false;
		field.background = true;
		field.backgroundColor = 0x11111A;
		field.border = true;
		field.borderColor = 0x4C3676;
		field.textColor = 0xE8E6FF;
		field.x = x;
		field.y = y;
		field.width = w;
		field.height = h;
		field.visible = false;
		FlxG.stage.addChild(field);
	}

	public function setBounds(x:Int, y:Int, w:Int, h:Int):Void
	{
		field.x = x;
		field.y = y;
		field.width = w;
		field.height = h;
	}

	public function setText(value:String):Void
	{
		field.text = value;
	}

	public function getText():String
	{
		return field.text;
	}

	public function setVisible(value:Bool):Void
	{
		field.visible = value;
	}

	public function focus():Void
	{
		FlxG.stage.focus = field;
	}

	public function blur():Void
	{
		if (FlxG.stage.focus == field)
		{
			FlxG.stage.focus = null;
		}
	}

	public function destroy():Void
	{
		blur();
		if (field.parent != null)
		{
			field.parent.removeChild(field);
		}
	}
}
