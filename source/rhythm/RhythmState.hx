package rhythm;

import core.content.ContentRepository;
import dev.DevTools;
import dev.DevTools.RhythmDevMode;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.Assets;
import rhythm.ArrowRenderer;
import rhythm.CharacterAnimationBridge;
import rhythm.CharacterSpriteManager;
import rhythm.ChartData;
import rhythm.ChartHandler;
import rhythm.Conductor;
import rhythm.JudgementSystem;
import rhythm.Note;
import rhythm.NoteHandler;
import rhythm.NoteRenderer;
import rhythm.ScoreTracker;
import util.MobileSupport;

class RhythmState extends FlxState
{
	public var song:String;
	public var chartPath:String;
	public var returnStateFactory:Void->flixel.FlxState;
	public var onComplete:Dynamic;

	private var chartDisplayName:String = "";

	private var conductor:Conductor;
	private var chartHandler:ChartHandler;
	private var judgement:JudgementSystem;
	private var noteHandler:NoteHandler;

	private var arrowRenderer:ArrowRenderer;
	private var noteRenderer:NoteRenderer;
	private var characterSprites:CharacterSpriteManager;
	private var characterBridge:CharacterAnimationBridge;
	private var isFinishingSong:Bool = false;
	private var touchPads:Array<FlxSprite> = [];
	private var touchPadLabels:Array<FlxText> = [];
	private var touchLaneHeld:Array<Bool> = [false, false, false, false];

	private var devOverlayBg:FlxSprite;
	private var devOverlayText:FlxText;

	private var scoreTracker:ScoreTracker;

	// HUD
	private var hudHealthBg:FlxSprite;
	private var hudHealthFill:FlxSprite;
	private var hudHealthMaxWidth:Int;
	private var hudScoreText:FlxText;
	private var hudComboText:FlxText;
	private var hudJudgeText:FlxText;
	private var hudJudgeFadeTimer:Float = 0;
	private static inline var HUD_JUDGE_FADE:Float = 0.6;

	private var isPaused:Bool = false;
	private var pauseOverlayBg:FlxSprite;
	private var pauseOverlayTitle:FlxText;
	private var pauseMenuBtns:Array<{bg:FlxSprite, label:FlxText}> = [];
	private var pauseBtn:FlxSprite;

