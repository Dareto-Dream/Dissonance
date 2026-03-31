package editor;

import core.content.ContentRepository;
import core.content.WorkspaceService;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class ChartEditorModule extends FlxGroup implements EditorModule
{
	private static inline var MAX_VISIBLE_FILES:Int = 11;
	private static inline var MAX_VISIBLE_SECTIONS:Int = 11;

	private var onPlaytest:String->Void;

	private var fileButtons:Array<EditorButton> = [];
	private var sectionButtons:Array<EditorButton> = [];
	private var files:Array<String> = [];
	private var sectionLabels:Array<String> = [];
	private var fileScroll:Int = 0;
	private var sectionScroll:Int = 0;
	private var selectedPath:String = null;
	private var selectedSection:Int = 0;
	private var lastSavedText:String = "";

	private var statusText:FlxText;
	private var summaryText:FlxText;
	private var textArea:EditorTextArea;

	public function new(onPlaytest:String->Void)
	{
		super();
		this.onPlaytest = onPlaytest;

		var filePanel = new FlxSprite(20, 90);
		filePanel.makeGraphic(260, 560, FlxColor.fromRGB(16, 14, 24));
		add(filePanel);

		var editorPanel = new FlxSprite(300, 130);
		editorPanel.makeGraphic(680, 520, FlxColor.fromRGB(16, 14, 24));
		add(editorPanel);

		var sectionPanel = new FlxSprite(1000, 90);
		sectionPanel.makeGraphic(240, 560, FlxColor.fromRGB(16, 14, 24));
		add(sectionPanel);

		var title = new FlxText(20, 20, 900, "Chart Editor");
		title.setFormat(null, 28, FlxColor.WHITE, LEFT);
		add(title);

		var description = new FlxText(20, 54, 1180,
			"Chart-aware desktop authoring for rhythm JSON: inspect sections, validate note structure, format output, and launch playtests directly.");
		description.setFormat(null, 14, FlxColor.fromRGB(200, 190, 230), LEFT);
		add(description);

		add(new EditorButton(300, 90, 100, 32, "SAVE", function() {
			save();
		}));
		add(new EditorButton(410, 90, 100, 32, "RELOAD", function() {
			load();
		}));
		add(new EditorButton(520, 90, 100, 32, "FORMAT", function() {
			formatJson();
		}));
		add(new EditorButton(630, 90, 110, 32, "VALIDATE", function() {
			validateCurrent();
		}));
		add(new EditorButton(750, 90, 120, 32, "PLAYTEST", function() {
			playtestCurrent();
		}));

		add(new EditorButton(20, 660, 120, 32, "FILES UP", function() {
			setFileScroll(fileScroll - 1);
		}));
		add(new EditorButton(150, 660, 130, 32, "FILES DOWN", function() {
			setFileScroll(fileScroll + 1);
		}));
		add(new EditorButton(1000, 660, 110, 32, "SECTIONS UP", function() {
			setSectionScroll(sectionScroll - 1);
		}));
		add(new EditorButton(1120, 660, 120, 32, "SECTIONS DOWN", function() {
			setSectionScroll(sectionScroll + 1);
		}));

		statusText = new FlxText(300, 660, 680, "");
		statusText.setFormat(null, 14, FlxColor.fromRGB(190, 180, 220), LEFT);
		add(statusText);

		summaryText = new FlxText(1000, 34, 240, "");
		summaryText.setFormat(null, 13, FlxColor.fromRGB(190, 180, 220), LEFT);
		add(summaryText);

		textArea = new EditorTextArea(310, 140, 660, 500, true);
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
		return selectedPath != null && textArea.getText() != lastSavedText;
	}

	public function save():Bool
	{
		if (selectedPath == null)
		{
			return false;
		}

		var text = textArea.getText();
		var parsed = parseJson(text);
		if (parsed == null)
		{
			return false;
		}

		WorkspaceService.stageText(selectedPath, text);
		if (!WorkspaceService.save(selectedPath))
		{
			setStatus('Failed to save ${selectedPath}', FlxColor.RED);
			return false;
		}

		lastSavedText = text;
		refreshSectionList(parsed);
		var valid = validateCurrent();
		setStatus(valid ? 'Saved ${selectedPath}' : 'Saved with validation warnings', valid
			? FlxColor.fromRGB(150, 255, 170)
			: FlxColor.fromRGB(255, 210, 120));
		return true;
	}

	public function load():Void
	{
		if (selectedPath == null && files.length > 0)
		{
			selectFile(files[0]);
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

		var parsed = parseJson(text, false);
		if (parsed != null)
		{
			refreshSectionList(parsed);
			updateSummary(parsed);
		}
		else
		{
			sectionLabels = [];
			selectedSection = 0;
			rebuildSectionButtons(null);
			updateSummary(null);
		}

		setStatus('Loaded ${selectedPath}', FlxColor.fromRGB(190, 180, 220));
	}

	public function getHelpText():String
	{
		return "Structured rhythm editor. Validate section layout and note data, then launch a playtest directly from the selected chart.";
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!visible)
		{
			return;
		}

		#if FLX_KEYBOARD
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
		{
			save();
		}
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.R)
		{
			load();
		}
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.F)
		{
			formatJson();
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
		files = ContentRepository.listFiles("assets/data/charts", ".json");
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
		load();
	}

	private function rebuildFileButtons():Void
	{
		for (button in fileButtons)
		{
			remove(button, true);
			button.destroy();
		}
		fileButtons = [];

		var end = Std.int(Math.min(files.length, fileScroll + MAX_VISIBLE_FILES));
		var y = 102;
		for (i in fileScroll...end)
		{
			var path = files[i];
			var filePath = path;
			var button = new EditorButton(30, y, 240, 30, shortenPath(filePath), function() {
				selectFile(filePath);
			});
			button.setSelected(filePath == selectedPath);
			fileButtons.push(button);
			add(button);
			y += 36;
		}
	}

	private function refreshSectionList(data:Dynamic):Void
	{
		sectionLabels = [];
		var sections:Array<Dynamic> = extractSections(data);
		for (i in 0...sections.length)
		{
			var section = sections[i];
			var noteCount = section != null && section.sectionNotes != null
				? cast(section.sectionNotes, Array<Dynamic>).length
				: 0;
			sectionLabels.push('S${i + 1} (${noteCount})');
		}

		if (selectedSection >= sectionLabels.length)
		{
			selectedSection = Std.int(Math.max(0, sectionLabels.length - 1));
		}

		rebuildSectionButtons(data);
	}

	private function rebuildSectionButtons(data:Dynamic):Void
	{
		for (button in sectionButtons)
		{
			remove(button, true);
			button.destroy();
		}
		sectionButtons = [];

		var end = Std.int(Math.min(sectionLabels.length, sectionScroll + MAX_VISIBLE_SECTIONS));
		var y = 102;
		for (i in sectionScroll...end)
		{
			var label = sectionLabels[i];
			var sectionIndex = i;
			var button = new EditorButton(1010, y, 220, 30, label, function() {
				selectedSection = sectionIndex;
				rebuildSectionButtons(data);
				updateSummary(data);
			});
			button.setSelected(sectionIndex == selectedSection);
			sectionButtons.push(button);
			add(button);
			y += 36;
		}
	}

	private function selectFile(path:String):Void
	{
		selectedPath = path;
		fileScroll = clampScroll(fileScroll, files.length, MAX_VISIBLE_FILES);
		rebuildFileButtons();
		load();
		textArea.focus();
	}

	private function setFileScroll(value:Int):Void
	{
		fileScroll = clampScroll(value, files.length, MAX_VISIBLE_FILES);
		rebuildFileButtons();
	}

	private function setSectionScroll(value:Int):Void
	{
		sectionScroll = clampScroll(value, sectionLabels.length, MAX_VISIBLE_SECTIONS);
		var parsed = parseJson(textArea.getText(), false);
		rebuildSectionButtons(parsed);
	}

	private function playtestCurrent():Void
	{
		if (selectedPath == null)
		{
			return;
		}

		if (!save())
		{
			return;
		}

		onPlaytest(selectedPath);
	}

	private function formatJson():Void
	{
		var parsed = parseJson(textArea.getText());
		if (parsed == null)
		{
			return;
		}

		textArea.setText(haxe.Json.stringify(parsed, null, "  "));
		setStatus("Formatted chart JSON", FlxColor.fromRGB(150, 210, 255));
		refreshSectionList(parsed);
		updateSummary(parsed);
	}

	private function validateCurrent():Bool
	{
		var parsed = parseJson(textArea.getText(), false);
		if (parsed == null)
		{
			setStatus("Chart JSON is invalid", FlxColor.RED);
			return false;
		}

		var issues = validateChart(parsed);
		updateSummary(parsed, issues);
		if (issues.length == 0)
		{
			setStatus("Chart validation passed", FlxColor.fromRGB(150, 255, 170));
			return true;
		}

		setStatus(issues[0], FlxColor.fromRGB(255, 210, 120));
		return false;
	}

	private function validateChart(data:Dynamic):Array<String>
	{
		var issues:Array<String> = [];
		if (data.song == null)
		{
			issues.push("song object is missing");
			return issues;
		}

		if (data.song.song == null || Std.string(data.song.song) == "")
		{
			issues.push("song.song is missing");
		}
		if (data.song.bpm == null)
		{
			issues.push("song.bpm is missing");
		}
		if (data.song.notes == null)
		{
			issues.push("song.notes is missing");
			return issues;
		}

		var sections:Array<Dynamic> = cast data.song.notes;
		for (sectionIndex in 0...sections.length)
		{
			var section = sections[sectionIndex];
			if (section.sectionNotes == null)
			{
				issues.push('section ${sectionIndex + 1}: sectionNotes missing');
				continue;
			}

			for (noteIndex in 0...cast(section.sectionNotes, Array<Dynamic>).length)
			{
				var note:Dynamic = cast(section.sectionNotes, Array<Dynamic>)[noteIndex];
				if (!Std.isOfType(note, Array))
				{
					issues.push('section ${sectionIndex + 1}: note ${noteIndex + 1} is not an array');
					continue;
				}

				var raw:Array<Dynamic> = cast note;
				if (raw.length < 2)
				{
					issues.push('section ${sectionIndex + 1}: note ${noteIndex + 1} needs at least [time, lane]');
					continue;
				}

				var time = Std.parseFloat(Std.string(raw[0]));
				if (Math.isNaN(time))
				{
					issues.push('section ${sectionIndex + 1}: note ${noteIndex + 1} has invalid time');
				}

				var lane = Std.parseInt(Std.string(raw[1]));
				if (lane == null)
				{
					issues.push('section ${sectionIndex + 1}: note ${noteIndex + 1} has invalid lane');
				}

				if (raw.length > 2)
				{
					var hold = Std.parseFloat(Std.string(raw[2]));
					if (Math.isNaN(hold))
					{
						issues.push('section ${sectionIndex + 1}: note ${noteIndex + 1} has invalid hold length');
					}
				}
			}
		}

		return issues;
	}

	private function updateSummary(data:Dynamic, ?issues:Array<String>):Void
	{
		if (data == null || data.song == null)
		{
			summaryText.text = "No chart loaded";
			return;
		}

		var sections:Array<Dynamic> = extractSections(data);
		var section = selectedSection >= 0 && selectedSection < sections.length ? sections[selectedSection] : null;
		var noteCount = 0;
		for (entry in sections)
		{
			if (entry != null && entry.sectionNotes != null)
			{
				noteCount += cast(entry.sectionNotes, Array<Dynamic>).length;
			}
		}

		var sectionSummary = section != null
			? 'Selected: S${selectedSection + 1}\nBPM: ${section.bpm != null ? section.bpm : data.song.bpm}\nNotes: ${section.sectionNotes != null ? cast(section.sectionNotes, Array<Dynamic>).length : 0}'
			: "Selected: none";
		var issueCount = issues != null ? issues.length : 0;
		var fileId = selectedPath != null ? shortenPath(selectedPath) : "(none)";
		var audioSong = data.song.song != null ? Std.string(data.song.song) : "(missing)";

		summaryText.text =
			'File: ${fileId}\n'
			+ 'Song: ${audioSong}\n'
			+ 'BPM: ${data.song.bpm}\n'
			+ 'Sections: ${sections.length}\n'
			+ 'Total Notes: ${noteCount}\n'
			+ '${sectionSummary}\n'
			+ 'Issues: ${issueCount}';
	}

	private function extractSections(data:Dynamic):Array<Dynamic>
	{
		return data != null && data.song != null && data.song.notes != null
			? cast data.song.notes
			: [];
	}

	private function parseJson(text:String, reportErrors:Bool = true):Dynamic
	{
		try
		{
			return haxe.Json.parse(text);
		}
		catch (e:Dynamic)
		{
			if (reportErrors)
			{
				setStatus('Invalid JSON: ${e}', FlxColor.RED);
			}
			return null;
		}
	}

	private function shortenPath(path:String):String
	{
		return StringTools.startsWith(path, "assets/data/")
			? path.substr("assets/data/".length)
			: path;
	}

	private function clampScroll(value:Int, length:Int, visibleCount:Int):Int
	{
		var maxScroll = Math.max(0, length - visibleCount);
		return Std.int(Math.max(0, Math.min(value, maxScroll)));
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
