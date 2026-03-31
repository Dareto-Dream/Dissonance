package states;

import core.audio.AudioSystem;
import core.content.ContentRepository;
import core.content.WorkspaceService;
import core.state.GameState;
import core.state.SaveRestoreContext;
import core.state.SystemOverrideService;
import editor.ChartEditorModule;
import editor.ConditionEditorModule;
import editor.EditorButton;
import editor.EditorModule;
import editor.FileEditorModule;
import editor.StoryEditorModule;
import editor.TextEffectsEditorModule;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import rhythm.RhythmCompletionBridge;
import vn.VNReturnContext;

class EditorState extends FlxState
{
	private var initialModule:String;
	private var sidebarBg:FlxSprite;
	private var helpText:FlxText;
	private var moduleButtons:Array<EditorButton> = [];
	private var moduleNames:Array<String> = [];
	private var modules:Map<String, FlxGroup> = new Map();
	private var editors:Map<String, EditorModule> = new Map();
	private var currentModuleName:String = null;
	private var backButton:EditorButton;
	private var statusText:FlxText;

	public function new(?initialModule:String = "Story")
	{
		super();
		this.initialModule = initialModule;
	}

	override public function create():Void
	{
		super.create();
		#if FLX_MOUSE
		FlxG.mouse.visible = true;
		#end

		AudioSystem.stopMusic();

		var bg = new FlxSprite(0, 0);
		bg.makeGraphic(1280, 720, FlxColor.fromRGB(10, 10, 16));
		bg.scrollFactor.set(0, 0);
		add(bg);

		sidebarBg = new FlxSprite(0, 0);
		sidebarBg.makeGraphic(260, 720, FlxColor.fromRGB(18, 14, 28));
		sidebarBg.scrollFactor.set(0, 0);
		add(sidebarBg);

		var title = new FlxText(20, 18, 220, "EDITOR HUB");
		title.setFormat(null, 24, FlxColor.WHITE, LEFT);
		title.scrollFactor.set(0, 0);
		add(title);

		buildModules();
		buildSidebar();

		helpText = new FlxText(280, 670, 960, "");
		helpText.setFormat(null, 13, FlxColor.fromRGB(190, 180, 220), LEFT);
		helpText.scrollFactor.set(0, 0);
		add(helpText);

		statusText = new FlxText(280, 638, 960, "");
		statusText.setFormat(null, 13, FlxColor.fromRGB(255, 210, 120), LEFT);
		statusText.scrollFactor.set(0, 0);
		add(statusText);

		backButton = new EditorButton(20, 668, 220, 32, "RETURN TO TITLE", function() {
			exitToTitle();
		});
		add(backButton);

		switchModule(initialModule);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if FLX_KEYBOARD
		if (FlxG.keys.justPressed.ESCAPE)
		{
			exitToTitle();
			return;
		}
		#end
	}

	private function buildModules():Void
	{
		registerModule("Story", new StoryEditorModule(previewSceneFromNode));

		registerModule("Charts", new ChartEditorModule(playtestChart));

		registerModule("Preview", new FileEditorModule(
			"Scene Preview",
			"Scene browser for quick preview launches without editing.",
			"assets/data/scenes",
			".json",
			"Select a scene and press PREVIEW.",
			"PREVIEW",
			previewScene,
			function(path:String) return path.indexOf("/template/") < 0,
			true
		));

		registerModule("Placements", new FileEditorModule(
			"Placement Editor",
			"Edit character placement JSON directly from the game workspace.",
			"assets/data/placements",
			".json"
		));

		registerModule("Characters", new FileEditorModule(
			"Character Data",
			"Edit rhythm and registry character JSON files.",
			"assets/data/characters",
			".json",
			null,
			null,
			null,
			function(path:String) return !StringTools.endsWith(path, "poses.json")
		));

		registerModule("Poses", new FileEditorModule(
			"Pose Editor",
			"Edit pose JSON files from the built-in workspace.",
			"assets/data/characters",
			"poses.json"
		));

		registerModule("XML", new FileEditorModule(
			"XML Viewer",
			"Inspect and patch character atlas XML files directly.",
			"assets/images/characters",
			".xml"
		));

		registerModule("Conditions", new ConditionEditorModule());
		registerModule("Text FX", new TextEffectsEditorModule());
	}