	override public function create():Void
	{
		super.create();

		if (chartPath == null)
			throw "RhythmState started without chartPath";
		if (!ContentRepository.exists(chartPath))
			throw 'RhythmState could not find chart at ${chartPath}';

		var chart:ChartData = cast haxe.Json.parse(ContentRepository.readText(chartPath));
		chartDisplayName = deriveChartName(chartPath);
		if (chart != null && chart.song != null && chart.song.song != null && chart.song.song != "")
		{
			song = chart.song.song;
		}
		else if (song == null || song == "")
		{
			song = chartDisplayName;
		}
		configureMobileLayout();

		var stageSprite = createStageSprite(chart.song.stage);
		if (stageSprite != null)
		{
			add(stageSprite);
		}

		var musicPath = 'assets/music/${chart.song.song}.ogg';
		if (!Assets.exists(musicPath))
			throw 'RhythmState could not find music at ${musicPath}';
		FlxG.sound.playMusic(musicPath, 1.0, false);

		conductor = new Conductor(chart.song.bpm, chart.song.offset);
		judgement = new JudgementSystem();
		scoreTracker = new ScoreTracker();
		chartHandler = new ChartHandler(chart, conductor);
		noteHandler = new NoteHandler(chartHandler, conductor, judgement);
		noteHandler.spawnAheadMs = NoteRenderer.SPAWN_AHEAD_MS;

		arrowRenderer = new ArrowRenderer();
		noteRenderer = new NoteRenderer(conductor, arrowRenderer);
		characterSprites = new CharacterSpriteManager();

		var allCharacterIDs:Array<String> = [];
		var loadedCharacterIDs:Array<String> = [];

		for (section in chart.song.notes)
		{
			if (section.singers != null)
			{
				for (singerID in section.singers)
				{
					if (!allCharacterIDs.contains(singerID))
					{
						allCharacterIDs.push(singerID);
					}
				}
			}
		}

		for (i in 0...allCharacterIDs.length)
		{
			var characterID = allCharacterIDs[i];
			var sprite = characterSprites.loadCharacter(characterID);
			if (sprite != null)
			{
				var basePos = characterSprites.getBasePosition(characterID);
				characterSprites.setCharacterPosition(characterID, basePos.x, basePos.y);
				add(sprite);
				loadedCharacterIDs.push(characterID);
			}
		}

		characterBridge = new CharacterAnimationBridge(conductor, characterSprites);
		for (characterID in loadedCharacterIDs)
		{
			characterBridge.registerCharacter(characterID);
		}

		add(arrowRenderer);
		add(noteRenderer);
		add(characterBridge);

		noteHandler.onNoteSpawn.add(onNoteSpawn);
		noteHandler.onNoteHit.add(onNoteHit);
		noteHandler.onNoteMiss.add(onNoteMiss);
		noteHandler.onGhostTap.add(onGhostTap);

		if (DevTools.ENABLED)
		{
			createDevOverlay();
		}

		if (MobileSupport.isMobile())
		{
			createTouchControls();
		}

		createHUD();
		createPauseUI();

		// Mobile pause button (top-right corner, inside safe area)
		if (MobileSupport.isMobile())
		{
			pauseBtn = new FlxSprite(MobileSupport.topRightIconX(), MobileSupport.topIconY());
			pauseBtn.makeGraphic(40, 40, FlxColor.fromRGBFloat(0.1, 0.07, 0.18, 0.7));
			pauseBtn.scrollFactor.set(0, 0);
			add(pauseBtn);
		}

		conductor.start();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Pause toggle
		#if FLX_KEYBOARD
		if (FlxG.keys.justPressed.ESCAPE && !isFinishingSong)
		{
			togglePause();
			return;
		}
		#end
		if (pauseBtn != null && MobileSupport.pointerJustPressedOver(pauseBtn))
		{
			togglePause();
			return;
		}

		if (isPaused)
		{
			updatePauseMenu();
			return;
		}

		updateHUD(elapsed);
		conductor.update();
		noteHandler.update();

		if (DevTools.ENABLED)
		{
			handleDevTools(elapsed);
			updateDevOverlay();
		}

		if (!DevTools.ENABLED || DevTools.RHYTHM_MODE == RhythmDevMode.OFF)
		{
			handleInput();
		}
		else if (DevTools.RHYTHM_MODE == RhythmDevMode.BOTPLAY)
		{
			updateBotplay();
		}

		if (FlxG.sound.music != null && !FlxG.sound.music.playing)
		{
			finishSong();
		}
	}

	private function handleDevTools(elapsed:Float):Void
	{
		if (DevTools.shiftDevChordPressed(1))
		{
			DevTools.cycleLogLevel();
		}
		else if (DevTools.devChordPressed(1))
		{
			DevTools.toggleOverlay();
		}

		if (DevTools.devChordPressed(2))
		{
			DevTools.cycleRhythmMode();
		}

		if (DevTools.devChordPressed(3))
		{
			restartCurrentChart();
			return;
		}

		if (DevTools.shiftDevChordPressed(4))
		{
			forceFail();
			return;
		}
		else if (DevTools.devChordPressed(4))
		{
			forceSuccess();
			return;
		}

		if (DevTools.devChordPressed(5))
		{
			DevTools.cycleChart(-1);
		}

		if (DevTools.devChordPressed(6))
		{
			DevTools.cycleChart(1);
		}

		if (DevTools.devChordPressed(7))
		{
			restartChartById(DevTools.getSelectedChart());
			return;
		}

		if (DevTools.devChordPressed(8))
		{
			DevTools.adjustAutoFinishDelay(-0.25);
		}

		if (DevTools.devChordPressed(9))
		{
			DevTools.adjustAutoFinishDelay(0.25);
		}

		switch (DevTools.RHYTHM_MODE)
		{
			case AUTO_FINISH_SUCCESS:
				if (conductor.songPositionMs >= DevTools.RHYTHM_AUTO_FINISH_DELAY * 1000)
				{
					forceSuccess();
				}
			case AUTO_FINISH_FAIL:
				if (conductor.songPositionMs >= DevTools.RHYTHM_AUTO_FINISH_DELAY * 1000)
				{
					forceFail();
				}
			default:
		}
	}

