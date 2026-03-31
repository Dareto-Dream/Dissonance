package states;

import core.audio.AudioSystem;
import core.state.GameState;
import core.state.OptionsService;
import core.state.ProgressService;
import core.state.SaveRestoreContext;
import core.state.SaveSystem;
import core.state.SystemOverrideService;
import dev.DevTools;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.Assets;
import rhythm.RhythmState;
import rhythm.RhythmCompletionBridge;
#if desktop
import states.EditorState;
#end
import states.ExtrasState;
import ui.MenuButton;
import ui.OptionsOverlay;
import ui.SaveLoadOverlay;
import util.MobileSupport;
import vn.VNReturnContext;

class TitleState extends FlxState
{
	private var logo:FlxSprite;
	private var subtitle:FlxText;
	private var menuButtons:FlxTypedGroup<MenuButton>;
	private var bgGradient:FlxSprite;
	private var bgOverlay:FlxSprite;
	private var particles:FlxTypedGroup<FlxSprite>;
	private var statusText:FlxText;
	private var devOverlayBg:FlxSprite;
	private var devOverlayText:FlxText;
	private var selectedIndex:Int = 0;
	private var bgPulseTimer:Float = 0;
	private var isTransitioning:Bool = false;
	private var saveLoadOverlay:SaveLoadOverlay;
	private var optionsOverlay:OptionsOverlay;

	override public function create():Void
	{
		super.create();

		#if FLX_MOUSE
		FlxG.mouse.visible = !MobileSupport.isMobile();
		#end

		OptionsService.ensureLoaded();
		OptionsService.apply();
		ProgressService.ensureLoaded();
		SystemOverrideService.clearAll();

		// Background
		createBackground();

		// Logo (starts large, animates to final size)
		// 907x907 logo - scale down to fit nicely in corner
		// Logo
		logo = new FlxSprite();
		if (Assets.exists("assets/images/logo.png"))
		{
			logo.loadGraphic("assets/images/logo.png");
		}
		else
		{
			logo.makeGraphic(360, 360, FlxColor.fromRGB(24, 18, 40));
		}

        // Hard anchor
        logo.origin.set(0, 0);
        logo.offset.set(0, 0);

        var startScale:Float = MobileSupport.isMobile() ? 0.7 : 0.6;
        var endScale:Float = MobileSupport.isMobile() ? 0.24 : 0.2;

        logo.setGraphicSize(Std.int(logo.frameWidth * startScale));
        logo.updateHitbox();
        logo.setPosition(40, 40);
        logo.alpha = 0;

        add(logo);

        // Fade in
        FlxTween.tween(logo, { alpha: 1 }, 0.5, {
            ease: FlxEase.quadOut,
            onComplete: function(_) {

                // NUM tween — VERSION SAFE
                FlxTween.num(
                    startScale,
                    endScale,
                    1.2,
                    { ease: FlxEase.elasticOut },
                    function(s:Float)
                    {
                        logo.setGraphicSize(Std.int(logo.frameWidth * s));
                        logo.updateHitbox();
                        logo.setPosition(40, 40); // forced pin
                    }
                );
            }
        });

		// Subtitle (positioned below the logo after it scales to ~181 pixels)
		subtitle = new FlxText(MobileSupport.titleMenuX(), MobileSupport.isMobile() ? 278 : 240, 0, "A VISUAL NOVEL");
		subtitle.setFormat(null, MobileSupport.titleSubtitleFontSize(), FlxColor.fromRGB(138, 43, 226), LEFT); // Purple
		subtitle.alpha = 0;
		add(subtitle);

		FlxTween.tween(subtitle, {alpha: 0.8}, 0.8, {
			startDelay: 1.5,
			ease: FlxEase.quadOut
		});

		// Menu buttons
		menuButtons = new FlxTypedGroup<MenuButton>();
		add(menuButtons);

		var buttonY = FlxG.height - (MobileSupport.isMobile() ? 420 : 280);
		var buttonSpacing = MobileSupport.titleButtonSpacing();

		var menuX = MobileSupport.titleMenuX();

		var menuIndex = 0;
		if (SaveSystem.hasAutoSave())
		{
			menuButtons.add(new MenuButton(menuX, buttonY + buttonSpacing * menuIndex, "CONTINUE", function() {
				continueGame();
			}));
			menuIndex++;
		}

		menuButtons.add(new MenuButton(menuX, buttonY + buttonSpacing * menuIndex, "PLAY", function() {
			startGame();
		}));
		menuIndex++;

		menuButtons.add(new MenuButton(menuX, buttonY + buttonSpacing * menuIndex, "LOAD GAME", function() {
			openLoadOverlay();
		}));
		menuIndex++;

		if (ProgressService.extrasUnlocked)
		{
			menuButtons.add(new MenuButton(menuX, buttonY + buttonSpacing * menuIndex, "EXTRAS", function() {
				openExtras();
			}));
			menuIndex++;
		}

		menuButtons.add(new MenuButton(menuX, buttonY + buttonSpacing * menuIndex, "OPTIONS", function() {
			openOptionsOverlay();
		}));
		menuIndex++;

		#if desktop
		menuButtons.add(new MenuButton(menuX, buttonY + buttonSpacing * menuIndex, "EDITOR", function() {
			openEditor();
		}));
		menuIndex++;
		#end

		statusText = new FlxText(menuX, buttonY + buttonSpacing * menuButtons.length + 12, FlxG.width - Std.int(menuX * 2), "");
		statusText.setFormat(null, MobileSupport.titleStatusFontSize(), FlxColor.fromRGB(220, 210, 255), LEFT);
		statusText.alpha = 0;
		add(statusText);

		// Animate buttons in sequence
		var delay = 2.0;
		for (i in 0...menuButtons.length)
		{
			var btn = menuButtons.members[i];
			btn.alpha = 0;
			btn.x -= 30;
			FlxTween.tween(btn, {alpha: 1, x: btn.x + 30}, 0.6, {
				startDelay: delay + (i * 0.1),
				ease: FlxEase.quadOut
			});
		}

		updateSelection();

		if (DevTools.ENABLED)
		{
			createDevOverlay();
		}

		if (ProgressService.gameCompleted)
		{
			showStatus("Main route cleared. Extras unlocked.");
		}

		// Play title music using AudioSystem (not FlxG.sound)
		AudioSystem.playMusic("assets/music/dissonance.ogg", 0.7);
	}

