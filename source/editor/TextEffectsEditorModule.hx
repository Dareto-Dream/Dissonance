package editor;

import core.rendering.TextEffectSystem;
import core.rendering.TextEffectSystem.TextEffect;
import core.state.OptionsService;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class TextEffectsEditorModule extends FlxGroup implements EditorModule
{
	private var sample:FlxText;
	private var currentEffect:TextEffect = None;
	private var textArea:EditorTextArea;
	private var effectButtons:Array<EditorButton> = [];

	public function new()
	{
		super();

		var bg = new FlxSprite(20, 90);
		bg.makeGraphic(1220, 560, FlxColor.fromRGB(16, 14, 24));
		bg.scrollFactor.set(0, 0);
		add(bg);

		var title = new FlxText(20, 20, 900, "Text Effects Preview");
		title.setFormat(null, 28, FlxColor.WHITE, LEFT);
		title.scrollFactor.set(0, 0);
		add(title);

		var description = new FlxText(20, 54, 1180, "Edit the sample text below and preview the engine text effects live.");
		description.setFormat(null, 14, FlxColor.fromRGB(200, 190, 230), LEFT);
		description.scrollFactor.set(0, 0);
		add(description);

		textArea = new EditorTextArea(32, 104, 1188, 90, true);
		textArea.setText("Everything is still in tune.");

		sample = new FlxText(80, 280, 1080, textArea.getText());
		sample.setFormat(null, 28, FlxColor.WHITE, CENTER);
		sample.scrollFactor.set(0, 0);
		add(sample);

		var labels = ["NONE", "SHAKE", "GLITCH", "WAVE", "RAINBOW", "FADE", "TYPEWRITER"];
		for (i in 0...labels.length)
		{
			var idx = i;
			var button = new EditorButton(40 + (i * 170), 210, 150, 32, labels[i], function() {
				selectEffect(idx);
			});
			effectButtons.push(button);
			add(button);
		}

		exit();
	}

	public function enter():Void
	{
		visible = true;
		active = true;
		textArea.setVisible(true);
		textArea.focus();
	}

	public function exit():Void
	{
		visible = false;
		active = false;
		textArea.setVisible(false);
	}

	public function hasUnsavedChanges():Bool
	{
		return false;
	}

	public function save():Bool
	{
		return false;
	}

	public function load():Void {}

	public function getHelpText():String
	{
		return "Preview the engine's text animation effects on arbitrary copy without leaving the game.";
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!visible)
		{
			return;
		}

		sample.text = textArea.getText();
		TextEffectSystem.update(elapsed);
		TextEffectSystem.applyEffect(sample, currentEffect, elapsed);
	}

	override public function destroy():Void
	{
		textArea.destroy();
		super.destroy();
	}

	private function selectEffect(index:Int):Void
	{
		TextEffectSystem.reset();
		currentEffect = switch (index)
		{
			case 1: Shake(2.5);
			case 2: Glitch(4.0);
			case 3: Wave(3.0, 5.0);
			case 4: Rainbow(2.0);
			case 5: Fade(2.0);
			case 6: Typewriter(OptionsService.textSpeed);
			default: None;
		};

		for (i in 0...effectButtons.length)
		{
			effectButtons[i].setSelected(i == index);
		}
	}
}