	private function updateBotplay():Void
	{
		for (lane in 0...4)
		{
			if (noteHandler.isLaneSustaining(lane) && noteHandler.getTailInWindow(lane) != null)
			{
				noteHandler.onKeyRelease(lane);
			}

			if (noteHandler.getHittableNoteForLane(lane) != null)
			{
				noteHandler.onKeyPress(lane);
			}
		}
	}

	private function handleInput():Void
	{
		updateTouchInput();

		#if FLX_KEYBOARD
		if (FlxG.keys.justPressed.A) noteHandler.onKeyPress(0);
		if (FlxG.keys.justPressed.S) noteHandler.onKeyPress(1);
		if (FlxG.keys.justPressed.D) noteHandler.onKeyPress(2);
		if (FlxG.keys.justPressed.F) noteHandler.onKeyPress(3);

		if (FlxG.keys.justReleased.A) noteHandler.onKeyRelease(0);
		if (FlxG.keys.justReleased.S) noteHandler.onKeyRelease(1);
		if (FlxG.keys.justReleased.D) noteHandler.onKeyRelease(2);
		if (FlxG.keys.justReleased.F) noteHandler.onKeyRelease(3);
		#end
	}

	private function configureMobileLayout():Void
	{
		if (MobileSupport.isMobile())
		{
			ArrowRenderer.VISUAL_SCALE = 1.3;
			ArrowRenderer.LAYOUT_RADIUS = 130;
			ArrowRenderer.LAYOUT_CENTER_Y_OFFSET = -18;
			NoteRenderer.VISUAL_SCALE = 1.35;
			NoteRenderer.SPAWN_RADIUS = 330;
			return;
		}

		ArrowRenderer.VISUAL_SCALE = 1.0;
		ArrowRenderer.LAYOUT_RADIUS = 150;
		ArrowRenderer.LAYOUT_CENTER_Y_OFFSET = 50;
		NoteRenderer.VISUAL_SCALE = 1.0;
		NoteRenderer.SPAWN_RADIUS = 400;
	}

	private function createTouchControls():Void
	{
		var gap = MobileSupport.rhythmPadGap();
		var bottomMargin = MobileSupport.rhythmPadBottomMargin();
		var padHeight = MobileSupport.rhythmPadHeight();
		var sideMargin = MobileSupport.safeX() + 8.0; // keep pads inside cutout zone
		var padWidth = (FlxG.width - (sideMargin * 2) - (gap * 3)) / 4;
		var y = FlxG.height - padHeight - bottomMargin;
		var labels = ["LEFT", "DOWN", "UP", "RIGHT"];
		var colors = [
			FlxColor.fromRGB(200, 70, 70),
			FlxColor.fromRGB(80, 180, 90),
			FlxColor.fromRGB(80, 120, 220),
			FlxColor.fromRGB(220, 190, 70)
		];

		touchPads = [];
		touchPadLabels = [];
		touchLaneHeld = [false, false, false, false];

		for (lane in 0...4)
		{
			var x = sideMargin + lane * (padWidth + gap);
			var pad = new FlxSprite(x, y);
			pad.makeGraphic(Std.int(padWidth), Std.int(padHeight), colors[lane]);
			pad.scrollFactor.set(0, 0);
			pad.alpha = MobileSupport.rhythmPadIdleAlpha();
			add(pad);
			touchPads.push(pad);

			var label = new FlxText(x, y + (padHeight / 2) - 20, padWidth, labels[lane]);
			label.setFormat(null, 22, FlxColor.WHITE, "center");
			label.scrollFactor.set(0, 0);
			add(label);
			touchPadLabels.push(label);
		}
	}

