package editor;

import core.content.ContentRepository;
import core.content.WorkspaceService;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class FileEditorModule extends FlxGroup implements EditorModule
{
	private static inline var MAX_VISIBLE_FILES:Int = 14;

	private var rootPath:String;
	private var suffix:String;
	private var readOnly:Bool;
	private var primaryActionLabel:String;
	private var primaryAction:String->Void;
	private var fileFilter:String->Bool;

	private var title:FlxText;
	private var description:FlxText;
	private var listBg:FlxSprite;
	private var fileButtons:Array<EditorButton> = [];
	private var saveButton:EditorButton;
	private var reloadButton:EditorButton;
	private var primaryActionButton:EditorButton;
	private var statusText:FlxText;
	private var textArea:EditorTextArea;

	private var files:Array<String> = [];
	private var scrollIndex:Int = 0;
	private var selectedPath:String = null;
	private var lastSavedText:String = "";
	private var helpText:String;

	public function new(moduleName:String, descriptionText:String, rootPath:String, suffix:String,
		?helpText:String, ?primaryActionLabel:String, ?primaryAction:String->Void,
		?fileFilter:String->Bool, readOnly:Bool = false)
	{
		super();
		this.rootPath = rootPath;
		this.suffix = suffix;
		this.helpText = helpText != null ? helpText : descriptionText;
		this.primaryActionLabel = primaryActionLabel;
		this.primaryAction = primaryAction;
		this.fileFilter = fileFilter;
		this.readOnly = readOnly;

		listBg = new FlxSprite(20, 90);
		listBg.makeGraphic(280, 560, FlxColor.fromRGB(16, 14, 24));
		listBg.scrollFactor.set(0, 0);
		add(listBg);

		title = new FlxText(20, 20, 900, moduleName);
		title.setFormat(null, 28, FlxColor.WHITE, LEFT);
		title.scrollFactor.set(0, 0);
		add(title);

		description = new FlxText(20, 54, 1100, descriptionText);
		description.setFormat(null, 14, FlxColor.fromRGB(200, 190, 230), LEFT);
		description.scrollFactor.set(0, 0);
		add(description);

		saveButton = new EditorButton(320, 90, 120, 32, readOnly ? "REFRESH" : "SAVE", function() {
			if (readOnly)
			{
				load();
			}
			else
			{
				save();
			}
		});
		add(saveButton);

		reloadButton = new EditorButton(450, 90, 120, 32, "RELOAD", function() {
			load();
		});
		add(reloadButton);

		if (primaryActionLabel != null && primaryAction != null)
		{
			primaryActionButton = new EditorButton(580, 90, 160, 32, primaryActionLabel, function() {
				if (!readOnly)
				{
					save();
				}
				if (selectedPath != null)
				{
					primaryAction(selectedPath);
				}
			});
			add(primaryActionButton);
		}

		statusText = new FlxText(320, 128, 900, "");
		statusText.setFormat(null, 14, FlxColor.fromRGB(190, 180, 220), LEFT);
		statusText.scrollFactor.set(0, 0);
		add(statusText);

		textArea = new EditorTextArea(320, 160, 920, 490, !readOnly);
		refreshFiles();
		exit();
	}

	public function enter():Void
	{
		visible = true;
		active = true;
		textArea.setVisible(true);
	}

	public function exit():Void
	{
		visible = false;
		active = false;
		textArea.setVisible(false);
	}

	public function hasUnsavedChanges():Bool
	{
		return !readOnly && selectedPath != null && textArea.getText() != lastSavedText;
	}

	public function save():Bool
	{
		if (readOnly || selectedPath == null)
		{
			return false;
		}

		var text = textArea.getText();
		if (suffix == ".json")
		{
			try
			{
				haxe.Json.parse(text);
			}
			catch (e:Dynamic)
			{
				setStatus('Invalid JSON: ${e}', FlxColor.RED);
				return false;
			}
		}

		WorkspaceService.stageText(selectedPath, text);
		if (!WorkspaceService.save(selectedPath))
		{
			setStatus('Failed to save ${selectedPath}', FlxColor.RED);
			return false;
		}

		lastSavedText = text;
		setStatus('Saved ${selectedPath}', FlxColor.fromRGB(150, 255, 170));
		refreshFiles();
		return true;
	}

	public function load():Void
	{
		if (selectedPath == null && files.length > 0)
		{
			selectPath(files[0]);
			return;
		}

		if (selectedPath == null)
		{
			textArea.setText("");
			lastSavedText = "";
			return;
		}

		var text = WorkspaceService.getText(selectedPath);
		textArea.setText(text);
		lastSavedText = text;
		setStatus('Loaded ${selectedPath}', FlxColor.fromRGB(190, 180, 220));
	}

	public function getHelpText():String
	{
		return helpText;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!visible)
		{
			return;
		}

		#if FLX_MOUSE
		if (FlxG.mouse.wheel != 0)
		{
			var nextScroll = scrollIndex - FlxG.mouse.wheel;
			setScroll(nextScroll);
		}
		#end

		#if FLX_KEYBOARD
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S && !readOnly)
		{
			save();
		}

		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.R)
		{
			refreshFiles();
			load();
		}
		#end
	}

	override public function destroy():Void
	{
		textArea.destroy();
		super.destroy();
	}

	private function refreshFiles():Void
	{
		files = [];
		for (path in ContentRepository.listFiles(rootPath, suffix))
		{
			if (fileFilter != null && !fileFilter(path))
			{
				continue;
			}
			files.push(path);
		}

		files.sort(sortStrings);

		if (selectedPath == null && files.length > 0)
		{
			selectedPath = files[0];
		}
		else if (selectedPath != null && !files.contains(selectedPath))
		{
			selectedPath = files.length > 0 ? files[0] : null;
		}

		rebuildFileButtons();
		if (selectedPath != null)
		{
			load();
		}
	}

	private function rebuildFileButtons():Void
	{
		for (button in fileButtons)
		{
			remove(button, true);
			button.destroy();
		}
		fileButtons = [];

		var end = Std.int(Math.min(files.length, scrollIndex + MAX_VISIBLE_FILES));
		var y = 100;
		for (i in scrollIndex...end)
		{
			var path = files[i];
			var filePath = path;
			var button = new EditorButton(30, y, 260, 30, shortenPath(filePath), function() {
				selectPath(filePath);
			});
			button.setSelected(filePath == selectedPath);
			fileButtons.push(button);
			add(button);
			y += 36;
		}
	}

	private function selectPath(path:String):Void
	{
		selectedPath = path;
		rebuildFileButtons();
		load();
		textArea.focus();
	}

	private function setScroll(value:Int):Void
	{
		var maxScroll = Math.max(0, files.length - MAX_VISIBLE_FILES);
		scrollIndex = Std.int(Math.max(0, Math.min(value, maxScroll)));
		rebuildFileButtons();
	}

	private function shortenPath(path:String):String
	{
		var normalized = StringTools.replace(path, "\\", "/");
		if (StringTools.startsWith(normalized, "assets/data/"))
		{
			return normalized.substr("assets/data/".length);
		}
		if (StringTools.startsWith(normalized, "assets/images/"))
		{
			return normalized.substr("assets/images/".length);
		}
		return normalized;
	}

	private function setStatus(text:String, color:Int):Void
	{
		statusText.text = text;
		statusText.color = color;
	}

	private function sortStrings(a:String, b:String):Int
	{
		if (a < b) return -1;
		if (a > b) return 1;
		return 0;
	}
}
