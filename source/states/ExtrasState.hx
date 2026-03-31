package states;

import core.audio.AudioSystem;
import core.state.GameState;
import core.state.ProgressService;
import core.state.SaveRestoreContext;
import core.state.SaveSystem;
import core.state.SystemOverrideService;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import rhythm.RhythmCompletionBridge;
import ui.MenuButton;
import util.MobileSupport;
import vn.VNReturnContext;

private typedef ChapterEntry = {
	var label:String;
	var path:String;
}

class ExtrasState extends FlxState
{
	private var menuButtons:Array<MenuButton> = [];
	private var chapterEntries:Array<ChapterEntry> = [];
	private var selectedIndex:Int = 0;

	override public function create():Void
	{
		super.create();

		#if FLX_MOUSE
		FlxG.mouse.visible = !MobileSupport.isMobile();
		#end

		ProgressService.ensureLoaded();
		SystemOverrideService.clearAll();
		AudioSystem.playMusic("assets/music/dissonance.ogg", 0.45, "cut");

		var bg = new FlxSprite(0, 0);
		bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(10, 8, 18));
		add(bg);

		var title = new FlxText(0, 60, FlxG.width, "EXTRAS");
		title.setFormat(null, MobileSupport.isMobile() ? 34 : 28, FlxColor.WHITE, CENTER);
		add(title);

		var subtitle = new FlxText(0, 104, FlxG.width, "Chapter select, progress, and unlocked route data");
		subtitle.setFormat(null, MobileSupport.isMobile() ? 20 : 16, FlxColor.fromRGB(185, 150, 255), CENTER);
		add(subtitle);

		var autoInfo = SaveSystem.getAutoSaveInfo();
		var progressText = new FlxText(40, 160, FlxG.width - 80,
			'Game completed: ${ProgressService.gameCompleted ? "YES" : "NO"}\n'
			+ 'Endings: ${ProgressService.endingsSeen.join(", ")}\n'
			+ 'Last completion: ${ProgressService.lastCompletionTimestamp != "" ? ProgressService.lastCompletionTimestamp : "Unavailable"}\n'
			+ 'Autosave: ${autoInfo != null ? autoInfo.scene + " @ " + autoInfo.node : "Unavailable"}');
		progressText.setFormat(null, MobileSupport.isMobile() ? 18 : 14, FlxColor.fromRGB(220, 210, 245), CENTER);
		add(progressText);

		chapterEntries = [
			{label: "ACT 1", path: "scenes/act1/scene1.json"},
			{label: "ACT 2", path: "scenes/act2/scene1_generated.json"},
			{label: "ACT 3", path: "scenes/act3/scene1_generated.json"},
			{label: "ACT 4", path: "scenes/act4/scene1_generated.json"},
			{label: "ACT 5", path: "scenes/act5/scene1_generated.json"}
		];

		var baseY = MobileSupport.isMobile() ? 330 : 280;
		var spacing = MobileSupport.titleButtonSpacing();
		for (i in 0...chapterEntries.length)
		{
			var chapter = chapterEntries[i];
			var chapterPath = chapter.path;
			addMenuButton(baseY + (i * spacing), chapter.label, function() {
				GameState.reset();
				SaveRestoreContext.clear();
				SystemOverrideService.clearAll();
				VNReturnContext.clear();
				RhythmCompletionBridge.clear();
				AudioSystem.fadeOutMusic(0.2);
				FlxG.switchState(() -> new VNState(chapterPath));
			});
		}

		addMenuButton(baseY + (chapterEntries.length * spacing), "RETURN TO TITLE", function() {
			FlxG.switchState(() -> new TitleState());
		});

		updateSelection();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if FLX_KEYBOARD
		if (FlxG.keys.justPressed.UP)
		{
			selectedIndex--;
			if (selectedIndex < 0) selectedIndex = menuButtons.length - 1;
			updateSelection();
		}

		if (FlxG.keys.justPressed.DOWN)
		{
			selectedIndex++;
			if (selectedIndex >= menuButtons.length) selectedIndex = 0;
			updateSelection();
		}

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			menuButtons[selectedIndex].onClick();
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.switchState(() -> new TitleState());
		}
		#end
	}

	private function addMenuButton(y:Float, label:String, onClick:Void->Void):Void
	{
		var button = new MenuButton(MobileSupport.titleMenuX(), y, label, onClick);
		menuButtons.push(button);
		add(button);
	}

	private function updateSelection():Void
	{
		for (i in 0...menuButtons.length)
		{
			menuButtons[i].setSelected(i == selectedIndex);
		}
	}
}