	private function updateTouchInput():Void
	{
		if (!MobileSupport.isMobile() || touchPads == null || touchPads.length == 0)
		{
			return;
		}

		for (lane in 0...touchPads.length)
		{
			var isPressed = MobileSupport.pointerPressedOver(touchPads[lane]);
			if (isPressed != touchLaneHeld[lane])
			{
				if (isPressed)
				{
					noteHandler.onKeyPress(lane);
				}
				else
				{
					noteHandler.onKeyRelease(lane);
				}
			}

			touchLaneHeld[lane] = isPressed;
			touchPads[lane].alpha = isPressed ? MobileSupport.rhythmPadPressedAlpha() : MobileSupport.rhythmPadIdleAlpha();
			touchPadLabels[lane].alpha = isPressed ? 1.0 : 0.88;
		}
	}

	private function onNoteSpawn(note:Note):Void
	{
		noteRenderer.spawnNote(note);
	}

	private function onNoteHit(note:Note, rating:HitRating):Void
	{
		noteRenderer.removeNote(note);
		arrowRenderer.onNoteHit(note, rating);
		characterBridge.onNoteHit(note, rating);

		if (note.isJudged)
		{
			scoreTracker.onNoteHit(rating);
			showJudgement(rating);
			if (scoreTracker.isDead())
				triggerFail();
		}
	}

	private function onNoteMiss(note:Note):Void
	{
		noteRenderer.removeNote(note);
		arrowRenderer.onNoteMiss(note);
		characterBridge.onNoteMiss(note);

		if (note.isJudged)
		{
			scoreTracker.onNoteMiss();
			showJudgement(HitRating.MISS);
			if (scoreTracker.isDead())
				triggerFail();
		}
	}

	private function onGhostTap(lane:Int):Void
	{
		arrowRenderer.onGhostTap(lane);
		scoreTracker.onGhostTap();
		if (scoreTracker.isDead())
			triggerFail();
	}

	private function triggerFail():Void
	{
		if (isFinishingSong) return;
		finishSong({
			score: scoreTracker.score,
			combo: scoreTracker.maxCombo,
			accuracy: scoreTracker.getAccuracy(),
			health: 0.0,
			completed: false
		});
	}

	private function createStageSprite(stageId:String):FlxSprite
	{
		if (stageId == null || stageId == "")
		{
			trace("[RhythmState] No stage specified in chart; skipping stage background");
			return null;
		}

		var stagePath = 'assets/images/stages/${stageId}.png';
		var sprite = new FlxSprite(0, 0);

		if (Assets.exists(stagePath))
		{
			trace('[RhythmState] Loading stage background: ${stagePath}');
			sprite.loadGraphic(stagePath);
		}
		else
		{
			trace('[RhythmState] Stage image not found at ${stagePath}, using placeholder');
			sprite.makeGraphic(FlxG.width, FlxG.height, 0xff101018);
		}

		sprite.setGraphicSize(FlxG.width, FlxG.height);
		sprite.updateHitbox();
		sprite.scrollFactor.set(0, 0);
		sprite.antialiasing = true;

		return sprite;
	}

	private function restartCurrentChart():Void
	{
		DevTools.notify('Restarting current chart ${chartDisplayName != "" ? chartDisplayName : song}');
		var nextState = new RhythmState();
		nextState.song = song;
		nextState.chartPath = chartPath;
		nextState.returnStateFactory = returnStateFactory;
		nextState.onComplete = onComplete;
		FlxG.switchState(() -> nextState);
	}