	private function createBackground():Void
	{
		// Load background image
		bgGradient = new FlxSprite(0, 0);
		if (Assets.exists("assets/images/title_bg.png"))
		{
			bgGradient.loadGraphic("assets/images/title_bg.png");
		}
		else
		{
			bgGradient.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(14, 10, 26));
		}
		// Scale to fill screen if needed
		bgGradient.setGraphicSize(FlxG.width, FlxG.height);
		bgGradient.updateHitbox();
		add(bgGradient);

		// Animated overlay for subtle color pulsing
		bgOverlay = new FlxSprite();
		bgOverlay.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(138, 43, 226)); // Purple
		bgOverlay.alpha = 0.03;
		add(bgOverlay);

		// Pulse the overlay
		FlxTween.tween(bgOverlay, {alpha: 0.08}, 3, {
			type: PINGPONG,
			ease: FlxEase.sineInOut
		});

		// Create floating particles
		particles = new FlxTypedGroup<FlxSprite>();
		add(particles);

		for (i in 0...20)
		{
			var particle = new FlxSprite();
			particle.makeGraphic(2, 2, FlxColor.fromRGB(138, 43, 226)); // Purple
			particle.alpha = FlxG.random.float(0.3, 0.7);
			particle.x = FlxG.random.float(0, FlxG.width);
			particle.y = FlxG.random.float(0, FlxG.height);
			particles.add(particle);

			// Animate particle floating
			var duration = FlxG.random.float(8, 15);
			var targetY = particle.y - FlxG.random.float(100, 300);
			var targetX = particle.x + FlxG.random.float(-50, 50);
			var currentParticle = particle;

			FlxTween.tween(currentParticle, {y: targetY, x: targetX}, duration, {
				type: LOOPING,
				ease: FlxEase.sineInOut,
				onComplete: function(_) {
					// Reset particle to bottom
					currentParticle.y = FlxG.height + 10;
					currentParticle.x = FlxG.random.float(0, FlxG.width);
				}
			});
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (DevTools.ENABLED)
		{
			handleDevTools();
			updateDevOverlay();
		}

		if (isTransitioning)
		{
			return;
		}

		// If save/load overlay is active, let it handle input
		if (saveLoadOverlay != null && saveLoadOverlay.isOpen)
		{
			return;
		}

		if (optionsOverlay != null && optionsOverlay.isOpen)
		{
			return;
		}

		// Subtle background color pulse
		bgPulseTimer += elapsed;
		if (bgOverlay != null)
		{
			// Create a subtle breathing effect
			var pulseAlpha = 0.05 + Math.sin(bgPulseTimer * 0.5) * 0.03;
			bgOverlay.alpha = pulseAlpha;
		}

		// Keyboard navigation
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
			menuButtons.members[selectedIndex].onClick();
		}

		#if desktop
		if (FlxG.keys.justPressed.SEVEN || FlxG.keys.justPressed.NUMPADSEVEN)
		{
			openEditor();
		}
		#end
		#end
	}

	private function updateSelection():Void
	{
		for (i in 0...menuButtons.length)
		{
			menuButtons.members[i].setSelected(i == selectedIndex);
		}
	}

	private function openLoadOverlay():Void
	{
		if (saveLoadOverlay != null)
		{
			remove(saveLoadOverlay, true);
			saveLoadOverlay.destroy();
		}

		saveLoadOverlay = new SaveLoadOverlay(LOAD, () -> {
			// On close
			if (saveLoadOverlay != null)
			{
				remove(saveLoadOverlay, true);
				saveLoadOverlay.destroy();
				saveLoadOverlay = null;
			}
		}, (data) -> {
			// On load
			if (data != null)
			{
				var state = GameState.get();
				isTransitioning = true;
				AudioSystem.fadeOutMusic(0.3);
				FlxG.camera.fade(FlxColor.BLACK, 0.3, false, function() {
					FlxG.switchState(() -> new VNState(state.currentScene, null, state.currentNode));
				});
			}
		});

		add(saveLoadOverlay);
	}

	private function startGame():Void
	{
		if (isTransitioning)
		{
			return;
		}

		isTransitioning = true;
		GameState.reset();
		SaveRestoreContext.clear();
		SystemOverrideService.clearAll();
		VNReturnContext.clear();
		RhythmCompletionBridge.clear();

		// Fade out title music before transitioning
		AudioSystem.fadeOutMusic(0.5);

		// Transition to VNState
		FlxG.camera.fade(FlxColor.BLACK, 0.5, false, function() {
			FlxG.switchState(() -> new VNState("scenes/act1/scene1.json"));
		});
	}

	#if desktop
	private function openEditor():Void
	{
		if (isTransitioning)
		{
			return;
		}

		isTransitioning = true;
		AudioSystem.fadeOutMusic(0.2);
		FlxG.camera.fade(FlxColor.BLACK, 0.2, false, function() {
			FlxG.switchState(() -> new EditorState());
		});
	}
	#else
	private function openEditor():Void
	{
		showStatus("Editor is only available on desktop builds.");
	}
	#end

	private function openOptionsOverlay():Void
	{
		if (optionsOverlay != null)
		{
			remove(optionsOverlay, true);
			optionsOverlay.destroy();
		}

		optionsOverlay = new OptionsOverlay(() -> {
			if (optionsOverlay != null)
			{
				remove(optionsOverlay, true);
				optionsOverlay.destroy();
				optionsOverlay = null;
			}
		});

		add(optionsOverlay);
	}

	private function continueGame():Void
	{
		if (isTransitioning)
		{
			return;
		}

		var data = SaveSystem.loadAutoSave();
		if (data == null)
		{
			showStatus("No autosave found.");
			return;
		}

		isTransitioning = true;
		AudioSystem.fadeOutMusic(0.3);
		FlxG.camera.fade(FlxColor.BLACK, 0.3, false, function() {
			FlxG.switchState(() -> new VNState(GameState.get().currentScene, null, GameState.get().currentNode));
		});
	}

	private function openExtras():Void
	{
		if (isTransitioning)
		{
			return;
		}

		isTransitioning = true;
		AudioSystem.fadeOutMusic(0.2);
		FlxG.camera.fade(FlxColor.BLACK, 0.2, false, function() {
			FlxG.switchState(() -> new ExtrasState());
		});
	}

	private function handleDevTools():Void
	{
		if (DevTools.shiftDevChordPressed(1))
		{
			DevTools.cycleLogLevel();
		}
		else if (DevTools.devChordPressed(1))
		{
			DevTools.toggleOverlay();
		}

		if (isTransitioning)
		{
			return;
		}

		if (DevTools.devChordPressed(2))
		{
			showStatus('Scene: ' + DevTools.cycleScene(-1));
		}

		if (DevTools.devChordPressed(3))
		{
			showStatus('Scene: ' + DevTools.cycleScene(1));
		}

		if (DevTools.devChordPressed(4))
		{
			showStatus('Chart: ' + DevTools.cycleChart(-1));
		}

		if (DevTools.devChordPressed(5))
		{
			showStatus('Chart: ' + DevTools.cycleChart(1));
		}

		if (DevTools.devChordPressed(6))
		{
			loadSelectedScene();
		}

		if (DevTools.devChordPressed(7))
		{
			launchSelectedChart();
		}
	}

	private function loadSelectedScene():Void
	{
		isTransitioning = true;
		var scene = DevTools.getSelectedScene();
		DevTools.notify('Loading scene from title: ${scene}');
		GameState.reset();
		SaveRestoreContext.clear();
		SystemOverrideService.clearAll();
		VNReturnContext.clear();
		RhythmCompletionBridge.clear();
		AudioSystem.fadeOutMusic(0.25);
		FlxG.camera.fade(FlxColor.BLACK, 0.25, false, function() {
			FlxG.switchState(() -> new VNState(scene));
		});
	}

	private function launchSelectedChart():Void
	{
		isTransitioning = true;
		var chartId = DevTools.getSelectedChart();
		DevTools.notify('Launching title rhythm sandbox: ${chartId}');
		AudioSystem.fadeOutMusic(0.25);

		var nextState = new RhythmState();
		nextState.song = chartId;
		nextState.chartPath = 'assets/data/charts/${chartId}.json';
		nextState.returnStateFactory = () -> new TitleState();
		nextState.onComplete = null;

		FlxG.camera.fade(FlxColor.BLACK, 0.25, false, function() {
			FlxG.switchState(() -> nextState);
		});
	}

	private function createDevOverlay():Void
	{
		devOverlayBg = new FlxSprite(8, 8);
		devOverlayBg.makeGraphic(520, 104, FlxColor.fromRGB(10, 10, 10, 180));
		devOverlayBg.scrollFactor.set(0, 0);
		devOverlayBg.alpha = 0.8;
		add(devOverlayBg);

		devOverlayText = new FlxText(18, 16, 500, "");
		devOverlayText.setFormat(null, 12, FlxColor.WHITE, LEFT);
		devOverlayText.scrollFactor.set(0, 0);
		add(devOverlayText);
	}

	private function updateDevOverlay():Void
	{
		if (devOverlayText == null || devOverlayBg == null)
		{
			return;
		}

		devOverlayBg.visible = DevTools.SHOW_OVERLAY;
		devOverlayText.visible = DevTools.SHOW_OVERLAY;
		if (!DevTools.SHOW_OVERLAY)
		{
			return;
		}

		devOverlayText.text =
			'DEV TITLE | Log=${DevTools.logLevelName(DevTools.LOG_LEVEL)} | Last=${DevTools.lastAction}\n'
			+ 'Selected Scene=${DevTools.shortScene(DevTools.getSelectedScene())} | Selected Chart=${DevTools.getSelectedChart()}\n'
			+ 'M+1 overlay | Shift+M+1 log | M+2/M+3 scene | M+4/M+5 chart | M+6 load scene | M+7 chart sandbox';
	}

	private function showStatus(message:String):Void
	{
		if (statusText == null)
		{
			return;
		}

		statusText.text = message;
		FlxTween.cancelTweensOf(statusText);
		statusText.alpha = 1;
		FlxTween.tween(statusText, {alpha: 0}, 1.6, {
			startDelay: 1.0,
			ease: FlxEase.quadOut
		});
	}
}
