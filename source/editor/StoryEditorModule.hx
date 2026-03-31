package editor;

import core.content.ContentRepository;
import core.content.WorkspaceService;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class StoryEditorModule extends FlxGroup implements EditorModule
{
	private static inline var MAX_VISIBLE_FILES:Int = 11;
	private static inline var MAX_VISIBLE_NODES:Int = 11;

	private var onPreview:String->String->Void;

	private var fileButtons:Array<EditorButton> = [];
	private var nodeButtons:Array<EditorButton> = [];
	private var files:Array<String> = [];
	private var nodeIds:Array<String> = [];
	private var fileScroll:Int = 0;
	private var nodeScroll:Int = 0;
	private var selectedPath:String = null;
	private var selectedNodeId:String = null;
	private var lastSavedText:String = "";

	private var statusText:FlxText;
	private var summaryText:FlxText;
	private var textArea:EditorTextArea;

	public function new(onPreview:String->String->Void)
	{
		super();
		this.onPreview = onPreview;

		var filePanel = new FlxSprite(20, 90);
		filePanel.makeGraphic(260, 560, FlxColor.fromRGB(16, 14, 24));
		add(filePanel);

		var editorPanel = new FlxSprite(300, 130);
		editorPanel.makeGraphic(680, 520, FlxColor.fromRGB(16, 14, 24));
		add(editorPanel);

		var nodePanel = new FlxSprite(1000, 90);
		nodePanel.makeGraphic(240, 560, FlxColor.fromRGB(16, 14, 24));
		add(nodePanel);

		var title = new FlxText(20, 20, 900, "Story Editor");
		title.setFormat(null, 28, FlxColor.WHITE, LEFT);
		add(title);

		var description = new FlxText(20, 54, 1180,
			"Scene-aware desktop authoring for VN JSON: validate links, inspect nodes, format output, and preview from start or the selected node.");
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
		add(new EditorButton(750, 90, 110, 32, "START", function() {
			previewStart();
		}));
		add(new EditorButton(870, 90, 110, 32, "NODE", function() {
			previewSelectedNode();
		}));

		add(new EditorButton(20, 660, 120, 32, "FILES UP", function() {
			setFileScroll(fileScroll - 1);
		}));
		add(new EditorButton(150, 660, 130, 32, "FILES DOWN", function() {
			setFileScroll(fileScroll + 1);
		}));
		add(new EditorButton(1000, 660, 110, 32, "NODES UP", function() {
			setNodeScroll(nodeScroll - 1);
		}));
		add(new EditorButton(1120, 660, 120, 32, "NODES DOWN", function() {
			setNodeScroll(nodeScroll + 1);
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
		refreshNodeList(parsed);
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
			refreshNodeList(parsed);
			updateSummary(parsed);
		}
		else
		{
			nodeIds = [];
			selectedNodeId = null;
			rebuildNodeButtons(null);
			updateSummary(null);
		}

		setStatus('Loaded ${selectedPath}', FlxColor.fromRGB(190, 180, 220));
	}

	public function getHelpText():String
	{
		return "Structured VN editor. Save and validate scene graphs, inspect node links, and launch previews from scene start or the selected node.";
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
		files = [];
		for (path in ContentRepository.listFiles("assets/data/scenes", ".json"))
		{
			if (path.indexOf("/template/") >= 0)
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

	private function refreshNodeList(data:Dynamic):Void
	{
		nodeIds = [];
		var nodes:Array<Dynamic> = data != null && data.nodes != null ? cast data.nodes : [];
		for (node in nodes)
		{
			if (node != null && node.id != null)
			{
				nodeIds.push(Std.string(node.id));
			}
		}

		if (selectedNodeId == null && data != null && data.start != null)
		{
			selectedNodeId = Std.string(data.start);
		}
		else if (selectedNodeId != null && !nodeIds.contains(selectedNodeId))
		{
			selectedNodeId = nodeIds.length > 0 ? nodeIds[0] : null;
		}

		rebuildNodeButtons(data);
	}

	private function rebuildNodeButtons(data:Dynamic):Void
	{
		for (button in nodeButtons)
		{
			remove(button, true);
			button.destroy();
		}
		nodeButtons = [];

		var end = Std.int(Math.min(nodeIds.length, nodeScroll + MAX_VISIBLE_NODES));
		var y = 102;
		for (i in nodeScroll...end)
		{
			var nodeId = nodeIds[i];
			var label = nodeId;
			var node = getNodeById(data, nodeId);
			if (node != null && node.type != null)
			{
				label = '[${node.type}] ${nodeId}';
			}
			var currentNodeId = nodeId;
			var button = new EditorButton(1010, y, 220, 30, label, function() {
				selectedNodeId = currentNodeId;
				rebuildNodeButtons(data);
				updateSummary(data);
			});
			button.setSelected(currentNodeId == selectedNodeId);
			nodeButtons.push(button);
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

	private function setNodeScroll(value:Int):Void
	{
		nodeScroll = clampScroll(value, nodeIds.length, MAX_VISIBLE_NODES);
		var parsed = parseJson(textArea.getText(), false);
		rebuildNodeButtons(parsed);
	}

	private function previewStart():Void
	{
		if (selectedPath == null)
		{
			return;
		}

		if (!save())
		{
			return;
		}

		var parsed = parseJson(textArea.getText(), false);
		var startNode = parsed != null && parsed.start != null ? Std.string(parsed.start) : null;
		onPreview(selectedPath, startNode);
	}

	private function previewSelectedNode():Void
	{
		if (selectedPath == null || selectedNodeId == null)
		{
			return;
		}

		if (!save())
		{
			return;
		}

		onPreview(selectedPath, selectedNodeId);
	}

	private function formatJson():Void
	{
		var parsed = parseJson(textArea.getText());
		if (parsed == null)
		{
			return;
		}

		textArea.setText(haxe.Json.stringify(parsed, null, "  "));
		setStatus("Formatted scene JSON", FlxColor.fromRGB(150, 210, 255));
		refreshNodeList(parsed);
		updateSummary(parsed);
	}

	private function validateCurrent():Bool
	{
		var parsed = parseJson(textArea.getText(), false);
		if (parsed == null)
		{
			setStatus("Scene JSON is invalid", FlxColor.RED);
			return false;
		}

		var issues = validateScene(parsed);
		updateSummary(parsed, issues);
		if (issues.length == 0)
		{
			setStatus("Scene validation passed", FlxColor.fromRGB(150, 255, 170));
			return true;
		}

		setStatus(issues[0], FlxColor.fromRGB(255, 210, 120));
		return false;
	}

	private function validateScene(data:Dynamic):Array<String>
	{
		var issues:Array<String> = [];
		if (data.scene_id == null || Std.string(data.scene_id) == "")
		{
			issues.push("scene_id is missing");
		}

		var nodes:Array<Dynamic> = data.nodes != null ? cast data.nodes : null;
		if (nodes == null || nodes.length == 0)
		{
			issues.push("nodes array is empty");
			return issues;
		}

		var nodeMap:Map<String, Dynamic> = new Map();
		for (node in nodes)
		{
			if (node.id == null)
			{
				issues.push("node missing id");
				continue;
			}

			var id = Std.string(node.id);
			if (nodeMap.exists(id))
			{
				issues.push('duplicate node id: ${id}');
			}
			nodeMap.set(id, node);

			if (node.type == null || Std.string(node.type) == "")
			{
				issues.push('${id}: missing type');
			}
		}

		if (data.start == null || !nodeMap.exists(Std.string(data.start)))
		{
			issues.push('start node is missing or invalid: ${data.start}');
		}

		for (node in nodes)
		{
			if (node == null || node.id == null || node.type == null)
			{
				continue;
			}

			var id = Std.string(node.id);
			var type = Std.string(node.type);
			switch (type)
			{
				case "dialogue", "narration", "action":
					validateTarget(nodeMap, id, resolveNextTarget(node), issues, "next");
				case "choice":
					if (node.choices == null)
					{
						issues.push('${id}: choices array missing');
					}
					else
					{
						var choices:Array<Dynamic> = cast node.choices;
						for (choice in choices)
						{
							if (choice == null || choice.target == null)
							{
								issues.push('${id}: choice missing target');
								continue;
							}
							validateTarget(nodeMap, id, Std.string(choice.target), issues, "choice target");
						}
					}
				case "if":
					validateTarget(nodeMap, id, node.trueNode != null ? Std.string(node.trueNode) : null, issues, "trueNode");
					validateTarget(nodeMap, id, node.falseNode != null ? Std.string(node.falseNode) : null, issues, "falseNode");
				case "jump":
					validateTarget(nodeMap, id, node.target != null ? Std.string(node.target) : null, issues, "target");
				case "game":
					validateTarget(nodeMap, id, resolveNextTarget(node), issues, "next");
					if (node.song == null || node.song == "")
					{
						issues.push('${id}: rhythm node missing song');
					}
					else
					{
						var chartPath = 'assets/data/charts/${node.song}.json';
						if (!ContentRepository.exists(chartPath))
						{
							issues.push('${id}: missing chart ${chartPath}');
						}
					}
					if (node.win_node != null)
					{
						validateTarget(nodeMap, id, Std.string(node.win_node), issues, "win_node");
					}
					if (node.fail_node != null)
					{
						validateTarget(nodeMap, id, Std.string(node.fail_node), issues, "fail_node");
					}
				case "end":
					if (node.next_scene != null && Std.string(node.next_scene) != ""
						&& !ContentRepository.exists('assets/data/${node.next_scene}'))
					{
						issues.push('${id}: next_scene missing: ${node.next_scene}');
					}
				default:
					issues.push('${id}: unsupported type ${type}');
			}
		}

		return issues;
	}

	private function updateSummary(data:Dynamic, ?issues:Array<String>):Void
	{
		if (data == null)
		{
			summaryText.text = "No scene loaded";
			return;
		}

		var nodes:Array<Dynamic> = data.nodes != null ? cast data.nodes : [];
		var selectedNode = selectedNodeId != null ? getNodeById(data, selectedNodeId) : null;
		var selectedType = selectedNode != null && selectedNode.type != null ? Std.string(selectedNode.type) : "(none)";
		var issueCount = issues != null ? issues.length : 0;
		var issueLine = issueCount > 0 ? 'Issues: ${issueCount}' : "Issues: none";
		var nodeLine = selectedNodeId != null ? 'Selected: ${selectedNodeId} (${selectedType})' : "Selected: none";
		summaryText.text =
			'Scene: ${data.scene_id}\n'
			+ 'Start: ${data.start}\n'
			+ 'Nodes: ${nodes.length}\n'
			+ '${nodeLine}\n'
			+ '${issueLine}';
	}

	private function resolveNextTarget(node:Dynamic):String
	{
		if (node.next != null && Std.string(node.next) != "")
		{
			return Std.string(node.next);
		}
		return node.id != null ? Std.string(node.id) + "_next" : null;
	}

	private function validateTarget(nodeMap:Map<String, Dynamic>, nodeId:String, target:String, issues:Array<String>, label:String):Void
	{
		if (target == null || target == "")
		{
			issues.push('${nodeId}: missing ${label}');
			return;
		}

		if (!nodeMap.exists(target))
		{
			issues.push('${nodeId}: missing ${label} target ${target}');
		}
	}

	private function getNodeById(data:Dynamic, nodeId:String):Dynamic
	{
		if (data == null || data.nodes == null || nodeId == null)
		{
			return null;
		}

		for (node in cast(data.nodes, Array<Dynamic>))
		{
			if (node != null && node.id != null && Std.string(node.id) == nodeId)
			{
				return node;
			}
		}
		return null;
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