	private function restartChartById(nextChartId:String):Void
	{
		DevTools.notify('Restarting rhythm chart ${nextChartId}');
		var nextState = new RhythmState();
		nextState.song = nextChartId;
		nextState.chartPath = 'assets/data/charts/${nextChartId}.json';
		nextState.returnStateFactory = returnStateFactory;
		nextState.onComplete = onComplete;
		FlxG.switchState(() -> nextState);
	}

	private function forceSuccess():Void
	{
		DevTools.notify('Forced success for ${song}');
		finishSong({
			score: 123456,
			combo: 999,
			accuracy: 1.0,
			health: 1.0,
			completed: true
		});
	}

	private function forceFail():Void
	{
		DevTools.notify('Forced fail for ${song}');
		finishSong({
			score: 0,
			combo: 0,
			accuracy: 0.0,
			health: 0.0,
			completed: false
		});
	}

	private function finishSong(?resultOverride:Dynamic):Void
	{
		if (isFinishingSong) return;
		isFinishingSong = true;

		var result = {
			score: scoreTracker != null ? scoreTracker.score : 0,
			combo: scoreTracker != null ? scoreTracker.maxCombo : 0,
			accuracy: scoreTracker != null ? scoreTracker.getAccuracy() : 0.0,
			health: scoreTracker != null ? scoreTracker.health : 1.0,
			completed: true
		};

		if (resultOverride != null)
		{
			for (field in Reflect.fields(resultOverride))
			{
				Reflect.setField(result, field, Reflect.field(resultOverride, field));
			}
		}

		if (onComplete != null)
			rhythm.RhythmCompletionBridge.storeResult(result, onComplete);

		// Stop rhythm music before returning so it never bleeds into the VN
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			FlxG.sound.music.destroy();
			FlxG.sound.music = null;
		}

