package states;

import core.audio.AudioSystem;
import core.state.GameState;
import core.state.ProgressService;
import core.state.SaveSystem;
import core.state.SystemOverrideService;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import ui.MenuButton;
import util.MobileSupport;

class CompletionState extends FlxState
{
	private var menuButtons:Array<MenuButton> = [];
	private var selectedIndex:Int = 0;

	override public function create():Void
	{
		super.create();

		#if FLX_MOUSE
		FlxG.mouse.visible = !MobileSupport.isMobile();
		#end

		ProgressService.ensureLoaded();
		SystemOverrideService.clearAll();
		AudioSystem.stopMusic();
		AudioSystem.playMusic("assets/music/dissonance.ogg", 0.45, "cut");

		var bg = new FlxSprite(0, 0);
		bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(8, 6, 14));
		add(bg);

		var glow = new FlxSprite(0, 0);
		glow.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(88, 42, 150));
		glow.alpha = 0.08;
		add(glow);

		var title = new FlxText(0, 80, FlxG.width, "THANK YOU FOR PLAYING");
		title.setFormat(null, MobileSupport.isMobile() ? 34 : 28, FlxColor.WHITE, CENTER);
		add(title);

		var subtitle = new FlxText(0, 126, FlxG.width, "Dissonance main route cleared");
		subtitle.setFormat(null, MobileSupport.isMobile() ? 22 : 18, FlxColor.fromRGB(185, 150, 255), CENTER);
		add(subtitle);

		var autosaveInfo = SaveSystem.getAutoSaveInfo();
		var endingCount = ProgressService.endingsSeen.length;
		var stats = new FlxText(0, 210, FlxG.width,
			'Playtime: ${SaveSystem.formatPlaytime(GameState.get().playtime)}\n'
			+ 'Endings unlocked: ${endingCount}\n'
			+ 'Latest autosave: ${autosaveInfo != null ? autosaveInfo.scene : "Unavailable"}');
		stats.setFormat(null, MobileSupport.isMobile() ? 20 : 16, FlxColor.fromRGB(220, 210, 245), CENTER);
		add(stats);

		var body = new FlxText(0, 330, FlxG.width,
			"Chapter Select and extras are now unlocked.\nUse ENTER to open them or ESC to return to the title screen.");
		body.setFormat(null, MobileSupport.isMobile() ? 20 : 16, FlxColor.fromRGB(185, 180, 210), CENTER);
		add(body);

		var baseY = MobileSupport.isMobile() ? 470 : 440;
		var spacing = MobileSupport.titleButtonSpacing();

		addMenuButton(baseY, "OPEN EXTRAS", function() {
			FlxG.switchState(() -> new ExtrasState());
		});
		addMenuButton(baseY + spacing, "RETURN TO TITLE", function() {
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