	private function buildSidebar():Void
	{
		var y = 70;
		for (name in moduleNames)
		{
			var moduleName = name;
			var button = new EditorButton(20, y, 220, 32, moduleName.toUpperCase(), function() {
				switchModule(moduleName);
			});
			moduleButtons.push(button);
			add(button);
			y += 40;
		}
	}

	private function registerModule(name:String, module:EditorModule):Void
	{
		var group:FlxGroup = cast module;
		moduleNames.push(name);
		modules.set(name, group);
		editors.set(name, module);
		add(group);
		module.exit();
	}

	private function switchModule(name:String):Void
	{
		if (currentModuleName == name)
		{
			return;
		}

		if (currentModuleName != null && editors.exists(currentModuleName))
		{
			var previous = editors.get(currentModuleName);
			if (previous.hasUnsavedChanges())
			{
				if (!previous.save())
				{
					showStatus("Fix invalid or unsaved changes before switching modules.", FlxColor.fromRGB(255, 120, 120));
					return;
				}
			}
			previous.exit();
		}

		currentModuleName = name;
		if (editors.exists(name))
		{
			editors.get(name).enter();
			helpText.text = editors.get(name).getHelpText();
			showDirtyStatus();
		}

		for (i in 0...moduleButtons.length)
		{
			moduleButtons[i].setSelected(moduleNames[i] == currentModuleName);
		}
	}

	private function previewScene(path:String):Void
	{
		previewSceneFromNode(path, null);
	}

	private function previewSceneFromNode(path:String, ?node:String):Void
	{
		var module = editors.get(currentModuleName);
		if (module != null && module.hasUnsavedChanges())
		{
			if (!module.save())
			{
				showStatus("Preview blocked until the current editor content saves cleanly.", FlxColor.fromRGB(255, 120, 120));
				return;
			}
		}

		GameState.reset();
		SaveRestoreContext.clear();
		SystemOverrideService.clearAll();
		VNReturnContext.clear();
		RhythmCompletionBridge.clear();
		var scenePath = path.substr("assets/data/".length);
		FlxG.switchState(() -> new VNState(scenePath, null, node));
	}

	private function playtestChart(path:String):Void
	{
		var module = editors.get(currentModuleName);
		if (module != null && module.hasUnsavedChanges())
		{
			if (!module.save())
			{
				showStatus("Playtest blocked until the current chart saves cleanly.", FlxColor.fromRGB(255, 120, 120));
				return;
			}
		}

		var songId = resolveSongId(path);
		var nextState = new rhythm.RhythmState();
		nextState.song = songId;
		nextState.chartPath = path;
		nextState.returnStateFactory = () -> new EditorState("Charts");
		nextState.onComplete = null;
		FlxG.switchState(() -> nextState);
	}

	private function exitToTitle():Void
	{
		for (name in editors.keys())
		{
			var module = editors.get(name);
			if (module.hasUnsavedChanges())
			{
				if (!module.save())
				{
					showStatus('Cannot leave editor: ${name} has unsaved or invalid changes.', FlxColor.fromRGB(255, 120, 120));
					return;
				}
			}
		}

		WorkspaceService.clear();
		SaveRestoreContext.clear();
		SystemOverrideService.clearAll();
		VNReturnContext.clear();
		RhythmCompletionBridge.clear();
		FlxG.switchState(() -> new TitleState());
	}

	private function resolveSongId(path:String):String
	{
		var fallback = path.substr(path.lastIndexOf("/") + 1);
		if (StringTools.endsWith(fallback, ".json"))
		{
			fallback = fallback.substr(0, fallback.length - ".json".length);
		}

		try
		{
			var data:Dynamic = haxe.Json.parse(ContentRepository.readText(path));
			if (data != null && data.song != null && Reflect.hasField(data.song, "song"))
			{
				var explicitSong = Std.string(Reflect.field(data.song, "song"));
				if (explicitSong != null && explicitSong != "")
				{
					return explicitSong;
				}
			}
		}
		catch (_:Dynamic) {}

		return fallback;
	}

	private function showDirtyStatus():Void
	{
		var dirtyCount = WorkspaceService.dirtyCount();
		if (dirtyCount > 0)
		{
			showStatus('Workspace dirty: ${dirtyCount} file(s) pending save.', FlxColor.fromRGB(255, 210, 120));
		}
		else
		{
			showStatus("Workspace clean.", FlxColor.fromRGB(150, 255, 170));
		}
	}

	private function showStatus(message:String, color:Int):Void
	{
		if (statusText == null)
		{
			return;
		}

		statusText.text = message;
		statusText.color = color;
	}
}