		if (returnStateFactory != null)
		{
			FlxG.switchState(() -> returnStateFactory());
		}
		else if (onComplete != null)
		{
			onComplete(result);
		}
	}

	private function createHUD():Void
	{
		var sw = FlxG.width;
		var sh = FlxG.height;
		var mobile = MobileSupport.isMobile();

		// Health bar — bottom center
		var barW = mobile ? 500 : 400;
		var barH = mobile ? 20 : 14;
		var barX = Std.int((sw - barW) / 2);
		var barY = sh - (mobile ? 50 : 36);
		hudHealthMaxWidth = barW;

		hudHealthBg = new FlxSprite(barX, barY);
		hudHealthBg.makeGraphic(barW, barH, FlxColor.fromRGB(15, 8, 25));
		hudHealthBg.scrollFactor.set(0, 0);
		add(hudHealthBg);

		hudHealthFill = new FlxSprite(barX, barY);
		hudHealthFill.makeGraphic(barW, barH, 0xFF8A2BE2);
		hudHealthFill.scrollFactor.set(0, 0);
		hudHealthFill.origin.x = 0;
		add(hudHealthFill);

		// Score — top right
		hudScoreText = new FlxText(sw - (mobile ? 220 : 180), mobile ? 12 : 8,
			mobile ? 200 : 164, "0");
		hudScoreText.setFormat(null, mobile ? 22 : 16, FlxColor.WHITE, RIGHT);
		hudScoreText.scrollFactor.set(0, 0);
		add(hudScoreText);

		// Combo — top center
		hudComboText = new FlxText(0, mobile ? 12 : 8, sw, "");
		hudComboText.setFormat(null, mobile ? 26 : 20, 0xFF8A2BE2, CENTER);
		hudComboText.scrollFactor.set(0, 0);
		add(hudComboText);

		// Judgement flash — upper-center of screen
		hudJudgeText = new FlxText(0, Std.int(sh * 0.34), sw, "");
		hudJudgeText.setFormat(null, mobile ? 38 : 30, FlxColor.WHITE, CENTER);
		hudJudgeText.scrollFactor.set(0, 0);
		hudJudgeText.alpha = 0;
		add(hudJudgeText);
	}

	private function updateHUD(elapsed:Float):Void
	{
		// Health bar fill — scale from left edge
		hudHealthFill.scale.x = Math.max(0, scoreTracker.health);

		// Tint the fill based on health level
		if (scoreTracker.health > 0.5)
			hudHealthFill.color = 0xFF8A2BE2;      // purple (safe)
		else if (scoreTracker.health > 0.25)
			hudHealthFill.color = 0xFFBB7700;      // amber (warning)
		else
			hudHealthFill.color = 0xFFCC2222;      // red (danger)

		// Score
		hudScoreText.text = Std.string(scoreTracker.score);

		// Combo (hide at 0 or 1)
		hudComboText.text = scoreTracker.combo >= 2 ? '${scoreTracker.combo}x' : "";

		// Fade judgement text
		if (hudJudgeFadeTimer > 0)
		{
			hudJudgeFadeTimer -= elapsed;
			hudJudgeText.alpha = Math.max(0, hudJudgeFadeTimer / HUD_JUDGE_FADE);
		}
	}

	private function showJudgement(rating:HitRating):Void
	{
		switch (rating)
		{
			case SICK:
				hudJudgeText.text  = "SICK!";
				hudJudgeText.color = 0xFF8A2BE2;
			case GOOD:
				hudJudgeText.text  = "GOOD";
				hudJudgeText.color = FlxColor.WHITE;
			case BAD:
				hudJudgeText.text  = "BAD";
				hudJudgeText.color = FlxColor.fromRGB(255, 160, 40);
			case MISS:
				hudJudgeText.text  = "MISS";
				hudJudgeText.color = FlxColor.RED;
		}
		hudJudgeText.alpha    = 1.0;
		hudJudgeFadeTimer     = HUD_JUDGE_FADE;
	}

	private function createPauseUI():Void
	{
		var sw = FlxG.width;
		var sh = FlxG.height;
		var mobile = MobileSupport.isMobile();

		pauseOverlayBg = new FlxSprite(0, 0);
		pauseOverlayBg.makeGraphic(sw, sh, FlxColor.fromRGBFloat(0, 0, 0, 0.7));
		pauseOverlayBg.scrollFactor.set(0, 0);
		pauseOverlayBg.visible = false;
		add(pauseOverlayBg);

		pauseOverlayTitle = new FlxText(0, mobile ? 100 : 80, sw, "PAUSED");
		pauseOverlayTitle.setFormat(null, mobile ? 36 : 28, 0xFF8A2BE2, CENTER);
		pauseOverlayTitle.scrollFactor.set(0, 0);
		pauseOverlayTitle.visible = false;
		add(pauseOverlayTitle);

		var items = ["RESUME", "RESTART", "QUIT"];
		var btnW = mobile ? 400 : 300;
		var btnH = mobile ? 60 : 44;
		var spacing = mobile ? 70 : 56;
		var startY = mobile ? 220 : 180;
		var btnX = Std.int((sw - btnW) / 2);

		for (i in 0...items.length)
		{
			var bg = new FlxSprite(btnX, startY + i * spacing);
			bg.makeGraphic(btnW, btnH, FlxColor.fromRGB(18, 12, 32));
			bg.scrollFactor.set(0, 0);
			bg.visible = false;
			add(bg);

			var lbl = new FlxText(bg.x, bg.y, btnW, items[i]);
			lbl.setFormat(null, mobile ? 26 : 20, 0xFF8A2BE2, CENTER);
			lbl.scrollFactor.set(0, 0);
			lbl.y = bg.y + (btnH - lbl.height) / 2;
			lbl.visible = false;
			add(lbl);

			pauseMenuBtns.push({bg: bg, label: lbl});
		}
	}

	private function togglePause():Void
	{
		if (isFinishingSong) return;
		isPaused = !isPaused;

		pauseOverlayBg.visible = isPaused;
		pauseOverlayTitle.visible = isPaused;
		for (btn in pauseMenuBtns)
		{
			btn.bg.visible = isPaused;
			btn.label.visible = isPaused;
		}

		if (isPaused)
		{
			if (FlxG.sound.music != null && FlxG.sound.music.playing)
				FlxG.sound.music.pause();
		}
		else
		{
			if (FlxG.sound.music != null && !FlxG.sound.music.playing)
				FlxG.sound.music.resume();
		}
	}

	private function updatePauseMenu():Void
	{
		for (i in 0...pauseMenuBtns.length)
		{
			var btn = pauseMenuBtns[i];
			if (MobileSupport.pointerOverlaps(btn.bg))
			{
				btn.bg.color = FlxColor.fromRGB(35, 25, 60);
				if (MobileSupport.pointerJustPressedOver(btn.bg))
				{
					switch (i)
					{
						case 0: // RESUME
							togglePause();
						case 1: // RESTART
							togglePause();
							restartCurrentChart();
						case 2: // QUIT
							isPaused = false;
							finishSong({score: 0, combo: 0, accuracy: 0.0, health: 0.0, completed: false});
					}
				}
			}
			else
			{
				btn.bg.color = FlxColor.fromRGB(18, 12, 32);
			}
		}

		#if FLX_KEYBOARD
		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			togglePause();
		}
		#end
	}

	private function createDevOverlay():Void
	{
		devOverlayBg = new FlxSprite(8, 8);
		devOverlayBg.makeGraphic(560, 198, FlxColor.fromRGB(10, 10, 10, 180));
		devOverlayBg.scrollFactor.set(0, 0);
		devOverlayBg.alpha = 0.8;
		add(devOverlayBg);

		devOverlayText = new FlxText(18, 16, 540, "");
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

		var acc = Std.int(scoreTracker.getAccuracy() * 10000) / 100;
		devOverlayText.text =
			'DEV RHYTHM | Song=${song} | Chart=${chartDisplayName} | Log=${DevTools.logLevelName(DevTools.LOG_LEVEL)} | Last=${DevTools.lastAction}\n'
			+ 'Mode=${DevTools.rhythmModeName(DevTools.RHYTHM_MODE)} | AutoFinishDelay=${DevTools.formatFloat(DevTools.RHYTHM_AUTO_FINISH_DELAY)}s | Time=${DevTools.formatFloat(conductor.songPositionMs)}ms\n'
			+ 'Selected Chart=${DevTools.getSelectedChart()} | Active Notes=${noteHandler.getActiveCount()} | Finishing=${isFinishingSong}\n'
			+ 'Score=${scoreTracker.score} | Combo=${scoreTracker.combo} (max ${scoreTracker.maxCombo}) | Health=${Std.int(scoreTracker.health * 100)}% | Acc=${acc}%\n'
			+ 'SICK=${scoreTracker.sickCount} GOOD=${scoreTracker.goodCount} BAD=${scoreTracker.badCount} MISS=${scoreTracker.missCount}\n'
			+ 'M+1 overlay | Shift+M+1 log | M+2 rhythm mode | M+3 restart current | M+4 success | Shift+M+4 fail\n'
			+ 'M+5/M+6 chart | M+7 load selected chart | M+8/M+9 auto-finish delay';
	}

	private function deriveChartName(path:String):String
	{
		if (path == null || path == "")
		{
			return "(unknown)";
		}

		var normalized = StringTools.replace(path, "\\", "/");
		var slash = normalized.lastIndexOf("/");
		var name = slash >= 0 ? normalized.substr(slash + 1) : normalized;
		return StringTools.endsWith(name, ".json")
			? name.substr(0, name.length - ".json".length)
			: name;
	}
}
