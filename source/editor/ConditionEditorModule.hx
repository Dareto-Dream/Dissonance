package editor;

import core.dialogue.ConditionParser;
import core.state.GameState;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class ConditionEditorModule extends FlxGroup implements EditorModule
{
	private var title:FlxText;
	private var description:FlxText;
	private var inputArea:EditorTextArea;
	private var evaluateButton:EditorButton;
	private var resultText:FlxText;

	public function new()
	{
		super();

		var bg = new FlxSprite(20, 90);
		bg.makeGraphic(1220, 560, FlxColor.fromRGB(16, 14, 24));
		bg.scrollFactor.set(0, 0);
		add(bg);

		title = new FlxText(20, 20, 900, "Condition Builder");
		title.setFormat(null, 28, FlxColor.WHITE, LEFT);
		title.scrollFactor.set(0, 0);
		add(title);

		description = new FlxText(20, 54, 1180, "Type a VN condition expression and evaluate it against the current GameState.");
		description.setFormat(null, 14, FlxColor.fromRGB(200, 190, 230), LEFT);
		description.scrollFactor.set(0, 0);
		add(description);

		evaluateButton = new EditorButton(20, 660, 140, 32, "EVALUATE", function() {
			evaluate();
		});
		add(evaluateButton);

		resultText = new FlxText(180, 662, 1000, "");
		resultText.setFormat(null, 16, FlxColor.fromRGB(200, 190, 230), LEFT);
		resultText.scrollFactor.set(0, 0);
		add(resultText);

		inputArea = new EditorTextArea(32, 102, 1190, 540, true);
		inputArea.setText("last_rhythm_completed == true");
		exit();
	}

	public function enter():Void
	{
		visible = true;
		active = true;
		inputArea.setVisible(true);
		inputArea.focus();
	}

	public function exit():Void
	{
		visible = false;
		active = false;
		inputArea.setVisible(false);
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
		return "Evaluate VN boolean expressions against the live GameState. Useful for branching and debug validation.";
	}

	override public function destroy():Void
	{
		inputArea.destroy();
		super.destroy();
	}

	private function evaluate():Void
	{
		var expr = StringTools.trim(inputArea.getText());
		var state = GameState.get();
		var result = ConditionParser.eval(expr);
		resultText.text = 'Result: ${result} | Scene=${state.currentScene} | Node=${state.currentNode}';
		resultText.color = result ? FlxColor.LIME : FlxColor.RED;
	}
}
